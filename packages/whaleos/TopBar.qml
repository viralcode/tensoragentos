import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: topBar
    height: 36
    color: Qt.rgba(0.08, 0.08, 0.08, 0.85)

    // ── OpenWhale state ──
    property bool owOnline: false
    property bool owPanelVisible: false
    property string owLogs: ""
    property bool owLogsFetching: false
    property bool owRestarting: false

    Component.onCompleted: { checkOwHealth(); }

    // Poll health every 10s
    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: checkOwHealth()
    }

    function checkOwHealth() {
        API.getHealth(function(online) {
            owOnline = online;
        });
    }

    function fetchLogs() {
        owLogsFetching = true;
        owLogs = "Fetching logs...";
        API.getLogs(50, function(status, data) {
            owLogsFetching = false;
            if (data && data.response) {
                owLogs = data.response;
            } else if (data && data.raw) {
                owLogs = data.raw;
            } else {
                owLogs = "Could not retrieve logs.\nOpenWhale may be offline.";
            }
        });
    }

    function restartOw() {
        owRestarting = true;
        API.execCommand("Run this exact command: sudo systemctl restart openwhale", function(status, data) {
            // Give it a few seconds to come back up
            restartTimer.start();
        });
    }

    Timer {
        id: restartTimer; interval: 5000; repeat: false
        onTriggered: { owRestarting = false; checkOwHealth(); }
    }

    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.borderColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        // ── Left: Whale Icon + OpenWhale (Clickable) ──
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: owLeftRow.width + 16
            height: 28
            radius: root.radiusSm
            color: owAreaMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: owLeftRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "🐋"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Status dot
                Rectangle {
                    width: 7; height: 7; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: owOnline ? root.accentGreen : root.accentRed

                    // Subtle pulse for online
                    SequentialAnimation on opacity {
                        running: owOnline
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.5; duration: 1200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: "OpenWhale"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: root.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: owAreaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    owPanelVisible = !owPanelVisible;
                    userMenu.visible = false;
                    if (owPanelVisible) { checkOwHealth(); }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ── Center: Clock ──
        Text {
            id: clockText
            text: Qt.formatTime(new Date(), "h:mm AP")
            font.pixelSize: 13
            font.weight: Font.Medium
            color: root.textPrimary
            Layout.alignment: Qt.AlignVCenter

            Timer {
                interval: 30000
                running: true
                repeat: true
                onTriggered: clockText.text = Qt.formatTime(new Date(), "h:mm AP")
            }
        }

        Item { Layout.fillWidth: true }

        // ── Right: Settings + User ──
        Row {
            spacing: 10
            Layout.alignment: Qt.AlignVCenter

            // Settings gear
            Rectangle {
                width: 26
                height: 26
                radius: 6
                color: settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "⚙"
                    font.pixelSize: 14
                    color: root.textSecondary
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openApp("settings", "Settings", "⚙")
                }
            }

            // User avatar
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: root.bgElevated
                border.color: root.borderColor
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: root.currentUser.charAt(0).toUpperCase()
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: root.textPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { userMenu.visible = !userMenu.visible; owPanelVisible = false; }
                }
            }
        }
    }

    // ════════════════════════════════════════════
    // ── OpenWhale Status Panel (Dropdown) ──
    // ════════════════════════════════════════════
    Rectangle {
        id: owPanel
        visible: owPanelVisible
        anchors.left: parent.left
        anchors.top: parent.bottom
        anchors.leftMargin: 10
        anchors.topMargin: 6
        width: 360
        height: owPanelCol.height + 20
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor
        border.width: 1
        z: 1000
        clip: true

        Column {
            id: owPanelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 10

            // ── Header ──
            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    text: "🐋"
                    font.pixelSize: 18
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "OpenWhale Engine"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    Text {
                        text: "AI Agent Platform"
                        font.pixelSize: 10
                        color: root.textMuted
                    }
                }
            }

            // ── Separator ──
            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── Status Row ──
            Rectangle {
                width: parent.width
                height: 44
                radius: root.radiusSm
                color: owOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.06) : Qt.rgba(0.94, 0.27, 0.27, 0.06)
                border.color: owOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.15) : Qt.rgba(0.94, 0.27, 0.27, 0.15)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Rectangle {
                        width: 9; height: 9; radius: 5
                        color: owRestarting ? root.accentOrange : owOnline ? root.accentGreen : root.accentRed
                    }

                    Text {
                        text: owRestarting ? "Restarting..." : owOnline ? "Online" : "Offline"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: owRestarting ? root.accentOrange : owOnline ? root.accentGreen : root.accentRed
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Port 7777"
                        font.pixelSize: 10
                        color: root.textMuted
                    }
                }
            }

            // ── Action Buttons ──
            RowLayout {
                width: parent.width
                spacing: 8

                // Restart Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: root.radiusSm
                    color: restartMa.containsMouse ? Qt.rgba(0.98, 0.45, 0.09, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "🔄"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: owRestarting ? "Restarting..." : "Restart"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: owRestarting ? root.accentOrange : root.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: restartMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !owRestarting
                        onClicked: restartOw()
                    }
                }

                // View Logs Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: root.radiusSm
                    color: logsMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "📋"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: owLogsFetching ? "Fetching..." : "View Logs"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: owLogsFetching ? root.accentBlue : root.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: logsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !owLogsFetching
                        onClicked: fetchLogs()
                    }
                }

                // Refresh Health
                Rectangle {
                    width: 32; height: 32
                    radius: root.radiusSm
                    color: refreshMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⟳"
                        font.pixelSize: 16
                        color: root.textSecondary
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: checkOwHealth()
                    }
                }
            }

            // ── Logs Viewer ──
            Rectangle {
                visible: owLogs !== ""
                width: parent.width
                height: 200
                radius: root.radiusSm
                color: Qt.rgba(0, 0, 0, 0.4)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                clip: true

                // Header bar
                Rectangle {
                    id: logsHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 24
                    color: Qt.rgba(1, 1, 1, 0.03)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Text {
                            text: "LOGS — journalctl -u openwhale"
                            font.pixelSize: 9
                            color: root.textMuted
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "✕"
                            font.pixelSize: 10
                            color: clearLogsMa.containsMouse ? root.accentRed : root.textMuted

                            MouseArea {
                                id: clearLogsMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: owLogs = ""
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.04)
                    }
                }

                Flickable {
                    anchors.top: logsHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    contentHeight: logsText.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: logsText
                        width: parent.width
                        text: owLogs
                        font.pixelSize: 10
                        font.family: "monospace"
                        color: "#a1a1aa"
                        wrapMode: Text.WrapAnywhere
                        lineHeight: 1.4
                    }
                }
            }
        }
    }

    // ── Click-outside to close OpenWhale panel ──
    MouseArea {
        visible: owPanelVisible
        anchors.fill: parent
        anchors.topMargin: parent.height
        parent: topBar.parent  // cover the whole desktop
        z: 999
        onClicked: { owPanelVisible = false; }
    }

    // ── User Dropdown Menu ──
    Rectangle {
        id: userMenu
        visible: false
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.rightMargin: 14
        anchors.topMargin: 6
        width: 160
        height: menuCol.height + 12
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor
        border.width: 1
        z: 1000

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2

            // User info
            Rectangle {
                width: parent.width
                height: 36
                radius: root.radiusSm
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Text { text: "👤"; font.pixelSize: 13 }
                    Text {
                        text: root.currentUser
                        font.pixelSize: 12
                        color: root.textPrimary
                        font.weight: Font.Medium
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: root.borderColor
            }

            // Logout
            Rectangle {
                width: parent.width
                height: 34
                radius: root.radiusSm
                color: logoutMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Text { text: "🚪"; font.pixelSize: 12 }
                    Text {
                        text: "Sign Out"
                        font.pixelSize: 12
                        color: root.textSecondary
                    }
                }

                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { userMenu.visible = false; root.doLogout(); }
                }
            }
        }
    }

    function openApp(appId, title, icon) {
        userMenu.visible = false;
        owPanelVisible = false;
        // Check if already open
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].appId === appId) return;
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: appId, title: title, icon: icon });
        root.openWindows = wins;
    }
}
