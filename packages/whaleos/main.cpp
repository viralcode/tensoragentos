#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QDebug>

int main(int argc, char *argv[]) {
    // Don't hardcode platform - let Qt auto-detect from environment
    // Cage sets WAYLAND_DISPLAY which Qt will pick up automatically
    QGuiApplication app(argc, argv);
    app.setApplicationName("WhaleOS");
    app.setOrganizationName("TensorAgentOS");

    QQmlApplicationEngine engine;

    // Log QML errors
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() {
            qCritical() << "WhaleOS: QML object creation failed!";
        }, Qt::QueuedConnection);

    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
        [](const QList<QQmlError> &warnings) {
            for (const auto &w : warnings)
                qWarning() << "QML Warning:" << w.toString();
        });

    qDebug() << "WhaleOS: Loading main.qml from /opt/ainux/whaleos/main.qml";
    engine.load(QUrl::fromLocalFile("/opt/ainux/whaleos/main.qml"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "WhaleOS: Failed to load main.qml - no root objects!";
        return -1;
    }

    qDebug() << "WhaleOS: Desktop shell loaded successfully";
    return app.exec();
}
