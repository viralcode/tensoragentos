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
};

#endif // SYSTEMMANAGER_H
