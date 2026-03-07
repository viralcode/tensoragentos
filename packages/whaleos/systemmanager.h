/*
 * SystemManager — TensorAgent OS kernel-level operations
 *
 * Provides QML-callable methods for:
 *   • PAM-based authentication (async, non-blocking)
 *   • Asynchronous shell command execution (non-blocking UI)
 *   • User management (async add/delete/password)
 *   • File system operations
 *   • Clipboard sync (Qt ↔ Wayland ↔ XWayland) — async
 *   • Display settings (wlr-randr / xrandr) — async
 *   • Native app launching with dynamic environment
 *
 * PERF: All system operations that spawn QProcess now use async
 *       signal-based completion to avoid blocking the QML main thread.
 */

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
#include <QGuiApplication>
#include <QClipboard>
#include <QMimeData>
#include <QUuid>

#include <security/pam_appl.h>
#include <pwd.h>
#include <unistd.h>
#include <sys/types.h>
#include <cstring>

// ════════════════════════════════════════════════════════════════
// PAM conversation callback — feeds password to PAM non-interactively
// ════════════════════════════════════════════════════════════════

static int pamConversation(int numMsg, const struct pam_message **msg,
                           struct pam_response **resp, void *appdata) {
    const char *password = static_cast<const char *>(appdata);
    if (numMsg <= 0 || numMsg > PAM_MAX_NUM_MSG) return PAM_CONV_ERR;

    struct pam_response *reply = static_cast<struct pam_response *>(
        calloc(numMsg, sizeof(struct pam_response)));
    if (!reply) return PAM_BUF_ERR;

    for (int i = 0; i < numMsg; i++) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF ||
            msg[i]->msg_style == PAM_PROMPT_ECHO_ON) {
            reply[i].resp = strdup(password);
            reply[i].resp_retcode = 0;
        }
    }

    *resp = reply;
    return PAM_SUCCESS;
}


// ════════════════════════════════════════════════════════════════
// AuthWorker — runs PAM authentication off the main thread
// ════════════════════════════════════════════════════════════════

class AuthWorker : public QObject {
    Q_OBJECT
public:
    AuthWorker(const QString &user, const QString &pass)
        : m_user(user), m_pass(pass) {}

public slots:
    void doWork() {
        QByteArray user = m_user.toUtf8();
        QByteArray pass = m_pass.toUtf8();

        struct pam_conv conv;
        conv.conv = pamConversation;
        conv.appdata_ptr = const_cast<char *>(pass.constData());

        pam_handle_t *pamh = nullptr;
        int ret = pam_start("login", user.constData(), &conv, &pamh);
        if (ret != PAM_SUCCESS) {
            qWarning() << "AuthWorker: PAM start failed:" << pam_strerror(pamh, ret);
            emit finished(false);
            return;
        }

        ret = pam_authenticate(pamh, 0);
        bool authenticated = (ret == PAM_SUCCESS);

        if (authenticated) {
            ret = pam_acct_mgmt(pamh, 0);
            if (ret != PAM_SUCCESS) {
                qWarning() << "AuthWorker: PAM account check failed:" << pam_strerror(pamh, ret);
                authenticated = false;
            }
        }

        pam_end(pamh, ret);
        qDebug() << "AuthWorker: Auth" << m_user << ":"
                 << (authenticated ? "SUCCESS" : "FAILED");
        emit finished(authenticated);
    }

signals:
    void finished(bool success);

private:
    QString m_user;
    QString m_pass;
};


class SystemManager : public QObject {
    Q_OBJECT

public:
    explicit SystemManager(QObject *parent = nullptr)
        : QObject(parent), m_mainWindow(nullptr), m_cachedHome("") {}

    void setMainWindow(QQuickWindow *win) { m_mainWindow = win; }


    // ════════════════════════════════════════════════
    // ── Authentication (PAM-based, ASYNC — non-blocking)
    // ════════════════════════════════════════════════

    // Legacy synchronous — kept for backward compat but should be avoided
    Q_INVOKABLE bool authenticate(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) return false;

        QByteArray user = username.toUtf8();
        QByteArray pass = password.toUtf8();

        struct pam_conv conv;
        conv.conv = pamConversation;
        conv.appdata_ptr = const_cast<char *>(pass.constData());

        pam_handle_t *pamh = nullptr;
        int ret = pam_start("login", user.constData(), &conv, &pamh);
        if (ret != PAM_SUCCESS) {
            qWarning() << "SystemManager: PAM start failed:" << pam_strerror(pamh, ret);
            return false;
        }

        ret = pam_authenticate(pamh, 0);
        bool authenticated = (ret == PAM_SUCCESS);

        if (authenticated) {
            ret = pam_acct_mgmt(pamh, 0);
            if (ret != PAM_SUCCESS) {
                qWarning() << "SystemManager: PAM account check failed:" << pam_strerror(pamh, ret);
                authenticated = false;
            }
        }

        pam_end(pamh, ret);
        qDebug() << "SystemManager: Auth" << username << ":"
                 << (authenticated ? "SUCCESS" : "FAILED");
        return authenticated;
    }

    // ASYNC authentication — runs PAM in a worker thread, emits authResult
    Q_INVOKABLE void authenticateAsync(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) {
            emit authResult(false);
            return;
        }

        QThread *thread = new QThread();
        AuthWorker *worker = new AuthWorker(username, password);
        worker->moveToThread(thread);

        connect(thread, &QThread::started, worker, &AuthWorker::doWork);
        connect(worker, &AuthWorker::finished, this, [this, thread, worker](bool success) {
            emit authResult(success);
            thread->quit();
        });
        connect(thread, &QThread::finished, worker, &QObject::deleteLater);
        connect(thread, &QThread::finished, thread, &QObject::deleteLater);

        thread->start();
        qDebug() << "SystemManager: authenticateAsync started for" << username;
    }


    // ════════════════════════════════════════════════
    // ── User Management (ASYNC — non-blocking)
    // ════════════════════════════════════════════════

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

                QString uname = parts[0];
                int uid = parts[2].toInt();
                QString shell = parts[6];

                // Only real users: UID >= 1000, valid shell
                if (uid >= 1000 && uname != "nobody" && uname != "nogroup"
                    && !shell.contains("nologin") && !shell.contains("false")) {
                    QJsonObject user;
                    user["username"] = uname;
                    user["uid"] = uid;
                    user["home"] = parts[5];
                    user["shell"] = shell;
                    user["role"] = (uid == 1000) ? "admin" : "user";
                    users.append(user);
                }
            }
            passwd.close();
        }
        return QString::fromUtf8(QJsonDocument(users).toJson(QJsonDocument::Compact));
    }

    // ASYNC addUser — non-blocking
    Q_INVOKABLE void addUserAsync(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) {
            emit userOpResult("addUser", false, "Username and password required");
            return;
        }

        QRegularExpression rx("^[a-z_][a-z0-9_-]*$");
        if (!rx.match(username).hasMatch()) {
            qWarning() << "SystemManager: Invalid username:" << username;
            emit userOpResult("addUser", false, "Invalid username format");
            return;
        }

        QProcess *proc = new QProcess(this);
        proc->setProperty("opUser", username);
        proc->setProperty("opPass", password);

        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, username, password](int exitCode, QProcess::ExitStatus) {
            if (exitCode != 0) {
                qWarning() << "SystemManager: useradd failed:" << proc->readAllStandardError();
                emit userOpResult("addUser", false, "useradd failed");
                proc->deleteLater();
                return;
            }

            // Now set password asynchronously
            QProcess *chpasswd = new QProcess(this);
            connect(chpasswd, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    this, [this, chpasswd, username](int code, QProcess::ExitStatus) {
                if (code != 0) {
                    qWarning() << "SystemManager: chpasswd failed:" << chpasswd->readAllStandardError();
                    emit userOpResult("addUser", false, "chpasswd failed");
                } else {
                    qDebug() << "SystemManager: User" << username << "created successfully";
                    emit userOpResult("addUser", true, username);
                }
                chpasswd->deleteLater();
            });
            chpasswd->start("sudo", QStringList() << "chpasswd");
            chpasswd->waitForStarted(1000);
            chpasswd->write(QString("%1:%2\n").arg(username, password).toUtf8());
            chpasswd->closeWriteChannel();

            proc->deleteLater();
        });

        proc->start("sudo", QStringList() << "useradd" << "-m" << "-s" << "/bin/bash" << username);
    }

    // Legacy synchronous — kept for compat
    Q_INVOKABLE bool addUser(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) return false;

        QRegularExpression rx("^[a-z_][a-z0-9_-]*$");
        if (!rx.match(username).hasMatch()) {
            qWarning() << "SystemManager: Invalid username:" << username;
            return false;
        }

        QProcess proc;
        proc.start("sudo", QStringList() << "useradd" << "-m" << "-s" << "/bin/bash" << username);
        proc.waitForFinished(5000);
        if (proc.exitCode() != 0) {
            qWarning() << "SystemManager: useradd failed:" << proc.readAllStandardError();
            return false;
        }

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

    // ASYNC deleteUser — non-blocking
    Q_INVOKABLE void deleteUserAsync(const QString &username) {
        if (username.isEmpty()) {
            emit userOpResult("deleteUser", false, "Empty username");
            return;
        }

        // Check UID first (fast, synchronous read)
        QProcess *idProc = new QProcess(this);
        connect(idProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, idProc, username](int, QProcess::ExitStatus) {
            int uid = idProc->readAllStandardOutput().trimmed().toInt();
            idProc->deleteLater();

            if (uid == 1000) {
                qWarning() << "SystemManager: Cannot delete primary admin user";
                emit userOpResult("deleteUser", false, "Cannot delete primary admin user");
                return;
            }

            QProcess *delProc = new QProcess(this);
            connect(delProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    this, [this, delProc, username](int exitCode, QProcess::ExitStatus) {
                if (exitCode != 0) {
                    qWarning() << "SystemManager: userdel failed:" << delProc->readAllStandardError();
                    emit userOpResult("deleteUser", false, "userdel failed");
                } else {
                    qDebug() << "SystemManager: User" << username << "deleted successfully";
                    emit userOpResult("deleteUser", true, username);
                }
                delProc->deleteLater();
            });
            delProc->start("sudo", QStringList() << "userdel" << "-r" << username);
        });
        idProc->start("id", QStringList() << "-u" << username);
    }

    Q_INVOKABLE bool deleteUser(const QString &username) {
        if (username.isEmpty()) return false;

        QProcess idProc;
        idProc.start("id", QStringList() << "-u" << username);
        idProc.waitForFinished(3000);
        int uid = idProc.readAllStandardOutput().trimmed().toInt();
        if (uid == 1000) {
            qWarning() << "SystemManager: Cannot delete primary admin user";
            return false;
        }

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

    // ASYNC changePassword — non-blocking
    Q_INVOKABLE void changePasswordAsync(const QString &username, const QString &newPassword) {
        if (username.isEmpty() || newPassword.isEmpty()) {
            emit userOpResult("changePassword", false, "Username and password required");
            return;
        }

        QProcess *proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, username](int exitCode, QProcess::ExitStatus) {
            if (exitCode != 0) {
                qWarning() << "SystemManager: Password change failed:" << proc->readAllStandardError();
                emit userOpResult("changePassword", false, "chpasswd failed");
            } else {
                qDebug() << "SystemManager: Password changed for" << username;
                emit userOpResult("changePassword", true, username);
            }
            proc->deleteLater();
        });
        proc->start("sudo", QStringList() << "chpasswd");
        proc->waitForStarted(1000);
        proc->write(QString("%1:%2\n").arg(username, newPassword).toUtf8());
        proc->closeWriteChannel();
    }

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

    Q_INVOKABLE QString getHostname() {
        QFile f("/etc/hostname");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return f.readAll().trimmed();
        }
        return "tensoragent";
    }


    // ════════════════════════════════════════════════
    // ── Shell Command Execution
    //
    // runCommandQuick() — fast synchronous for sub-second queries (cd, echo)
    // runCommand()      — synchronous with 3s timeout (reduced from 10s)
    // runCommandAsync()  — fully non-blocking, emits signals
    // ════════════════════════════════════════════════

    // Quick synchronous — for sub-second system queries only (cd, pwd, echo)
    Q_INVOKABLE QString runCommandQuick(const QString &command, const QString &cwd) {
        QProcess proc;
        proc.setWorkingDirectory(cwd.isEmpty() ? currentUserHome() : cwd);
        proc.setProcessChannelMode(QProcess::SeparateChannels);
        proc.start("/bin/bash", QStringList() << "-c" << command);

        if (!proc.waitForStarted(2000)) {
            return buildCommandResult("", "Failed to start command", -1, cwd);
        }

        proc.waitForFinished(2000);

        QString stdoutStr = QString::fromUtf8(proc.readAllStandardOutput());
        QString stderrStr = QString::fromUtf8(proc.readAllStandardError());
        QString newCwd = cwd.isEmpty() ? currentUserHome() : cwd;

        return buildCommandResult(stdoutStr, stderrStr, proc.exitCode(), newCwd);
    }

    // Synchronous — reduced timeout from 10s to 3s
    Q_INVOKABLE QString runCommand(const QString &command, const QString &cwd) {
        QProcess proc;
        proc.setWorkingDirectory(cwd.isEmpty() ? currentUserHome() : cwd);
        proc.setProcessChannelMode(QProcess::SeparateChannels);
        proc.start("/bin/bash", QStringList() << "-c" << command);

        if (!proc.waitForStarted(2000)) {
            return buildCommandResult("", "Failed to start command", -1, cwd);
        }

        // Reduced timeout: 3s max for synchronous calls (was 10s)
        proc.waitForFinished(3000);

        QString stdoutStr = QString::fromUtf8(proc.readAllStandardOutput());
        QString stderrStr = QString::fromUtf8(proc.readAllStandardError());

        QString newCwd = cwd.isEmpty() ? currentUserHome() : cwd;
        if (command.trimmed().startsWith("cd ")) {
            QProcess pwdProc;
            pwdProc.setWorkingDirectory(newCwd);
            pwdProc.start("/bin/bash", QStringList() << "-c" << command + " && pwd");
            if (pwdProc.waitForFinished(2000)) {
                QString pwd = QString::fromUtf8(pwdProc.readAllStandardOutput()).trimmed();
                if (!pwd.isEmpty()) newCwd = pwd;
            }
        }

        return buildCommandResult(stdoutStr, stderrStr, proc.exitCode(), newCwd);
    }

    // Asynchronous — for terminal commands, long-running tasks
    Q_INVOKABLE QString runCommandAsync(const QString &command, const QString &cwd) {
        QString cmdId = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
        QString workDir = cwd.isEmpty() ? currentUserHome() : cwd;

        QProcess *proc = new QProcess(this);
        proc->setWorkingDirectory(workDir);
        proc->setProcessChannelMode(QProcess::SeparateChannels);
        proc->setProperty("cmdId", cmdId);
        proc->setProperty("cmdCwd", workDir);
        proc->setProperty("cmdCommand", command);

        // Stream stdout incrementally
        connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc]() {
            QString cmdId = proc->property("cmdId").toString();
            QString data = QString::fromUtf8(proc->readAllStandardOutput());
            emit commandOutput(cmdId, data);
        });

        // Stream stderr incrementally
        connect(proc, &QProcess::readyReadStandardError, this, [this, proc]() {
            QString cmdId = proc->property("cmdId").toString();
            QString data = QString::fromUtf8(proc->readAllStandardError());
            emit commandError(cmdId, data);
        });

        // Completion handler
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int exitCode, QProcess::ExitStatus) {
            QString cmdId = proc->property("cmdId").toString();
            QString cwd = proc->property("cmdCwd").toString();
            emit commandFinished(cmdId, exitCode, cwd);
            proc->deleteLater();
        });

        proc->start("/bin/bash", QStringList() << "-c" << command);
        qDebug() << "SystemManager: async command" << cmdId << "started:" << command;
        return cmdId;
    }

signals:
    void commandOutput(const QString &cmdId, const QString &data);
    void commandError(const QString &cmdId, const QString &data);
    void commandFinished(const QString &cmdId, int exitCode, const QString &cwd);
    void authResult(bool success);
    void userOpResult(const QString &operation, bool success, const QString &detail);
    void displayInfoReady(const QString &xrandrOutput);
    void clipboardReady(const QString &text);
    void gpuInfoReady(const QString &gpuLine);
    void timeInfoReady(const QString &timezone, bool ntpSync, bool ntpActive,
                       const QString &localTime, const QString &utcTime);
    void timezonesReady(const QStringList &timezones);
    void timeOpResult(const QString &operation, bool success, const QString &detail);


    // ════════════════════════════════════════════════
    // ── File System Operations
    // ════════════════════════════════════════════════

public:
    Q_INVOKABLE bool createDir(const QString &path) {
        if (path.isEmpty()) return false;
        QDir dir;
        bool ok = dir.mkpath(path);
        if (ok) qDebug() << "SystemManager: Created directory:" << path;
        else qWarning() << "SystemManager: Failed to create directory:" << path;
        return ok;
    }

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
            if (!info.isDir()) {
                item["ext"] = info.suffix().toLower();
            }
            items.append(item);
        }
        return QString::fromUtf8(QJsonDocument(items).toJson(QJsonDocument::Compact));
    }

    Q_INVOKABLE QString readFileContent(const QString &path) {
        QFile file(path);
        if (!file.exists()) return "";
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return "";
        QString content = file.readAll();
        file.close();
        return content;
    }

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

    Q_INVOKABLE bool renameFile(const QString &oldPath, const QString &newPath) {
        QFile file(oldPath);
        bool ok = file.rename(newPath);
        if (ok) qDebug() << "SystemManager: Renamed:" << oldPath << "->" << newPath;
        return ok;
    }

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

    Q_INVOKABLE bool openFile(const QString &path) {
        QFileInfo info(path);
        if (!info.exists()) return false;

        QString ext = info.suffix().toLower();
        QStringList args;

        if (ext == "pdf") {
            args << "evince" << path;
        } else if (ext == "xlsx" || ext == "xls" || ext == "ods" || ext == "csv") {
            args << "gnumeric" << path;
        } else if (ext == "doc" || ext == "docx" || ext == "odt" || ext == "pptx" || ext == "ppt") {
            args << "libreoffice" << "--norestore" << path;
        } else if (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif"
                   || ext == "bmp" || ext == "svg" || ext == "webp") {
            args << "feh" << "--scale-down" << path;
        } else {
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
    // ── Clipboard Operations (Qt ↔ Wayland ↔ XWayland)
    //
    // PERF: pasteFromClipboardAsync() replaces blocking poll.
    //       copyToClipboard() xsel path already non-blocking.
    // ════════════════════════════════════════════════

    Q_INVOKABLE bool copyToClipboard(const QString &text) {
        QClipboard *clipboard = QGuiApplication::clipboard();
        if (clipboard) {
            clipboard->setText(text);
            qDebug() << "SystemManager: copyToClipboard via Qt OK";
        }

        // Also push to X11 clipboard for XWayland apps (async, non-blocking)
        {
            QProcess *proc = new QProcess(this);
            QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
            env.insert("DISPLAY", ":0");
            proc->setProcessEnvironment(env);
            proc->start("xsel", QStringList() << "--clipboard" << "--input");
            proc->waitForStarted(1000);
            proc->write(text.toUtf8());
            proc->closeWriteChannel();
            connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    proc, &QProcess::deleteLater);
        }

        return true;
    }

    // Legacy synchronous paste — kept for backward compat, reduced timeout
    Q_INVOKABLE QString pasteFromClipboard() {
        // Primary: Wayland clipboard
        {
            QProcess proc;
            QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
            env.insert("WAYLAND_DISPLAY", "wayland-0");
            env.insert("XDG_RUNTIME_DIR", currentXdgRuntimeDir());
            proc.setProcessEnvironment(env);
            proc.start("wl-paste", QStringList() << "--no-newline");
            proc.waitForFinished(500);  // Reduced from 2000ms → 500ms
            if (proc.exitCode() == 0) {
                QString result = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
                if (!result.isEmpty() && result != "No selection") {
                    return result;
                }
            }
        }

        // Fallback: Qt native clipboard
        QClipboard *clipboard = QGuiApplication::clipboard();
        if (clipboard) {
            QString text = clipboard->text();
            if (!text.isEmpty()) {
                return text;
            }
        }

        return "";
    }

    // ASYNC paste — emits clipboardReady(text) without blocking UI
    Q_INVOKABLE void pasteFromClipboardAsync() {
        QProcess *proc = new QProcess(this);
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", currentXdgRuntimeDir());
        proc->setProcessEnvironment(env);

        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int exitCode, QProcess::ExitStatus) {
            QString text;
            if (exitCode == 0) {
                text = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
                if (text == "No selection") text = "";
            }

            // Fallback to Qt clipboard
            if (text.isEmpty()) {
                QClipboard *clipboard = QGuiApplication::clipboard();
                if (clipboard) text = clipboard->text();
            }

            if (!text.isEmpty()) {
                emit clipboardReady(text);
            }
            proc->deleteLater();
        });

        proc->start("wl-paste", QStringList() << "--no-newline");
    }


    // ════════════════════════════════════════════════
    // ── Display Settings (ASYNC — non-blocking)
    // ════════════════════════════════════════════════

    // ASYNC display info — emits displayInfoReady(xrandrOutput)
    Q_INVOKABLE void getDisplayInfoAsync() {
        QProcess *proc = new QProcess(this);
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", currentXdgRuntimeDir());
        proc->setProcessEnvironment(env);

        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int, QProcess::ExitStatus) {
            QString output = proc->readAllStandardOutput().trimmed();
            emit displayInfoReady(output);
            proc->deleteLater();
        });

        proc->start("xrandr", QStringList());
    }

    // Legacy synchronous — kept for backward compat
    Q_INVOKABLE QString getDisplayInfo() {
        QProcess proc;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", currentXdgRuntimeDir());
        proc.setProcessEnvironment(env);
        proc.start("xrandr", QStringList());
        proc.waitForFinished(3000);
        return proc.readAllStandardOutput().trimmed();
    }

    Q_INVOKABLE bool setDisplayResolution(int w, int h) {
        QProcess proc;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", currentXdgRuntimeDir());
        proc.setProcessEnvironment(env);

        QString mode = QString("%1x%2_60.00").arg(w).arg(h);
        if (w == 1280 && h == 800) mode = "1280x800";

        proc.start("xrandr", QStringList() << "--output" << "XWAYLAND0" << "--mode" << mode);
        proc.waitForFinished(5000);
        qDebug() << "SystemManager: setDisplayResolution" << mode << "exit:" << proc.exitCode();
        return proc.exitCode() == 0;
    }

    Q_INVOKABLE bool setDisplayScale(double scale) {
        QProcess proc;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", currentXdgRuntimeDir());
        proc.setProcessEnvironment(env);

        QString scaleStr = QString("%1x%1").arg(1.0 / scale);
        proc.start("xrandr", QStringList() << "--output" << "XWAYLAND0" << "--scale" << scaleStr);
        proc.waitForFinished(5000);
        qDebug() << "SystemManager: setDisplayScale" << scale << "exit:" << proc.exitCode();
        return proc.exitCode() == 0;
    }

    // ASYNC GPU info query — emits gpuInfoReady(gpuLine)
    Q_INVOKABLE void getGpuInfoAsync() {
        QProcess *proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int, QProcess::ExitStatus) {
            QString output = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            emit gpuInfoReady(output);
            proc->deleteLater();
        });
        proc->start("/bin/bash", QStringList() << "-c"
                     << "lspci 2>/dev/null | grep -i vga || echo 'VirtIO GPU'");
    }


    // ════════════════════════════════════════════════
    // ── Time Management (timedatectl — ASYNC, no helper dependency)
    // ════════════════════════════════════════════════

    // ASYNC: Fetch timezone, NTP status, local/UTC time — emits timeInfoReady
    Q_INVOKABLE void getTimeInfoAsync() {
        QProcess *proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int, QProcess::ExitStatus) {
            QString output = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            proc->deleteLater();

            // Parse timedatectl status output
            QString timezone, localTime, utcTime;
            bool ntpSync = false, ntpActive = false;

            QStringList lines = output.split('\n');
            for (const QString &line : lines) {
                QString trimmed = line.trimmed();
                if (trimmed.startsWith("Time zone:")) {
                    timezone = trimmed.mid(10).trimmed().split(' ').first();
                } else if (trimmed.startsWith("Local time:")) {
                    localTime = trimmed.mid(11).trimmed();
                } else if (trimmed.startsWith("Universal time:")) {
                    utcTime = trimmed.mid(15).trimmed();
                } else if (trimmed.startsWith("System clock synchronized:") || trimmed.startsWith("NTP synchronized:")) {
                    ntpSync = trimmed.contains("yes");
                } else if (trimmed.startsWith("NTP service:")) {
                    ntpActive = trimmed.contains("active");
                }
            }

            emit timeInfoReady(timezone, ntpSync, ntpActive, localTime, utcTime);
        });
        proc->start("timedatectl", QStringList() << "status");
    }

    // ASYNC: List all available timezones — emits timezonesReady
    Q_INVOKABLE void getTimezonesAsync() {
        QProcess *proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int, QProcess::ExitStatus) {
            QString output = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            QStringList zones = output.split('\n', Qt::SkipEmptyParts);
            emit timezonesReady(zones);
            proc->deleteLater();
        });
        proc->start("timedatectl", QStringList() << "list-timezones");
    }

    // ASYNC: Set timezone — emits timeOpResult
    Q_INVOKABLE void setTimezoneAsync(const QString &tz) {
        if (tz.isEmpty()) {
            emit timeOpResult("setTimezone", false, "No timezone provided");
            return;
        }
        QProcess *proc = new QProcess(this);
        QString tzSafe = tz;
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, tzSafe](int exitCode, QProcess::ExitStatus) {
            if (exitCode == 0) {
                emit timeOpResult("setTimezone", true, tzSafe);
                getTimeInfoAsync();
            } else {
                emit timeOpResult("setTimezone", false, QString::fromUtf8(proc->readAllStandardError()).trimmed());
            }
            proc->deleteLater();
        });
        proc->start("sudo", QStringList() << "timedatectl" << "set-timezone" << tz);
    }

    // ASYNC: Toggle NTP — emits timeOpResult
    Q_INVOKABLE void toggleNtpAsync(bool enable) {
        QProcess *proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc, enable](int exitCode, QProcess::ExitStatus) {
            if (exitCode == 0) {
                emit timeOpResult("toggleNtp", true, enable ? "enabled" : "disabled");
            } else {
                emit timeOpResult("toggleNtp", false, QString::fromUtf8(proc->readAllStandardError()).trimmed());
            }
            proc->deleteLater();
        });
        proc->start("sudo", QStringList() << "timedatectl" << "set-ntp" << (enable ? "true" : "false"));
    }

    // ASYNC: Set manual time — emits timeOpResult
    Q_INVOKABLE void setManualTimeAsync(const QString &timeStr) {
        if (timeStr.isEmpty()) {
            emit timeOpResult("setTime", false, "No time provided");
            return;
        }
        // Must disable NTP first, then set time
        QProcess *ntpProc = new QProcess(this);
        QString timeSafe = timeStr;
        connect(ntpProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, ntpProc, timeSafe](int, QProcess::ExitStatus) {
            ntpProc->deleteLater();
            QProcess *setProc = new QProcess(this);
            connect(setProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    this, [this, setProc, timeSafe](int exitCode, QProcess::ExitStatus) {
                if (exitCode == 0) {
                    emit timeOpResult("setTime", true, timeSafe);
                    getTimeInfoAsync();
                } else {
                    emit timeOpResult("setTime", false, QString::fromUtf8(setProc->readAllStandardError()).trimmed());
                }
                setProc->deleteLater();
            });
            setProc->start("sudo", QStringList() << "timedatectl" << "set-time" << timeSafe);
        });
        ntpProc->start("sudo", QStringList() << "timedatectl" << "set-ntp" << "false");
    }


    // ════════════════════════════════════════════════
    // ── Native App Window Management
    //
    // Uses Wayland-native approach: apps connect to Cage's
    // compositor via the inherited WAYLAND_DISPLAY env var.
    // xdotool is no longer needed.
    // ════════════════════════════════════════════════

    Q_INVOKABLE QString getMainWindowId() {
        if (m_mainWindow) return QString::number(m_mainWindow->winId());
        return "";
    }

    Q_INVOKABLE bool launchNativeApp(const QString &command) {
        if (command.isEmpty()) return false;

        // Dynamically resolve current user's environment
        uid_t uid = getuid();
        struct passwd *pw = getpwuid(uid);
        QString home = pw ? QString::fromUtf8(pw->pw_dir) : "/home/ainux";
        QString runtimeDir = QString("/run/user/%1").arg(uid);

        // Read the Wayland display from our current environment
        // (Cage sets WAYLAND_DISPLAY when it starts WhaleOS)
        QString waylandDisplay = qEnvironmentVariable("WAYLAND_DISPLAY", "wayland-0");

        // Tell native apps to connect to our Wayland compositor
        QString fullCmd = QString(
            "export WAYLAND_DISPLAY=%1; "
            "export XDG_RUNTIME_DIR=%2; "
            "export HOME=%3; "
            "export DBUS_SESSION_BUS_ADDRESS=unix:path=%2/bus; "
            "export DISPLAY=:0; "
            "exec %4"
        ).arg(waylandDisplay, runtimeDir, home, command);

        QProcess *proc = new QProcess(this);
        proc->setProgram("/bin/bash");
        proc->setArguments(QStringList() << "-c" << fullCmd);
        proc->start();

        qDebug() << "SystemManager: launchNativeApp" << command
                 << "WAYLAND_DISPLAY=" << waylandDisplay
                 << "started:" << proc->processId();
        return true;
    }

    // Legacy xdotool stubs — kept for QML compatibility, but no longer used
    Q_INVOKABLE QString findNativeWindow(const QString &) { return ""; }
    Q_INVOKABLE bool embedWindow(const QString &, const QString &, int, int, int, int) { return false; }
    Q_INVOKABLE bool moveEmbeddedWindow(const QString &, int, int, int, int) { return false; }
    Q_INVOKABLE bool closeNativeWindow(const QString &) { return false; }

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
    // ── Cached Home Directory (avoids repeated process spawns)
    // ════════════════════════════════════════════════

    Q_INVOKABLE QString getCachedHome() {
        if (m_cachedHome.isEmpty()) {
            m_cachedHome = currentUserHome();
        }
        return m_cachedHome;
    }


private:
    QQuickWindow *m_mainWindow;
    QString m_cachedHome;

    // ── Helpers ──

    QString currentUserHome() const {
        struct passwd *pw = getpwuid(getuid());
        return pw ? QString::fromUtf8(pw->pw_dir) : "/home/ainux";
    }

    QString currentXdgRuntimeDir() const {
        return QString("/run/user/%1").arg(getuid());
    }

    QString buildCommandResult(const QString &out, const QString &err,
                               int code, const QString &cwd) const {
        QJsonObject result;
        result["stdout"] = out;
        result["stderr"] = err;
        result["exitCode"] = code;
        result["cwd"] = cwd;
        return QString(QJsonDocument(result).toJson(QJsonDocument::Compact));
    }
};

#endif // SYSTEMMANAGER_H
