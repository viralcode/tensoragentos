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

    // ── Authenticate user against /etc/shadow ──
    Q_INVOKABLE bool authenticate(const QString &username, const QString &password) {
        if (username.isEmpty() || password.isEmpty()) return false;

        // Use python3 crypt to verify password hash from /etc/shadow
        // (su fails under systemd without a tty)
        QProcess proc;
        proc.start("sudo", QStringList() << "python3" << "-c" <<
            "import crypt,sys\n"
            "u=sys.stdin.readline().strip()\n"
            "p=sys.stdin.readline().strip()\n"
            "for line in open('/etc/shadow'):\n"
            "  parts=line.strip().split(':')\n"
            "  if parts[0]==u:\n"
            "    h=parts[1]\n"
            "    if h and crypt.crypt(p,h)==h:\n"
            "      print('AUTH_OK')\n"
            "      sys.exit(0)\n"
            "print('FAIL')");
        if (!proc.waitForStarted(2000)) return false;
        proc.write((username + "\n" + password + "\n").toUtf8());
        proc.closeWriteChannel();
        proc.waitForFinished(3000);

        QString output = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        bool ok = output.contains("AUTH_OK");

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
    // ── Clipboard Operations (X11 + Wayland bridge) ──
    // ════════════════════════════════════════════════

    Q_INVOKABLE bool copyToClipboard(const QString &text) {
        bool ok = false;

        // Write to X11 clipboard (for XWayland apps: Chrome, Mousepad, etc.)
        {
            QProcess proc;
            QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
            env.insert("DISPLAY", ":0");
            proc.setProcessEnvironment(env);
            proc.start("xclip", QStringList() << "-selection" << "clipboard");
            proc.waitForStarted(2000);
            proc.write(text.toUtf8());
            proc.closeWriteChannel();
            proc.waitForFinished(2000);
            if (proc.exitCode() == 0) ok = true;
        }

        // Also write to Wayland clipboard (for QML shell context menu)
        {
            QProcess proc;
            QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
            env.insert("WAYLAND_DISPLAY", "wayland-0");
            env.insert("XDG_RUNTIME_DIR", "/run/user/1000");
            proc.setProcessEnvironment(env);
            proc.start("wl-copy", QStringList());
            proc.waitForStarted(2000);
            proc.write(text.toUtf8());
            proc.closeWriteChannel();
            proc.waitForFinished(2000);
            if (proc.exitCode() == 0) ok = true;
        }

        qDebug() << "SystemManager: copyToClipboard:" << (ok ? "OK" : "FAIL");
        return ok;
    }

    Q_INVOKABLE QString pasteFromClipboard() {
        // Try X11 clipboard first (most apps run on XWayland)
        {
            QProcess proc;
            QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
            env.insert("DISPLAY", ":0");
            proc.setProcessEnvironment(env);
            proc.start("xclip", QStringList() << "-selection" << "clipboard" << "-o");
            proc.waitForFinished(2000);
            if (proc.exitCode() == 0) {
                QString result = proc.readAllStandardOutput().trimmed();
                if (!result.isEmpty()) return result;
            }
        }

        // Fallback to Wayland clipboard
        {
            QProcess proc;
            QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
            env.insert("WAYLAND_DISPLAY", "wayland-0");
            env.insert("XDG_RUNTIME_DIR", "/run/user/1000");
            proc.setProcessEnvironment(env);
            proc.start("wl-paste", QStringList() << "--no-newline");
            proc.waitForFinished(2000);
            if (proc.exitCode() == 0) {
                return proc.readAllStandardOutput().trimmed();
            }
        }

        return "";
    }

    // ════════════════════════════════════════════════
    // ── Display Settings (via xrandr — works under XWayland on Cage) ──
    // ════════════════════════════════════════════════

    Q_INVOKABLE QString getDisplayInfo() {
        QProcess proc;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", "/run/user/1000");
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
        env.insert("XDG_RUNTIME_DIR", "/run/user/1000");
        proc.setProcessEnvironment(env);
        // xrandr custom modes use WxH_60.00 naming
        QString mode = QString("%1x%2_60.00").arg(w).arg(h);
        // For the default 1280x800, use the native mode name
        if (w == 1280 && h == 800) mode = "1280x800";
        proc.start("xrandr", QStringList() << "--output" << "XWAYLAND0" << "--mode" << mode);
        proc.waitForFinished(5000);
        qDebug() << "SystemManager: setDisplayResolution" << mode << "exit:" << proc.exitCode();
        return proc.exitCode() == 0;
    }

    Q_INVOKABLE bool setDisplayScale(double scale) {
        // Use xrandr transform for scaling
        QProcess proc;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("WAYLAND_DISPLAY", "wayland-0");
        env.insert("XDG_RUNTIME_DIR", "/run/user/1000");
        proc.setProcessEnvironment(env);
        // xrandr scale uses inverse: 2x scale = --scale 0.5x0.5
        QString scaleStr = QString("%1x%1").arg(1.0 / scale);
        proc.start("xrandr", QStringList() << "--output" << "XWAYLAND0" << "--scale" << scaleStr);
        proc.waitForFinished(5000);
        qDebug() << "SystemManager: setDisplayScale" << scale << "exit:" << proc.exitCode();
        return proc.exitCode() == 0;
    }


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
    // ── Native App Window Management (XWayland + xdotool) ──
    // Under Cage (Wayland), native apps must run on XWayland.
    // We launch them with DISPLAY=:0 and use xdotool to
    // position XWayland windows over QML content areas.
    // ════════════════════════════════════════════════

    Q_INVOKABLE QString getMainWindowId() {
        if (m_mainWindow) return QString::number(m_mainWindow->winId());
        return "";
    }

    // Helper: set DISPLAY=:0 on a QProcess so xdotool targets XWayland
    void setXWaylandEnv(QProcess &proc) {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        proc.setProcessEnvironment(env);
    }

    // Launch a native app via XWayland (Cage manages display)
    Q_INVOKABLE bool launchNativeApp(const QString &command) {
        if (command.isEmpty()) return false;

        QProcess *proc = new QProcess();
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("DISPLAY", ":0");
        env.insert("XDG_RUNTIME_DIR", "/run/user/1000");
        env.insert("HOME", "/home/ainux");
        proc->setProcessEnvironment(env);
        proc->setProgram("/bin/bash");
        proc->setArguments(QStringList() << "-c" << command);
        
        qint64 pid = 0;
        bool ok = proc->startDetached(&pid);
        qDebug() << "SystemManager: launchNativeApp" << command << "pid:" << pid << "ok:" << ok;
        delete proc;
        return ok;
    }

    // Non-blocking single attempt to find an XWayland window by name
    // Called repeatedly from QML via a Timer for async polling
    Q_INVOKABLE QString findNativeWindow(const QString &searchName) {
        if (searchName.isEmpty()) return "";

        QProcess search;
        setXWaylandEnv(search);
        search.start("xdotool", QStringList() << "search" << "--name" << searchName);
        if (!search.waitForStarted(500)) return "";
        search.waitForFinished(800);
        QString output = search.readAllStandardOutput().trimmed();
        if (!output.isEmpty()) {
            QStringList ids = output.split('\n');
            QString winId = ids.last();
            qDebug() << "SystemManager: Found XWayland window:" << winId << "for" << searchName;
            return winId;
        }
        return "";
    }

    // Position and resize an XWayland window to overlay a QML content area
    Q_INVOKABLE bool embedWindow(const QString &childWinId, const QString &parentWinId, int x, int y, int w, int h) {
        if (childWinId.isEmpty()) return false;
        Q_UNUSED(parentWinId)  // Not used for XWayland overlay approach

        // Remove window decorations
        QProcess undecorate;
        setXWaylandEnv(undecorate);
        undecorate.start("xdotool", QStringList() << "set_window" << "--overrideredirect" << "1" << childWinId);
        undecorate.waitForFinished(800);

        // Resize first (no --sync to avoid extra blocking)
        QProcess resize;
        setXWaylandEnv(resize);
        resize.start("xdotool", QStringList() << "windowsize" << childWinId << QString::number(w) << QString::number(h));
        resize.waitForFinished(800);

        // Move to absolute position (no --sync to avoid extra blocking)
        QProcess move;
        setXWaylandEnv(move);
        move.start("xdotool", QStringList() << "windowmove" << childWinId << QString::number(x) << QString::number(y));
        move.waitForFinished(800);

        // Activate
        QProcess activate;
        setXWaylandEnv(activate);
        activate.start("xdotool", QStringList() << "windowactivate" << childWinId);
        activate.waitForFinished(800);

        qDebug() << "SystemManager: Positioned XWayland window" << childWinId << "at" << x << y << w << "x" << h;
        return true;
    }

    Q_INVOKABLE bool moveEmbeddedWindow(const QString &winId, int x, int y, int w, int h) {
        if (winId.isEmpty()) return false;

        QProcess move;
        setXWaylandEnv(move);
        move.start("xdotool", QStringList() << "windowmove" << winId << QString::number(x) << QString::number(y));
        move.waitForFinished(500);

        QProcess resize;
        setXWaylandEnv(resize);
        resize.start("xdotool", QStringList() << "windowsize" << winId << QString::number(w) << QString::number(h));
        resize.waitForFinished(500);
        return true;
    }

    Q_INVOKABLE bool closeNativeWindow(const QString &winId) {
        if (winId.isEmpty()) return false;

        QProcess proc;
        setXWaylandEnv(proc);
        proc.start("xdotool", QStringList() << "windowclose" << winId);
        proc.waitForFinished(1000);
        qDebug() << "SystemManager: Closed XWayland window:" << winId;
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

private:
    QQuickWindow *m_mainWindow;
};

#endif // SYSTEMMANAGER_H
