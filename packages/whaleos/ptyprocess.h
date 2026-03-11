/*
 * PtyProcess — Real PTY (pseudo-terminal) for TensorAgent OS Terminal
 *
 * Uses Linux forkpty() to spawn a real shell process with a proper TTY.
 * This enables full interactive terminal support:
 *   • nano, vim, vi, emacs — full TUI editors
 *   • top, htop — real-time system monitors
 *   • ssh, python, node REPLs — interactive sessions
 *   • man, less, more — pager programs
 *   • All curses/ncurses applications
 *
 * The PTY master FD is monitored via QSocketNotifier for non-blocking
 * integration with the Qt event loop.
 */

#ifndef PTYPROCESS_H
#define PTYPROCESS_H

#include <QObject>
#include <QSocketNotifier>
#include <QDebug>
#include <QProcessEnvironment>
#include <QTimer>

#include <pty.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <termios.h>
#include <fcntl.h>
#include <errno.h>
#include <pwd.h>
#include <cstring>
#include <cstdlib>

class PtyProcess : public QObject {
    Q_OBJECT

public:
    explicit PtyProcess(QObject *parent = nullptr)
        : QObject(parent), m_masterFd(-1), m_pid(-1),
          m_notifier(nullptr), m_rows(24), m_cols(80) {}

    ~PtyProcess() {
        stop();
    }

    Q_INVOKABLE bool start(int rows, int cols) {
        if (m_masterFd >= 0) {
            qWarning() << "PtyProcess: Already running";
            return false;
        }

        m_rows = rows;
        m_cols = cols;

        // Set up terminal size
        struct winsize ws;
        memset(&ws, 0, sizeof(ws));
        ws.ws_row = rows;
        ws.ws_col = cols;

        // Fork with a new PTY
        m_pid = forkpty(&m_masterFd, nullptr, nullptr, &ws);

        if (m_pid < 0) {
            qCritical() << "PtyProcess: forkpty() failed:" << strerror(errno);
            return false;
        }

        if (m_pid == 0) {
            // ── Child process: exec a shell ──

            // Get user's shell
            struct passwd *pw = getpwuid(getuid());
            const char *shell = pw && pw->pw_shell && pw->pw_shell[0]
                                ? pw->pw_shell : "/bin/bash";
            const char *home = pw && pw->pw_dir ? pw->pw_dir : "/home";
            const char *user = pw && pw->pw_name ? pw->pw_name : "user";

            // Set up environment
            setenv("TERM", "xterm-256color", 1);
            setenv("COLORTERM", "truecolor", 1);
            setenv("HOME", home, 1);
            setenv("USER", user, 1);
            setenv("LOGNAME", user, 1);
            setenv("SHELL", shell, 1);
            setenv("LANG", "en_US.UTF-8", 1);
            setenv("LC_ALL", "en_US.UTF-8", 1);

            // cd to home
            if (chdir(home) != 0) {
                chdir("/");
            }

            // Exec the shell as a login shell
            // The '-' prefix makes bash treat it as a login shell
            const char *shellBase = strrchr(shell, '/');
            shellBase = shellBase ? shellBase + 1 : shell;

            char loginShell[256];
            snprintf(loginShell, sizeof(loginShell), "-%s", shellBase);

            execlp(shell, loginShell, (char *)nullptr);

            // If exec fails, try bash
            execlp("/bin/bash", "-bash", (char *)nullptr);
            execlp("/bin/sh", "-sh", (char *)nullptr);

            _exit(127);
        }

        // ── Parent process ──

        // Set master fd to non-blocking
        int flags = fcntl(m_masterFd, F_GETFL);
        fcntl(m_masterFd, F_SETFL, flags | O_NONBLOCK);

        // Monitor the PTY master fd for incoming data
        m_notifier = new QSocketNotifier(m_masterFd, QSocketNotifier::Read, this);
        connect(m_notifier, &QSocketNotifier::activated, this, &PtyProcess::onDataReady);

        qDebug() << "PtyProcess: Started shell PID" << m_pid
                 << "on PTY fd" << m_masterFd
                 << "size" << cols << "x" << rows;

        return true;
    }

    Q_INVOKABLE void stop() {
        if (m_notifier) {
            m_notifier->setEnabled(false);
            delete m_notifier;
            m_notifier = nullptr;
        }

        if (m_pid > 0) {
            kill(m_pid, SIGHUP);
            // Give it a moment, then force kill
            QTimer::singleShot(200, this, [this]() {
                if (m_pid > 0) {
                    kill(m_pid, SIGKILL);
                    int status;
                    waitpid(m_pid, &status, WNOHANG);
                    m_pid = -1;
                }
            });
        }

        if (m_masterFd >= 0) {
            close(m_masterFd);
            m_masterFd = -1;
        }
    }

    Q_INVOKABLE void write(const QString &data) {
        if (m_masterFd < 0) return;

        QByteArray bytes = data.toUtf8();
        ssize_t written = ::write(m_masterFd, bytes.constData(), bytes.size());
        if (written < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                // Retry once after a short delay
                QTimer::singleShot(10, this, [this, bytes]() {
                    if (m_masterFd >= 0) {
                        ::write(m_masterFd, bytes.constData(), bytes.size());
                    }
                });
            } else {
                qWarning() << "PtyProcess: write failed:" << strerror(errno);
            }
        }
    }

    Q_INVOKABLE void writeBytes(const QByteArray &data) {
        if (m_masterFd < 0) return;
        ::write(m_masterFd, data.constData(), data.size());
    }

    Q_INVOKABLE void resize(int rows, int cols) {
        if (m_masterFd < 0) return;

        m_rows = rows;
        m_cols = cols;

        struct winsize ws;
        memset(&ws, 0, sizeof(ws));
        ws.ws_row = rows;
        ws.ws_col = cols;

        if (ioctl(m_masterFd, TIOCSWINSZ, &ws) < 0) {
            qWarning() << "PtyProcess: resize failed:" << strerror(errno);
        } else {
            // Send SIGWINCH to the child process group
            if (m_pid > 0) {
                kill(-m_pid, SIGWINCH);
            }
        }
    }

    Q_INVOKABLE bool isRunning() const {
        if (m_pid <= 0) return false;
        int status;
        pid_t result = waitpid(m_pid, &status, WNOHANG);
        return result == 0;  // Still running
    }

    Q_INVOKABLE int rows() const { return m_rows; }
    Q_INVOKABLE int cols() const { return m_cols; }

signals:
    void dataReceived(const QByteArray &data);
    void finished(int exitCode);

private slots:
    void onDataReady() {
        if (m_masterFd < 0) return;

        char buf[16384];
        while (true) {
            ssize_t n = ::read(m_masterFd, buf, sizeof(buf));
            if (n > 0) {
                QByteArray data(buf, n);
                emit dataReceived(data);
            } else if (n < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // No more data right now
                }
                // EIO typically means child exited
                if (errno == EIO) {
                    checkChildExit();
                    break;
                }
                break;
            } else {
                // n == 0: EOF
                checkChildExit();
                break;
            }
        }
    }

private:
    void checkChildExit() {
        if (m_pid <= 0) return;

        int status;
        pid_t result = waitpid(m_pid, &status, WNOHANG);
        if (result > 0) {
            int exitCode = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
            m_pid = -1;

            if (m_notifier) {
                m_notifier->setEnabled(false);
            }

            qDebug() << "PtyProcess: Shell exited with code" << exitCode;
            emit finished(exitCode);
        }
    }

    int m_masterFd;
    pid_t m_pid;
    QSocketNotifier *m_notifier;
    int m_rows;
    int m_cols;
};

#endif // PTYPROCESS_H
