#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDebug>
#include "systemmanager.h"

int main(int argc, char *argv[]) {
    // Don't hardcode platform - let Qt auto-detect from environment
    // Cage sets WAYLAND_DISPLAY which Qt will pick up automatically
    QGuiApplication app(argc, argv);
    app.setApplicationName("TensorAgentOS");
    app.setOrganizationName("TensorAgentOS");

    QQmlApplicationEngine engine;

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

    qDebug() << "TensorAgent OS: Loading main.qml from /opt/ainux/whaleos/main.qml";
    engine.load(QUrl::fromLocalFile("/opt/ainux/whaleos/main.qml"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "TensorAgent OS: Failed to load main.qml - no root objects!";
        return -1;
    }

    qDebug() << "TensorAgent OS: Desktop shell loaded successfully";
    return app.exec();
}
