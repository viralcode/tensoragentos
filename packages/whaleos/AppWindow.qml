import QtQuick
import QtQuick.Layouts

Rectangle {
    id: appWindow
    x: initialX
    y: initialY
    width: 700
    height: 500
    radius: root.radiusLg
    color: root.bgSurface
    border.color: root.borderColor
    border.width: 1
    clip: true
    z: 10

    property string windowTitle: "App"
    property string windowIcon: "📱"
    property string appId: ""
    property Item windowArea: parent
    property int initialX: 100
    property int initialY: 80

    // Shadow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.4)
        border.width: 2
        z: -1
    }

    // ── Title Bar ──
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: root.bgElevated
        radius: root.radiusLg

        // Square off bottom corners
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.radius
            color: parent.color
        }

        // Bottom border
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.borderColor
        }

        // Drag handle
        MouseArea {
            id: dragArea
            anchors.fill: parent
            drag.target: appWindow
            drag.minimumX: 0
            drag.minimumY: 0
            cursorShape: Qt.SizeAllCursor

            onPressed: { appWindow.z = 100; }
            onReleased: { appWindow.z = 10; }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: windowIcon
                font.pixelSize: 14
            }

            Text {
                text: windowTitle
                font.pixelSize: 13
                font.weight: Font.Medium
                color: root.textPrimary
            }

            Item { Layout.fillWidth: true }

            // Close button
            Rectangle {
                width: 28
                height: 28
                radius: 6
                color: closeMouse.containsMouse ? root.accentRed : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: closeMouse.containsMouse ? "#ffffff" : root.textSecondary
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: closeWindow()
                }
            }
        }
    }

    // ── App Content ──
    Item {
        id: contentArea
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Loader {
            anchors.fill: parent
            source: {
                switch (appId) {
                    case "settings":  return "SettingsApp.qml";
                    case "skills":    return "SkillsApp.qml";
                    case "apps":      return "AppsApp.qml";
                    case "providers": return "ProvidersApp.qml";
                    case "terminal":  return "TerminalApp.qml";
                    default:          return "";
                }
            }
        }
    }

    // ── Resize Handle ──
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 16
        height: 16
        cursorShape: Qt.SizeFDiagCursor

        property point pressPos

        onPressed: function(mouse) {
            pressPos = Qt.point(mouse.x, mouse.y);
        }

        onPositionChanged: function(mouse) {
            var dx = mouse.x - pressPos.x;
            var dy = mouse.y - pressPos.y;
            appWindow.width = Math.max(400, appWindow.width + dx);
            appWindow.height = Math.max(300, appWindow.height + dy);
        }
    }

    function closeWindow() {
        var wins = root.openWindows.filter(function(w) { return w.appId !== appId; });
        root.openWindows = wins;
    }

    // Entry animation
    Component.onCompleted: {
        opacity = 0;
        scale = 0.95;
    }

    Behavior on opacity { NumberAnimation { duration: 200 } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Timer {
        running: true
        interval: 50
        onTriggered: { appWindow.opacity = 1; appWindow.scale = 1; }
    }
}
