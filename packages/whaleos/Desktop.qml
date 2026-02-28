import QtQuick
import QtQuick.Layouts

Rectangle {
    id: desktop
    anchors.fill: parent
    color: "#050510"

    // ── Beautiful Gradient Wallpaper ──
    // Base deep blue-purple gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0c0a1a" }
            GradientStop { position: 0.3; color: "#0f1628" }
            GradientStop { position: 0.6; color: "#101830" }
            GradientStop { position: 1.0; color: "#080e1c" }
        }
    }

    // Aurora glow - top left (teal/cyan)
    Rectangle {
        x: -parent.width * 0.1
        y: parent.height * 0.05
        width: parent.width * 0.7
        height: parent.height * 0.5
        radius: width / 2
        opacity: 0.15
        rotation: -15
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0ea5e9" }
            GradientStop { position: 0.4; color: "#06b6d4" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Aurora glow - center (purple/indigo)
    Rectangle {
        x: parent.width * 0.2
        y: parent.height * 0.1
        width: parent.width * 0.65
        height: parent.height * 0.55
        radius: width / 2
        opacity: 0.12
        rotation: 10
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#7c3aed" }
            GradientStop { position: 0.5; color: "#4f46e5" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Aurora glow - right (blue/electric)
    Rectangle {
        x: parent.width * 0.4
        y: parent.height * 0.15
        width: parent.width * 0.55
        height: parent.height * 0.45
        radius: width / 2
        opacity: 0.1
        rotation: 20
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2563eb" }
            GradientStop { position: 0.5; color: "#1d4ed8" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Warm accent glow - bottom right (rose/pink)
    Rectangle {
        x: parent.width * 0.5
        y: parent.height * 0.5
        width: parent.width * 0.5
        height: parent.height * 0.4
        radius: width / 2
        opacity: 0.06
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#e11d48" }
            GradientStop { position: 0.5; color: "#be185d" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Star field Canvas
    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // Draw stars
            var seed = 42;
            function pseudoRandom() {
                seed = (seed * 16807 + 0) % 2147483647;
                return seed / 2147483647;
            }

            for (var i = 0; i < 80; i++) {
                var sx = pseudoRandom() * width;
                var sy = pseudoRandom() * height;
                var sr = pseudoRandom() * 1.2 + 0.3;
                var so = pseudoRandom() * 0.4 + 0.1;
                ctx.beginPath();
                ctx.fillStyle = "rgba(255, 255, 255, " + so + ")";
                ctx.arc(sx, sy, sr, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // ── Whale Logo Watermark ──
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: 14
        opacity: 0.35

        Rectangle {
            width: 90; height: 90; radius: 45
            color: Qt.rgba(0.15, 0.3, 0.7, 0.2)
            border.color: Qt.rgba(0.4, 0.6, 1.0, 0.25)
            border.width: 1.5
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                anchors.centerIn: parent
                width: 56; height: 56
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.fillStyle = "#93c5fd";
                    ctx.moveTo(8, 36);
                    ctx.quadraticCurveTo(4, 22, 14, 16);
                    ctx.quadraticCurveTo(24, 8, 38, 12);
                    ctx.quadraticCurveTo(50, 14, 52, 26);
                    ctx.quadraticCurveTo(56, 34, 50, 40);
                    ctx.quadraticCurveTo(52, 46, 56, 42);
                    ctx.quadraticCurveTo(60, 38, 58, 50);
                    ctx.quadraticCurveTo(54, 54, 48, 46);
                    ctx.quadraticCurveTo(38, 50, 28, 48);
                    ctx.quadraticCurveTo(16, 46, 8, 36);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.fillStyle = "#0f172a";
                    ctx.arc(22, 24, 2.5, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.fillStyle = "#ffffff";
                    ctx.arc(23, 23, 1, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.strokeStyle = "#93c5fd";
                    ctx.lineWidth = 1.5;
                    ctx.moveTo(32, 12); ctx.lineTo(32, 4); ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(28, 4); ctx.quadraticCurveTo(32, -1, 36, 4); ctx.stroke();
                }
            }
        }

        Text {
            text: "D E E P O S"
            font.pixelSize: 13
            font.weight: Font.Normal
            font.letterSpacing: 2
            color: "#93c5fd"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── Top Bar ──
    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // ── Window Area ──
    Item {
        id: windowArea
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: dockArea.top
    }

    // ── App Windows ──
    Repeater {
        model: root.openWindows
        delegate: AppWindow {
            windowTitle: modelData.title
            windowIcon: modelData.icon
            appId: modelData.appId
            windowArea: windowArea
            initialX: parent.width / 2 - 350 + index * 30
            initialY: 80 + index * 30
        }
    }

    // ── Dock + Chat ──
    ColumnLayout {
        id: dockArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 10
        width: Math.min(parent.width - 32, 600)

        AppDock { Layout.alignment: Qt.AlignHCenter }
        ChatBar { Layout.fillWidth: true }
    }
}
