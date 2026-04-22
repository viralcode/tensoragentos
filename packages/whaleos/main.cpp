/*
 * WhaleOS — TensorAgent OS Native Desktop Shell
 *
 * ClipboardCompositor: Subclasses QWaylandQuickCompositor and adds
 * retainedSelectionReceived() override to sync Wayland→QClipboard.
 * Includes proper QML default property for child items (WaylandOutput etc).
 */

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDebug>
#include <QFontDatabase>
#include <QClipboard>
#include <QMimeData>
#include <QTimer>
#include <QMouseEvent>
#include <QQmlListProperty>
#include <QtWaylandCompositor/QWaylandQuickCompositor>
#include "systemmanager.h"
#include "ptyprocess.h"
#include "terminalemulator.h"


// ════════════════════════════════════════════════════════════════
// RightClickFilter — blocks right-click ONLY for Chromium windows
// ════════════════════════════════════════════════════════════════
class RightClickFilter : public QObject {
    Q_OBJECT
public:
    explicit RightClickFilter(QObject *parent = nullptr) : QObject(parent) {}
protected:
    bool eventFilter(QObject *obj, QEvent *event) override {
        if (event->type() == QEvent::MouseButtonPress ||
            event->type() == QEvent::MouseButtonRelease) {
            QMouseEvent *me = static_cast<QMouseEvent *>(event);
            if (me->button() == Qt::RightButton && isChromiumWindow(obj)) {
                return true;  // Block right-click for Chromium only
            }
        }
        return QObject::eventFilter(obj, event);
    }
private:
    // Walk up the QObject parent chain to find the AppWindow.
    // AppWindow has QML properties "appId" and "windowTitle" —
    // if either contains "chromium" this is a Chromium window.
    bool isChromiumWindow(QObject *obj) {
        QObject *current = obj;
        while (current) {
            QVariant appId = current->property("appId");
            if (appId.isValid() && !appId.toString().isEmpty()) {
                if (appId.toString().contains("chromium", Qt::CaseInsensitive))
                    return true;
            }
            QVariant title = current->property("windowTitle");
            if (title.isValid() && !title.toString().isEmpty()) {
                if (title.toString().contains("chromium", Qt::CaseInsensitive))
                    return true;
            }
            current = current->parent();
        }
        return false;
    }
};

// ════════════════════════════════════════════════════════════════
// ClipboardCompositor — bridges Wayland clipboard → QClipboard
// ════════════════════════════════════════════════════════════════
class ClipboardCompositor : public QWaylandQuickCompositor {
    Q_OBJECT
    // QML default property — allows child items (WaylandOutput, XdgShell, etc.)
    Q_PROPERTY(QQmlListProperty<QObject> data READ data DESIGNABLE false)
    Q_CLASSINFO("DefaultProperty", "data")

public:
    ClipboardCompositor(QObject *parent = nullptr)
        : QWaylandQuickCompositor(parent) {}

    QQmlListProperty<QObject> data() {
        return QQmlListProperty<QObject>(this, nullptr,
            &ClipboardCompositor::appendData,
            &ClipboardCompositor::countData,
            &ClipboardCompositor::atData,
            &ClipboardCompositor::clearData);
    }

protected:
    // Called by Qt when a Wayland client copies and retainedSelection is true.
    // Qt reads data from client's data source via pipe FD and passes QMimeData.
    void retainedSelectionReceived(QMimeData *mimeData) override {
        if (!mimeData) return;

        if (mimeData->hasText()) {
            QString text = mimeData->text().trimmed();
            if (!text.isEmpty() && text != m_lastText) {
                m_lastText = text;
                // Defer to avoid re-entrancy
                QTimer::singleShot(0, this, [text]() {
                    QClipboard *cb = QGuiApplication::clipboard();
                    if (cb) {
                        cb->setText(text);
                        qDebug() << "ClipboardCompositor: synced Wayland→QClipboard:"
                                 << text.left(50);
                    }
                });
            }
        }
    }

private:
    QString m_lastText;
    QList<QObject *> m_data;

    static void appendData(QQmlListProperty<QObject> *prop, QObject *obj) {
        auto *self = static_cast<ClipboardCompositor *>(prop->object);
        obj->setParent(self);
        self->m_data.append(obj);
    }
    static qsizetype countData(QQmlListProperty<QObject> *prop) {
        return static_cast<ClipboardCompositor *>(prop->object)->m_data.count();
    }
    static QObject *atData(QQmlListProperty<QObject> *prop, qsizetype idx) {
        return static_cast<ClipboardCompositor *>(prop->object)->m_data.at(idx);
    }
    static void clearData(QQmlListProperty<QObject> *prop) {
        static_cast<ClipboardCompositor *>(prop->object)->m_data.clear();
    }
};


// ════════════════════════════════════════════════════════════════
// main()
// ════════════════════════════════════════════════════════════════

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("TensorAgentOS");
    app.setOrganizationName("TensorAgentOS");

    // Block right-click globally — prevents Chromium context menus
    RightClickFilter *rcFilter = new RightClickFilter(&app);
    app.installEventFilter(rcFilter);
    qDebug() << "TensorAgent OS: Right-click filter installed";

    // ── Register Font Awesome fonts BEFORE QML loads ──
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

    // ── QML Engine ──
    QQmlApplicationEngine engine;

    // Register ClipboardCompositor — replaces WaylandCompositor in QML
    qmlRegisterType<ClipboardCompositor>("TensorAgent.Compositor", 1, 0, "ClipboardCompositor");

    // Register PTY terminal types for real Linux terminal support
    qmlRegisterType<PtyProcess>("TensorAgent.Terminal", 1, 0, "PtyProcess");
    qmlRegisterType<TerminalEmulator>("TensorAgent.Terminal", 1, 0, "TerminalEmulator");

    // Register SystemManager for kernel-level OS operations
    SystemManager sysManager;
    engine.rootContext()->setContextProperty("sysManager", &sysManager);

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

    // Load the compositor QML
    qDebug() << "TensorAgent OS: Loading main.qml from /opt/ainux/whaleos/main.qml";
    engine.load(QUrl::fromLocalFile("/opt/ainux/whaleos/main.qml"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "TensorAgent OS: Failed to load main.qml - no root objects!";
        return -1;
    }

    // Find the Window inside the compositor for SystemManager
    QObject *root = engine.rootObjects().first();
    QQuickWindow *mainWindow = root ? root->findChild<QQuickWindow *>() : nullptr;
    if (mainWindow) {
        sysManager.setMainWindow(mainWindow);
        qDebug() << "TensorAgent OS: Main window WId:" << mainWindow->winId();
    }

    qDebug() << "TensorAgent OS: Desktop shell loaded successfully";
    return app.exec();
}

#include "main.moc"
