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
#include <QQuickWindow>
#include <QThread>

class SystemManager : public QObject {
    Q_OBJECT

public:
    explicit SystemManager(QObject *parent = nullptr) : QObject(parent), m_mainWindow(nullptr) {}

    void setMainWindow(QQuickWindow *win) { m_mainWindow = win; }

private:
    QQuickWindow *m_mainWindow;

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

    // ════════════════════════════════════════════════
    // ── File Launching (via xdg-open / app-specific) ──
    // ════════════════════════════════════════════════

    Q_INVOKABLE bool openFile(const QString &path) {
        QFileInfo info(path);
        if (!info.exists()) return false;

        QString ext = info.suffix().toLower();
        QStringList args;

        // PDF → evince
        if (ext == "pdf") {
            args << "evince" << path;
        }
        // Spreadsheets → gnumeric
        else if (ext == "xlsx" || ext == "xls" || ext == "ods" || ext == "csv") {
            args << "gnumeric" << path;
        }
        // Documents → libreoffice
        else if (ext == "doc" || ext == "docx" || ext == "odt" || ext == "pptx" || ext == "ppt") {
            args << "libreoffice" << "--norestore" << path;
        }
        // Images → eog (Eye of GNOME) or feh
        else if (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif" || ext == "bmp" || ext == "svg" || ext == "webp") {
            args << "feh" << "--scale-down" << path;
        }
        // Text/code → xdg-open (fallback to terminal editor)
        else {
            args << "xdg-open" << path;
        }

        QProcess *proc = new QProcess();
        proc->setProgram(args.takeFirst());
        proc->setArguments(args);
        proc->startDetached();
        qDebug() << "SystemManager: Opening file:" << path;
        return true;
    }

    // ════════════════════════════════════════════════
    // ── Native App Window Management (via xdotool) ──
    // ════════════════════════════════════════════════

    Q_INVOKABLE QString getMainWindowId() {
        if (m_mainWindow) return QString::number(m_mainWindow->winId());
        return "";
    }

    Q_INVOKABLE QString launchNativeApp(const QString &command, const QString &searchName) {
        if (command.isEmpty()) return "";

        // Launch the app detached
        QProcess::startDetached("/bin/bash", QStringList() << "-c" << command);
        qDebug() << "SystemManager: Launching native app:" << command;

        // Poll xdotool to find the window (up to 10 seconds)
        for (int i = 0; i < 20; i++) {
            QThread::msleep(500);
            QProcess search;
            search.start("xdotool", QStringList() << "search" << "--name" << searchName);
            search.waitForFinished(3000);
            QString output = search.readAllStandardOutput().trimmed();
            if (!output.isEmpty()) {
                QStringList ids = output.split('\n');
                QString winId = ids.last();
                qDebug() << "SystemManager: Found native window:" << winId;
                return winId;
            }
        }
        qWarning() << "SystemManager: Timeout finding window for:" << searchName;
        return "";
    }

    Q_INVOKABLE bool embedWindow(const QString &childWinId, const QString &parentWinId, int x, int y, int w, int h) {
        if (childWinId.isEmpty() || parentWinId.isEmpty()) return false;

        QProcess reparent;
        reparent.start("xdotool", QStringList() << "windowreparent" << childWinId << parentWinId);
        reparent.waitForFinished(3000);

        QProcess resize;
        resize.start("xdotool", QStringList() << "windowsize" << childWinId << QString::number(w) << QString::number(h));
        resize.waitForFinished(3000);

        QProcess move;
        move.start("xdotool", QStringList() << "windowmove" << "--relative" << childWinId << QString::number(x) << QString::number(y));
        move.waitForFinished(3000);

        QProcess activate;
        activate.start("xdotool", QStringList() << "windowactivate" << childWinId);
        activate.waitForFinished(3000);

        qDebug() << "SystemManager: Embedded window" << childWinId << "into" << parentWinId << "at" << x << y << w << h;
        return true;
    }

    Q_INVOKABLE bool moveEmbeddedWindow(const QString &winId, int x, int y, int w, int h) {
        if (winId.isEmpty()) return false;

        QProcess move;
        move.start("xdotool", QStringList() << "windowmove" << winId << QString::number(x) << QString::number(y));
        move.waitForFinished(1000);

        QProcess resize;
        resize.start("xdotool", QStringList() << "windowsize" << winId << QString::number(w) << QString::number(h));
        resize.waitForFinished(1000);
        return true;
    }

    Q_INVOKABLE bool closeNativeWindow(const QString &winId) {
        if (winId.isEmpty()) return false;

        QProcess proc;
        proc.start("xdotool", QStringList() << "windowclose" << winId);
        proc.waitForFinished(3000);
        qDebug() << "SystemManager: Closed native window:" << winId;
        return true;
    }

    Q_INVOKABLE bool launchApp(const QString &command) {
        if (command.isEmpty()) return false;
        QProcess *proc = new QProcess();
        proc->setProgram("/bin/bash");
        proc->setArguments(QStringList() << "-c" << command + " &");
        proc->startDetached();
        qDebug() << "SystemManager: Launching app:" << command;
        return true;
    }

    // ════════════════════════════════════════════════
    // ── Shell Command Execution (for Terminal) ──
    // ════════════════════════════════════════════════

    Q_INVOKABLE QString runCommand(const QString &command, const QString &cwd) {
        QProcess proc;
        proc.setWorkingDirectory(cwd.isEmpty() ? "/home/ainux" : cwd);
        proc.setProcessChannelMode(QProcess::SeparateChannels);

        // Run via bash -c to support pipes, redirects, etc.
        proc.start("/bin/bash", QStringList() << "-c" << command);

        if (!proc.waitForStarted(5000)) {
            QJsonObject result;
            result["stdout"] = "";
            result["stderr"] = "Failed to start command";
            result["exitCode"] = -1;
            result["cwd"] = cwd;
            return QString(QJsonDocument(result).toJson(QJsonDocument::Compact));
        }

        proc.waitForFinished(30000); // 30 second timeout

        QString stdoutStr = QString::fromUtf8(proc.readAllStandardOutput());
        QString stderrStr = QString::fromUtf8(proc.readAllStandardError());

        // Determine new cwd after cd commands
        QString newCwd = cwd.isEmpty() ? "/home/ainux" : cwd;
        if (command.trimmed().startsWith("cd ")) {
            // Run pwd to get the actual new directory
            QProcess pwdProc;
            pwdProc.setWorkingDirectory(newCwd);
            pwdProc.start("/bin/bash", QStringList() << "-c" << command + " && pwd");
            if (pwdProc.waitForFinished(3000)) {
                QString pwd = QString::fromUtf8(pwdProc.readAllStandardOutput()).trimmed();
                if (!pwd.isEmpty()) newCwd = pwd;
            }
        }

        QJsonObject result;
        result["stdout"] = stdoutStr;
        result["stderr"] = stderrStr;
        result["exitCode"] = proc.exitCode();
        result["cwd"] = newCwd;
        return QString(QJsonDocument(result).toJson(QJsonDocument::Compact));
    }
};

#endif // SYSTEMMANAGER_H
