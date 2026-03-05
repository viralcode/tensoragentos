#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDebug>
#include <QKeyEvent>
#include <QQuickItem>
#include <QInputMethodEvent>
#include <QFontDatabase>
#include "systemmanager.h"

// Global clipboard event filter — intercepts Ctrl+V and Ctrl+C
// before Qt's broken Wayland clipboard handler processes them
class ClipboardFilter : public QObject {
    Q_OBJECT
public:
    explicit ClipboardFilter(SystemManager *mgr, QObject *parent = nullptr)
        : QObject(parent), m_mgr(mgr) {}
    
protected:
    bool eventFilter(QObject *obj, QEvent *event) override {
        if (event->type() == QEvent::KeyPress) {
            QKeyEvent *ke = static_cast<QKeyEvent *>(event);
            
            // Ctrl+V — Paste
            if (ke->key() == Qt::Key_V && (ke->modifiers() & Qt::ControlModifier)) {
                QString text = m_mgr->pasteFromClipboard();
                if (!text.isEmpty()) {
                    // Send as input method event to the focused item
                    QGuiApplication *app = qobject_cast<QGuiApplication *>(QGuiApplication::instance());
                    if (app && app->focusObject()) {
                        QInputMethodEvent ime;
                        ime.setCommitString(text);
                        QCoreApplication::sendEvent(app->focusObject(), &ime);
                        qDebug() << "ClipboardFilter: Pasted" << text.length() << "chars";
                    }
                    return true;  // Consume the event
                }
            }
            
            // Ctrl+C — Copy
            if (ke->key() == Qt::Key_C && (ke->modifiers() & Qt::ControlModifier)) {
                QGuiApplication *app = qobject_cast<QGuiApplication *>(QGuiApplication::instance());
                if (app && app->focusObject()) {
                    QQuickItem *item = qobject_cast<QQuickItem *>(app->focusObject());
                    if (item) {
                        QVariant sel = item->property("selectedText");
                        if (sel.isValid() && !sel.toString().isEmpty()) {
                            m_mgr->copyToClipboard(sel.toString());
                            qDebug() << "ClipboardFilter: Copied" << sel.toString().length() << "chars";
                            return true;
                        }
                    }
                }
            }
        }
        return QObject::eventFilter(obj, event);
    }
    
private:
    SystemManager *m_mgr;
};

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("TensorAgentOS");
    app.setOrganizationName("TensorAgentOS");

    // ── Register Font Awesome fonts BEFORE QML loads ──
    // This is the only reliable approach: QFontDatabase makes fonts available
    // by family name immediately, without needing FontLoader or file:// paths.
    const QString fontDir = "/opt/ainux/whaleos/fonts";
    QStringList fontFiles = {
        fontDir + "/fa-solid-900.ttf",
        fontDir + "/fa-brands-400.ttf",
        fontDir + "/fa-regular-400.ttf"
    };
    for (const QString &fontPath : fontFiles) {
        int id = QFontDatabase::addApplicationFont(fontPath);
        if (id < 0) {
            qWarning() << "TensorAgent OS: Failed to load font:" << fontPath;
        } else {
            QStringList families = QFontDatabase::applicationFontFamilies(id);
            qDebug() << "TensorAgent OS: Loaded font:" << fontPath << "→" << families;
        }
    }

    QQmlApplicationEngine engine;

    // Register SystemManager for kernel-level OS operations
    SystemManager sysManager;
    engine.rootContext()->setContextProperty("sysManager", &sysManager);

    // Install global clipboard event filter
    ClipboardFilter *clipFilter = new ClipboardFilter(&sysManager, &app);
    app.installEventFilter(clipFilter);
    qDebug() << "TensorAgent OS: Clipboard event filter installed";

    // Log QML errors
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() {
            qCritical() << "TensorAgent OS: QML object creation failed!";
        }, Qt::QueuedConnection);

    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
        [](const QList<QQmlError> &warnings) {
            for (const auto &w : warnings)
                qWarning() << "QML Warning:" << w.toString();
        });

    qDebug() << "TensorAgent OS: Loading main.qml from /opt/ainux/whaleos/main.qml";
    engine.load(QUrl::fromLocalFile("/opt/ainux/whaleos/main.qml"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "TensorAgent OS: Failed to load main.qml - no root objects!";
        return -1;
    }

    // Pass main window to SystemManager for X11 window operations
    QQuickWindow *mainWindow = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (mainWindow) {
        sysManager.setMainWindow(mainWindow);
        qDebug() << "TensorAgent OS: Main window WId:" << mainWindow->winId();
    }

    qDebug() << "TensorAgent OS: Desktop shell loaded successfully";
    return app.exec();
}

#include "main.moc"
