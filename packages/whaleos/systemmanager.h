#ifndef SYSTEMMANAGER_H
#define SYSTEMMANAGER_H

#include <QObject>
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QDateTime>

class SystemManager : public QObject {
    Q_OBJECT

public:
    explicit SystemManager(QObject *parent = nullptr) : QObject(parent) {}

    // ── List real Linux system users (UID >= 1000, excluding nobody/nogroup) ──
    Q_INVOKABLE QString listUsers() {
        QJsonArray users;
        QFile passwd("/etc/passwd");
        if (passwd.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&passwd);
            while (!in.atEnd()) {
                QString line = in.readLine().trimmed();
                if (line.isEmpty() || line.startsWith('#')) continue;
                QStringList parts = line.split(':');
                if (parts.size() < 7) continue;

                QString username = parts[0];
                int uid = parts[2].toInt();
                QString shell = parts[6];

                // Only show real users: UID >= 1000, not nobody, has a real shell
                if (uid >= 1000 && username != "nobody" && username != "nogroup"
                    && !shell.contains("nologin") && !shell.contains("false")) {
                    QJsonObject user;
                    user["username"] = username;
                    user["uid"] = uid;
                    user["home"] = parts[5];
                    user["shell"] = shell;
                    // First user (uid 1000) is admin
                    user["role"] = (uid == 1000) ? "admin" : "user";
                    users.append(user);
                }
            }
            passwd.close();
        }
        return QString::fromUtf8(QJsonDocument(users).toJson(QJsonDocument::Compact));
    }

    // ── Add a new Linux system user ──
    Q_INVOKABLE bool addUser(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) return false;

        // Validate username (alphanumeric + underscore, starts with letter)
        QRegularExpression rx("^[a-z_][a-z0-9_-]*$");
        if (!rx.match(username).hasMatch()) {
            qWarning() << "SystemManager: Invalid username:" << username;
            return false;
        }

        // Create user with home directory and bash shell
        QProcess proc;
        proc.start("sudo", QStringList() << "useradd" << "-m" << "-s" << "/bin/bash" << username);
        proc.waitForFinished(5000);
        if (proc.exitCode() != 0) {
            qWarning() << "SystemManager: useradd failed:" << proc.readAllStandardError();
            return false;
        }

        // Set password
        QProcess chpasswd;
        chpasswd.start("sudo", QStringList() << "chpasswd");
        chpasswd.waitForStarted(3000);
        chpasswd.write(QString("%1:%2\n").arg(username, password).toUtf8());
        chpasswd.closeWriteChannel();
        chpasswd.waitForFinished(5000);
        if (chpasswd.exitCode() != 0) {
            qWarning() << "SystemManager: chpasswd failed:" << chpasswd.readAllStandardError();
            return false;
        }

        qDebug() << "SystemManager: User" << username << "created successfully";
        return true;
    }

    // ── Delete a Linux system user ──
    Q_INVOKABLE bool deleteUser(const QString &username) {
        if (username.isEmpty()) return false;

        // Prevent deleting the primary admin user (uid 1000)
        QProcess idProc;
        idProc.start("id", QStringList() << "-u" << username);
        idProc.waitForFinished(3000);
        int uid = idProc.readAllStandardOutput().trimmed().toInt();
        if (uid == 1000) {
            qWarning() << "SystemManager: Cannot delete primary admin user";
            return false;
        }

        // Delete user and their home directory
        QProcess proc;
        proc.start("sudo", QStringList() << "userdel" << "-r" << username);
        proc.waitForFinished(5000);
        if (proc.exitCode() != 0) {
            qWarning() << "SystemManager: userdel failed:" << proc.readAllStandardError();
            return false;
        }

        qDebug() << "SystemManager: User" << username << "deleted successfully";
        return true;
    }

    // ── Change a user's password ──
    Q_INVOKABLE bool changePassword(const QString &username, const QString &newPassword) {
        if (username.isEmpty() || newPassword.isEmpty()) return false;

        QProcess proc;
        proc.start("sudo", QStringList() << "chpasswd");
        proc.waitForStarted(3000);
        proc.write(QString("%1:%2\n").arg(username, newPassword).toUtf8());
        proc.closeWriteChannel();
        proc.waitForFinished(5000);

        if (proc.exitCode() != 0) {
            qWarning() << "SystemManager: Password change failed:" << proc.readAllStandardError();
            return false;
        }

        qDebug() << "SystemManager: Password changed for" << username;
        return true;
    }

    // ── Authenticate user against Linux PAM/shadow ──
    Q_INVOKABLE bool authenticate(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) return false;

        // Use 'su' to verify credentials
        QProcess proc;
        proc.start("su", QStringList() << "-c" << "echo AUTH_OK" << username);
        proc.waitForStarted(3000);
        proc.write(QString("%1\n").arg(password).toUtf8());
        proc.closeWriteChannel();
        proc.waitForFinished(5000);

        QString output = proc.readAllStandardOutput().trimmed();
        bool ok = (proc.exitCode() == 0 && output.contains("AUTH_OK"));

        qDebug() << "SystemManager: Auth for" << username << ":" << (ok ? "SUCCESS" : "FAILED");
        return ok;
    }

    // ── Get system hostname ──
    Q_INVOKABLE QString getHostname() {
        QFile f("/etc/hostname");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return f.readAll().trimmed();
        }
        return "ainux";
    }

    // ════════════════════════════════════════════════
    // ── File System Operations (kernel level) ──
    // ════════════════════════════════════════════════

    // ── Create directory (mkdir -p) ──
    Q_INVOKABLE bool createDir(const QString &path) {
        if (path.isEmpty()) return false;
        QDir dir;
        bool ok = dir.mkpath(path);
        if (ok) qDebug() << "SystemManager: Created directory:" << path;
        else qWarning() << "SystemManager: Failed to create directory:" << path;
        return ok;
    }

    // ── List directory contents → JSON array ──
    Q_INVOKABLE QString listDirectory(const QString &path) {
        QJsonArray items;
        QDir dir(path);
        if (!dir.exists()) return "[]";

        dir.setFilter(QDir::AllEntries | QDir::NoDotAndDotDot);
        dir.setSorting(QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);
        QFileInfoList entries = dir.entryInfoList();

        for (const QFileInfo &info : entries) {
            QJsonObject item;
            item["name"] = info.fileName();
            item["path"] = info.absoluteFilePath();
            item["isDir"] = info.isDir();
            item["size"] = info.isDir() ? 0 : (qint64)info.size();
            item["modified"] = info.lastModified().toString("yyyy-MM-dd HH:mm");
            item["permissions"] = info.isReadable() ? (info.isWritable() ? "rw" : "r") : "-";

            // File extension for icon mapping
            if (!info.isDir()) {
                item["ext"] = info.suffix().toLower();
            }
            items.append(item);
        }
        return QString::fromUtf8(QJsonDocument(items).toJson(QJsonDocument::Compact));
    }

    // ── Read file contents ──
    Q_INVOKABLE QString readFileContent(const QString &path) {
        QFile file(path);
        if (!file.exists()) return "";
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return "";
        QString content = file.readAll();
        file.close();
        return content;
    }

    // ── Write file contents ──
    Q_INVOKABLE bool writeFileContent(const QString &path, const QString &content) {
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            qWarning() << "SystemManager: Cannot write to:" << path;
            return false;
        }
        file.write(content.toUtf8());
        file.close();
        return true;
    }

    // ── Delete file or directory ──
    Q_INVOKABLE bool deleteFile(const QString &path) {
        QFileInfo info(path);
        if (!info.exists()) return false;

        bool ok;
        if (info.isDir()) {
            QDir dir(path);
            ok = dir.removeRecursively();
        } else {
            ok = QFile::remove(path);
        }
        if (ok) qDebug() << "SystemManager: Deleted:" << path;
        else qWarning() << "SystemManager: Delete failed:" << path;
        return ok;
    }

    // ── Rename/move file or directory ──
    Q_INVOKABLE bool renameFile(const QString &oldPath, const QString &newPath) {
        QFile file(oldPath);
        bool ok = file.rename(newPath);
        if (ok) qDebug() << "SystemManager: Renamed:" << oldPath << "->" << newPath;
        return ok;
    }

    // ── Get file info as JSON ──
    Q_INVOKABLE QString getFileInfo(const QString &path) {
        QFileInfo info(path);
        if (!info.exists()) return "{}";

        QJsonObject obj;
        obj["name"] = info.fileName();
        obj["path"] = info.absoluteFilePath();
        obj["isDir"] = info.isDir();
        obj["size"] = (qint64)info.size();
        obj["modified"] = info.lastModified().toString("yyyy-MM-dd HH:mm");
        obj["ext"] = info.suffix().toLower();
        obj["exists"] = true;
        return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
    }

    // ════════════════════════════════════════════════
    // ── Clipboard Operations (via xclip) ──
    // ════════════════════════════════════════════════

    Q_INVOKABLE bool copyToClipboard(const QString &text) {
        QProcess proc;
        proc.start("xclip", QStringList() << "-selection" << "clipboard");
        proc.waitForStarted(3000);
        proc.write(text.toUtf8());
        proc.closeWriteChannel();
        proc.waitForFinished(3000);
        return proc.exitCode() == 0;
    }

    Q_INVOKABLE QString pasteFromClipboard() {
        QProcess proc;
        proc.start("xclip", QStringList() << "-selection" << "clipboard" << "-o");
        proc.waitForFinished(3000);
        if (proc.exitCode() == 0) {
            return proc.readAllStandardOutput().trimmed();
        }
        return "";
    }
};

#endif // SYSTEMMANAGER_H
