import QtQuick
import QtQuick.Layouts

Rectangle {
    id: appWindow
    x: initialX
    y: initialY
    width: Math.min(700, windowArea ? windowArea.width - 20 : 700)
    height: Math.min(450, windowArea ? windowArea.height - 20 : 450)
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
    property int initialY: 80

    Rectangle {
        anchors.fill: parent; anchors.margins: -1; radius: parent.radius + 1
        color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.4); border.width: 2; z: -1
    }

    // ── Title Bar ──
    Rectangle {
        id: titleBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 40; color: root.bgElevated; radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.radius; color: parent.color }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.borderColor }

        MouseArea {
            id: dragArea; anchors.fill: parent; drag.target: appWindow
            drag.minimumX: -appWindow.width + 100; drag.minimumY: 0
            drag.maximumX: windowArea ? windowArea.width - 100 : 800
            drag.maximumY: windowArea ? windowArea.height - 40 : 600
            cursorShape: Qt.SizeAllCursor
            onPressed: function(mouse) {
                root.bringToFront(appWindow);
            }
        }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8; spacing: 8

            Text {
                text: appWindow.windowIcon
                font.family: root.iconFont; font.pixelSize: 14
                color: root.accentBlue
            }

            Text {
                text: appWindow.windowTitle
                font.pixelSize: 13; font.weight: Font.DemiBold
                color: root.textPrimary; Layout.fillWidth: true
            }

            // ── Close Button ──
            Rectangle {
                width: 13; height: 13; radius: 6.5
                Layout.alignment: Qt.AlignVCenter
                color: closeHover.containsMouse ? "#ef4444" : Qt.darker("#ef4444", 1.5)
                border.color: Qt.darker("#ef4444", 1.3); border.width: 0.5
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
            source: {
                if (appId === "settings") return "SettingsApp.qml";
                if (appId === "providers") return "ProvidersApp.qml";
                if (appId === "skills") return "SkillsApp.qml";
                if (appId === "apps") return "AppsApp.qml";
                if (appId === "terminal") return "TerminalApp.qml";
                if (appId === "mcp") return "McpApp.qml";
                if (appId === "agents") return "AgentsApp.qml";
                return "";
            }
        }
    }

    function closeWindow() {
        var wins = root.openWindows;
        var newWins = [];
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].appId !== appId) newWins.push(wins[i]);
        }
        root.openWindows = newWins;
    }

    // ── Resize Handle ──
    MouseArea {
        width: 16; height: 16
        anchors.right: parent.right; anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        property point pressPos
        onPressed: function(mouse) { pressPos = Qt.point(mouse.x, mouse.y); root.bringToFront(appWindow); }
        onPositionChanged: function(mouse) {
            var dx = mouse.x - pressPos.x;
            var dy = mouse.y - pressPos.y;
            appWindow.width = Math.max(350, appWindow.width + dx);
            appWindow.height = Math.max(250, appWindow.height + dy);
        }
    }
}
