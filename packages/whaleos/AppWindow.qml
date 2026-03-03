import QtQuick
import QtQuick.Layouts

Rectangle {
    id: appWindow
    x: initialX
    y: initialY
    width: Math.min(Math.round(700 * root.sf), windowArea ? windowArea.width - Math.round(20 * root.sf) : Math.round(700 * root.sf))
    height: Math.min(Math.round(450 * root.sf), windowArea ? windowArea.height - Math.round(20 * root.sf) : Math.round(450 * root.sf))
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

    // Native app properties
    property bool isNative: appId.indexOf("native-") === 0
    property string nativeCmd: ""
    property string nativeSearchName: ""
    property string nativeWinId: ""

    Rectangle {
        anchors.fill: parent; anchors.margins: -1; radius: parent.radius + 1
        color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.4); border.width: 2; z: -1
    }

    // ── Title Bar ──
    Rectangle {
        id: titleBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(40 * root.sf); color: root.bgElevated; radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.radius; color: parent.color }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.borderColor }

        MouseArea {
            id: dragArea; anchors.fill: parent; drag.target: appWindow
            drag.minimumX: -appWindow.width + Math.round(100 * root.sf); drag.minimumY: 0
            drag.maximumX: windowArea ? windowArea.width - Math.round(100 * root.sf) : 800
            drag.maximumY: windowArea ? windowArea.height - Math.round(40 * root.sf) : 600
            cursorShape: Qt.SizeAllCursor
            onPressed: function(mouse) {
                root.bringToFront(appWindow);
            }
        }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(14 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)

            Text {
                text: appWindow.windowIcon
                font.family: root.iconFont; font.pixelSize: Math.round(14 * root.sf)
                color: root.accentBlue
            }

            Text {
                text: appWindow.windowTitle
                font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold
                color: root.textPrimary; Layout.fillWidth: true
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
        anchors.top: titleBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        clip: true

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
                if (appId === "settings") return "SettingsApp.qml";
                if (appId === "providers") return "ProvidersApp.qml";
                if (appId === "skills") return "SkillsApp.qml";
                if (appId === "apps") return "AppsApp.qml";
                if (appId === "terminal") return "TerminalApp.qml";
                if (appId === "mcp") return "McpApp.qml";
                if (appId === "agents") return "AgentsApp.qml";
                if (appId === "files") return "FileManagerApp.qml";
                return "";
            }
        }

        // Native app loading indicator
        Column {
            anchors.centerIn: parent
            spacing: Math.round(12 * root.sf)
            visible: isNative && nativeWinId === ""

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * root.sf)
                Repeater {
                    model: 3
                    Rectangle {
                        width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: width / 2; color: "#3b82f6"
                        SequentialAnimation on opacity {
                            running: isNative && nativeWinId === ""; loops: Animation.Infinite
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
    }

    // ── Native App Embedding ──
    Timer {
        id: nativeLauncher
        interval: 100; running: false; repeat: false
        onTriggered: launchNative()
    }

    Component.onCompleted: {
        if (isNative && nativeCmd.length > 0) {
            nativeLauncher.start();
        }
    }

    function launchNative() {
        if (!isNative || nativeCmd.length === 0) return;

        var winId = sysManager.launchNativeApp(nativeCmd, nativeSearchName);
        if (winId.length > 0) {
            nativeWinId = winId;
            var mainWinId = sysManager.getMainWindowId();
            var globalPos = contentArea.mapToItem(null, 0, 0);
            sysManager.embedWindow(winId, mainWinId,
                Math.round(globalPos.x), Math.round(globalPos.y),
                Math.round(contentArea.width), Math.round(contentArea.height));
        } else {
            root.showToast("Failed to launch " + windowTitle, "error");
        }
    }

    // Track position/size changes for native windows
    onXChanged: updateNativeGeometry()
    onYChanged: updateNativeGeometry()
    onWidthChanged: updateNativeGeometry()
    onHeightChanged: updateNativeGeometry()

    function updateNativeGeometry() {
        if (!isNative || nativeWinId.length === 0) return;
        var globalPos = contentArea.mapToItem(null, 0, 0);
        sysManager.moveEmbeddedWindow(nativeWinId,
            Math.round(globalPos.x), Math.round(globalPos.y),
            Math.round(contentArea.width), Math.round(contentArea.height));
    }

    function closeWindow() {
        // Close native window if applicable
        if (isNative && nativeWinId.length > 0) {
            sysManager.closeNativeWindow(nativeWinId);
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
