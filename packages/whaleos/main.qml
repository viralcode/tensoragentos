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
}
