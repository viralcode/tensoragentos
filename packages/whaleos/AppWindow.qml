import QtQuick
import QtQuick.Layouts
import QtWayland.Compositor

Rectangle {
    id: appWindow
    x: initialX
    y: initialY
    // width/height set once in Component.onCompleted — NOT live-bound to windowArea
    // so chat panel expanding/collapsing never resizes open windows
    width: Math.round(700 * root.sf)
    height: Math.round(450 * root.sf)
    radius: root.radiusLg
    color: root.bgSurface
    border.color: root.borderColor
    border.width: 1
    clip: true
    z: 10

    property string windowTitle: "App"
    property string windowIcon: ""
    property string appId: ""
    property Item windowArea: parent
    property int initialX: 100
    property int initialY: Math.round(80 * root.sf)

    // Maximize state
    property bool maximized: false
    property real savedX: 0
    property real savedY: 0
    property real savedW: 0
    property real savedH: 0

    function toggleMaximize() {
        if (maximized) {
            appWindow.x = savedX; appWindow.y = savedY;
            appWindow.width = savedW; appWindow.height = savedH;
            maximized = false;
        } else {
            savedX = appWindow.x; savedY = appWindow.y;
            savedW = appWindow.width; savedH = appWindow.height;
            // Position at windowArea origin (accounts for top bar)
            if (windowArea) {
                appWindow.x = windowArea.x;
                appWindow.y = windowArea.y;
                appWindow.width = windowArea.width;
                appWindow.height = windowArea.height;
            }
            maximized = true;
        }
    }

    // Native app properties
    property bool isNative: appId.indexOf("native-") === 0 || appId.indexOf("wayland-") === 0
    property string nativeCmd: ""
    property string nativeSearchName: ""
    property int launchCountdown: 60

    // Set initial size + launch native app in one onCompleted handler
    // (QML only allows ONE Component.onCompleted per component)
    Component.onCompleted: {
        if (windowArea) {
            // Native apps get a larger window
            var initW = isNative ? Math.round(900 * root.sf) : Math.round(700 * root.sf);
            var initH = isNative ? Math.round(600 * root.sf) : Math.round(450 * root.sf);
            appWindow.width  = Math.min(initW, windowArea.width  - Math.round(20 * root.sf));
            appWindow.height = Math.min(initH, windowArea.height - Math.round(20 * root.sf));
        }
        if (isNative && nativeCmd.length > 0) {
            nativeLauncher.start();
        }
    }

    property string nativeWinId: ""

    // Wayland surface (assigned by compositor)
    property var shellSurface: null
    property var toplevelObj: null

    // When a native surface arrives, configure it to fill the content area
    // (the area below WhaleOS's title bar)
    onShellSurfaceChanged: {
        if (shellSurface && toplevelObj) {
            surfaceConfigureTimer.restart();
        }
    }
    onToplevelObjChanged: {
        if (shellSurface && toplevelObj) {
            surfaceConfigureTimer.restart();
        }
    }
    Timer {
        id: surfaceConfigureTimer
        interval: 150; repeat: false
        onTriggered: {
            if (toplevelObj && contentArea.width > 0 && contentArea.height > 0) {
                var sz = Qt.size(contentArea.width, contentArea.height);
                // sendMaximized tells Chrome to fill the given size
                // WhaleOS provides the title bar (SSD), so Chrome won't draw its own
                if (typeof toplevelObj.sendMaximized === "function") {
                    toplevelObj.sendMaximized(sz);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: -1; radius: parent.radius + 1
        color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.4); border.width: 2; z: -1
    }

    // ── Title Bar (always shown — compositor provides window controls) ──
    Rectangle {
        id: titleBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(40 * root.sf)
        color: root.bgElevated; radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.radius; color: parent.color }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.borderColor }

        MouseArea {
            id: dragArea; anchors.fill: parent; drag.target: maximized ? null : appWindow
            drag.minimumX: -appWindow.width + Math.round(100 * root.sf); drag.minimumY: 0
            drag.maximumX: windowArea ? windowArea.width - Math.round(100 * root.sf) : 800
            drag.maximumY: windowArea ? windowArea.height - Math.round(40 * root.sf) : 600
            cursorShape: Qt.SizeAllCursor
            onPressed: function(mouse) {
                root.bringToFront(appWindow);
            }
            onDoubleClicked: toggleMaximize()
        }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(14 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)

            Text {
                text: appWindow.windowTitle
                font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold
                color: root.textPrimary; Layout.fillWidth: true
            }

            // ── Maximize Button ──
            Item {
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); radius: width / 2
                    color: maxHover.containsMouse ? "#22c55e" : Qt.darker("#22c55e", 1.5)
                    border.color: Qt.darker("#22c55e", 1.3); border.width: 0.5
                }
                MouseArea { id: maxHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggleMaximize() }
            }

            // ── Close Button ──
            Item {
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); radius: width / 2
                    color: closeHover.containsMouse ? "#ef4444" : Qt.darker("#ef4444", 1.5)
                    border.color: Qt.darker("#ef4444", 1.3); border.width: 0.5
                }
                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: closeWindow() }
            }
        }
    }


    // ── Body ──
    Item {
        id: contentArea
        clip: true  // Prevent native app surface from overflowing
        anchors.top: titleBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom

        // Re-send configure when window is resized so native app fills properly
        onWidthChanged: if (isNative && toplevelObj) surfaceConfigureTimer.restart()
        onHeightChanged: if (isNative && toplevelObj) surfaceConfigureTimer.restart()

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onPressed: function(mouse) {
                root.bringToFront(appWindow);
                mouse.accepted = false;
            }
        }

        Loader {
            anchors.fill: parent
            visible: !isNative
            source: {
                if (isNative) return "";
                if (appId === "nativeapps") return "NativeAppsLauncher.qml";
                if (appId === "settings") return "SettingsApp.qml";
                if (appId === "providers") return "ProvidersApp.qml";
                if (appId === "skills") return "SkillsApp.qml";
                if (appId === "extensions") return "AppsApp.qml";
                if (appId === "terminal") return "TerminalApp.qml";
                if (appId === "mcp") return "McpApp.qml";
                if (appId === "agents") return "AgentsApp.qml";
                if (appId === "files") return "FileManagerApp.qml";
                return "";
            }
        }

        // Embedded Wayland surface (rendered by compositor)
        ShellSurfaceItem {
            id: surfaceItem
            anchors.fill: parent
            visible: shellSurface !== null
            shellSurface: appWindow.shellSurface
            autoCreatePopupItems: true

            onSurfaceDestroyed: {
                // Native app closed itself — close the AppWindow too
                closeWindow();
            }
        }

        // Native app loading indicator (shown until surface arrives or timeout)

        Column {
            anchors.centerIn: parent
            spacing: Math.round(12 * root.sf)
            visible: isNative && shellSurface === null && appWindow.launchCountdown > 0

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * root.sf)
                Repeater {
                    model: 3
                    Rectangle {
                        width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: width / 2; color: "#3b82f6"
                        SequentialAnimation on opacity {
                            running: isNative && shellSurface === null; loops: Animation.Infinite
                            PauseAnimation { duration: index * 200 }
                            NumberAnimation { to: 0.2; duration: 400 }
                            NumberAnimation { to: 1.0; duration: 400 }
                            PauseAnimation { duration: (2 - index) * 200 }
                        }
                    }
                }
            }

            Text {
                text: "Launching " + windowTitle + "..."
                font.pixelSize: Math.round(13 * root.sf); color: root.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Auto-close if app doesn't produce a surface in time
        Timer {
            id: launchTimeout
            interval: 1000; running: isNative && shellSurface === null && appWindow.launchCountdown > 0; repeat: true
            onTriggered: {
                appWindow.launchCountdown--;
                if (appWindow.launchCountdown <= 0) {
                    root.showToast(windowTitle + " did not open — it may be a CLI tool", "info");
                    closeWindow();
                }
            }
        }
    }

    // ── Native App Launch ──
    Timer {
        id: nativeLauncher
        interval: 200; running: false; repeat: false
        onTriggered: {
            if (!isNative || nativeCmd.length === 0) return;
            sysManager.launchNativeApp(nativeCmd);
        }
    }


    function closeWindow() {
        // Send close to Wayland surface if applicable
        if (toplevelObj) {
            toplevelObj.sendClose();
        }

        var wins = root.openWindows;
        var newWins = [];
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].appId !== appId) newWins.push(wins[i]);
        }
        root.openWindows = newWins;
    }

    // ── Resize Handle ──
    MouseArea {
        width: Math.round(16 * root.sf); height: Math.round(16 * root.sf)
        anchors.right: parent.right; anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        property point pressPos
        onPressed: function(mouse) { pressPos = Qt.point(mouse.x, mouse.y); root.bringToFront(appWindow); }
        onPositionChanged: function(mouse) {
            var dx = mouse.x - pressPos.x;
            var dy = mouse.y - pressPos.y;
            appWindow.width = Math.max(Math.round(350 * root.sf), appWindow.width + dx);
            appWindow.height = Math.max(Math.round(250 * root.sf), appWindow.height + dy);
        }
    }
}
