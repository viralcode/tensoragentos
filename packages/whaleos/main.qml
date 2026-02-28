import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint | Qt.Window
    title: "TensorAgent OS"
    color: "#0d0d0d"

    // ── Global State ──
    property bool loggedIn: false
    property string currentUser: ""
    property string sessionId: ""
    property var openWindows: []

    // ── API ──
    property string apiBase: "http://127.0.0.1:7777/dashboard/api"

    // ── Theme Constants ──
    readonly property color bgVoid: "#0d0d0d"
    readonly property color bgSurface: "#141414"
    readonly property color bgElevated: "#1c1c1c"
    readonly property color bgCard: "#1f1f1f"
    readonly property color borderColor: "#2a2a2a"
    readonly property color borderLight: "#333333"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#999999"
    readonly property color textMuted: "#666666"
    readonly property color accentBlue: "#3b82f6"
    readonly property color accentGreen: "#22c55e"
    readonly property color accentRed: "#ef4444"
    readonly property color accentOrange: "#f97316"
    readonly property int radiusSm: 6
    readonly property int radiusMd: 10
    readonly property int radiusLg: 14

    // ── Icon Fonts (Font Awesome) ──
    property string iconFont: faLoader.name
    property string iconFontBrands: faBrandsLoader.name

    FontLoader { id: faLoader; source: "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/webfonts/fa-solid-900.woff2" }
    FontLoader { id: faBrandsLoader; source: "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/webfonts/fa-brands-400.woff2" }
    FontLoader { id: systemFont; source: "" }

    // ── Window Management ──
    property int nextZ: 100

    function bringToFront(win) {
        nextZ++;
        win.z = nextZ;
    }

    // ── Login Screen ──
    Loader {
        id: loginLoader
        anchors.fill: parent
        active: !root.loggedIn
        source: "LoginScreen.qml"
    }

    // ── Desktop ──
    Loader {
        id: desktopLoader
        anchors.fill: parent
        active: root.loggedIn
        source: "Desktop.qml"
    }

    function onLoginSuccess(user, session) {
        currentUser = user;
        sessionId = session;
        loggedIn = true;
    }

    function doLogout() {
        loggedIn = false;
        currentUser = "";
        sessionId = "";
        openWindows = [];
    }

    // ── Toast Notification System ──
    function showToast(message, type) {
        toastText.text = message;
        toastText.color = "#fff";
        if (type === "success") {
            toastBg.color = Qt.rgba(0.13, 0.77, 0.37, 0.95);
            toastIcon.text = "✓";
            toastIcon.color = "#fff";
        } else if (type === "error") {
            toastBg.color = Qt.rgba(0.94, 0.27, 0.27, 0.95);
            toastIcon.text = "✕";
            toastIcon.color = "#fff";
        } else {
            toastBg.color = Qt.rgba(0.23, 0.51, 0.96, 0.95);
            toastIcon.text = "ℹ";
            toastIcon.color = "#fff";
        }
        toastContainer.opacity = 1.0;
        toastContainer.y = 20;
        toastTimer.restart();
    }

    Item {
        id: toastContainer
        anchors.horizontalCenter: parent.horizontalCenter
        y: -60; z: 99999
        width: toastRow.width + 32; height: 44
        opacity: 0.0

        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Rectangle {
            id: toastBg
            anchors.fill: parent; radius: 12
            color: Qt.rgba(0.13, 0.77, 0.37, 0.95)

            Row {
                id: toastRow
                anchors.centerIn: parent; spacing: 8
                Text { id: toastIcon; text: "✓"; font.pixelSize: 16; font.weight: Font.Bold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                Text { id: toastText; text: ""; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Timer {
            id: toastTimer; interval: 3000
            onTriggered: { toastContainer.opacity = 0.0; toastContainer.y = -60; }
        }
    }
}
