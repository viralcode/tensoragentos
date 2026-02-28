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
    property string owUptime: ""

    Component.onCompleted: { checkOwHealth(); }

    // Poll health every 10s
    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: checkOwHealth()
    }

    function checkOwHealth() {
        // Try helper endpoint first (port 7778), fallback to OW health
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:7778/status");
        xhr.timeout = 3000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        owOnline = (d.status === "active");
                        if (d.uptime) owUptime = d.uptime;
                    } catch(e) { owOnline = false; }
                } else {
                    // Fallback: check port 7777 directly
                    API.getHealth(function(online) { owOnline = online; });
                }
            }
        };
        xhr.ontimeout = function() {
            API.getHealth(function(online) { owOnline = online; });
        };
        xhr.send();
    }

    function fetchLogs() {
        owLogsFetching = true;
        owLogs = "Fetching logs...";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:7778/logs");
        xhr.timeout = 8000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                owLogsFetching = false;
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        owLogs = d.logs || "No log data returned.";
                    } catch(e) {
                        owLogs = xhr.responseText || "Parse error.";
                    }
                } else {
                    owLogs = "Helper service not available (port 7778).\n\nView logs via SSH:\n  journalctl -u openwhale -n 50 --no-pager";
                }
            }
        };
        xhr.ontimeout = function() {
            owLogsFetching = false;
            owLogs = "Request timed out.\nTry: journalctl -u openwhale -n 50 --no-pager";
        };
        xhr.send();
    }

    function restartOw() {
        owRestarting = true;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/restart");
        xhr.timeout = 12000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                restartTimer.start();
            }
        };
        xhr.ontimeout = function() {
            owRestarting = false;
        };
        xhr.send();
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

        // ── Left: Whale + OpenWhale (Clickable) ──
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

                // Whale drawn as canvas (no emoji)
                Canvas {
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#60a5fa";
                        ctx.beginPath();
                        ctx.moveTo(2, 10);
                        ctx.quadraticCurveTo(1, 6, 4, 4);
                        ctx.quadraticCurveTo(7, 2, 11, 3);
                        ctx.quadraticCurveTo(14, 4, 14, 7);
                        ctx.quadraticCurveTo(16, 9, 14, 11);
                        ctx.quadraticCurveTo(15, 13, 16, 12);
                        ctx.quadraticCurveTo(16, 14, 14, 13);
                        ctx.quadraticCurveTo(10, 14, 7, 13);
                        ctx.quadraticCurveTo(4, 12, 2, 10);
                        ctx.fill();
                        // eye
                        ctx.fillStyle = "#0f172a";
                        ctx.beginPath();
                        ctx.arc(6, 6, 1, 0, Math.PI * 2);
                        ctx.fill();
                        // spout
                        ctx.strokeStyle = "#60a5fa";
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(9, 3);
                        ctx.lineTo(9, 0);
                        ctx.stroke();
                    }
                }

                // Status dot
                Rectangle {
                    width: 7; height: 7; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: owOnline ? root.accentGreen : root.accentRed

                    SequentialAnimation on opacity {
                        running: owOnline
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.5; duration: 1200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: "TensorAgent OS"
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

            // Settings gear (canvas drawn)
            Rectangle {
                width: 26
                height: 26
                radius: 6
                color: settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Canvas {
                    anchors.centerIn: parent
                    width: 14; height: 14
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = "#999";
                        ctx.lineWidth = 1.2;
                        ctx.beginPath();
                        var cx = 7, cy = 7;
                        for (var i = 0; i < 8; i++) {
                            var a1 = (i * Math.PI / 4) - 0.18;
                            var a2 = (i * Math.PI / 4) + 0.18;
                            ctx.lineTo(cx + 6 * Math.cos(a1), cy + 6 * Math.sin(a1));
                            ctx.lineTo(cx + 6 * Math.cos(a2), cy + 6 * Math.sin(a2));
                            var a3 = ((i + 0.5) * Math.PI / 4) - 0.12;
                            var a4 = ((i + 0.5) * Math.PI / 4) + 0.12;
                            ctx.lineTo(cx + 4.5 * Math.cos(a3), cy + 4.5 * Math.sin(a3));
                            ctx.lineTo(cx + 4.5 * Math.cos(a4), cy + 4.5 * Math.sin(a4));
                        }
                        ctx.closePath();
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(cx, cy, 2.2, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openApp("settings", "Settings", "settings")
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

                // Whale canvas (matches the topbar icon)
                Canvas {
                    width: 22; height: 22
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#60a5fa";
                        ctx.beginPath();
                        ctx.moveTo(3, 14);
                        ctx.quadraticCurveTo(1, 8, 5, 5);
                        ctx.quadraticCurveTo(9, 2, 15, 4);
                        ctx.quadraticCurveTo(19, 5, 19, 10);
                        ctx.quadraticCurveTo(22, 13, 19, 15);
                        ctx.quadraticCurveTo(20, 18, 22, 16);
                        ctx.quadraticCurveTo(22, 19, 19, 17);
                        ctx.quadraticCurveTo(14, 19, 10, 18);
                        ctx.quadraticCurveTo(5, 17, 3, 14);
                        ctx.fill();
                        ctx.fillStyle = "#0f172a";
                        ctx.beginPath();
                        ctx.arc(8, 8, 1.5, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.strokeStyle = "#60a5fa";
                        ctx.lineWidth = 1.2;
                        ctx.beginPath();
                        ctx.moveTo(12, 4);
                        ctx.lineTo(12, 0);
                        ctx.stroke();
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "TensorAgent OS"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    Text {
                        text: owUptime || "Powered by OpenWhale Engine"
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
                        // Circular arrow icon (canvas)
                        Canvas {
                            width: 12; height: 12
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = owRestarting ? "#f97316" : "#999";
                                ctx.lineWidth = 1.5;
                                ctx.beginPath();
                                ctx.arc(6, 6, 4, -0.5, Math.PI * 1.5);
                                ctx.stroke();
                                // Arrow tip
                                ctx.beginPath();
                                ctx.moveTo(6, 1);
                                ctx.lineTo(9, 2.5);
                                ctx.lineTo(6, 4);
                                ctx.stroke();
                            }
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
                        // Document icon (canvas)
                        Canvas {
                            width: 12; height: 12
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = owLogsFetching ? "#3b82f6" : "#999";
                                ctx.lineWidth = 1.2;
                                ctx.strokeRect(1, 0, 10, 12);
                                ctx.beginPath();
                                ctx.moveTo(3.5, 3); ctx.lineTo(8.5, 3); ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(3.5, 6); ctx.lineTo(8.5, 6); ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(3.5, 9); ctx.lineTo(6.5, 9); ctx.stroke();
                            }
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

                    Canvas {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = "#999";
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            ctx.arc(6, 6, 4, -0.5, Math.PI * 1.5);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(6, 1);
                            ctx.lineTo(9, 2.5);
                            ctx.lineTo(6, 4);
                            ctx.stroke();
                        }
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
                            text: "LOGS — openwhale.service"
                            font.pixelSize: 9
                            color: root.textMuted
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "x"
                            font.pixelSize: 10
                            font.weight: Font.Bold
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

    // ── Click-outside to close panels ──
    MouseArea {
        visible: owPanelVisible
        parent: topBar.parent
        anchors.fill: parent
        anchors.topMargin: topBar.height
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

                    Canvas {
                        width: 13; height: 13
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = "#999"; ctx.lineWidth = 1.2;
                            ctx.beginPath(); ctx.arc(6.5, 4.5, 3, 0, Math.PI * 2); ctx.stroke();
                            ctx.beginPath(); ctx.arc(6.5, 15, 6, Math.PI * 1.2, Math.PI * 1.8); ctx.stroke();
                        }
                    }
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

                    Canvas {
                        width: 13; height: 13
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = "#999"; ctx.lineWidth = 1.2;
                            ctx.beginPath();
                            ctx.moveTo(5, 1); ctx.lineTo(1, 1); ctx.lineTo(1, 12);
                            ctx.lineTo(5, 12); ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(5, 6.5); ctx.lineTo(12, 6.5); ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(9, 3.5); ctx.lineTo(12, 6.5); ctx.lineTo(9, 9.5); ctx.stroke();
                        }
                    }
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
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].appId === appId) return;
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: appId, title: title, icon: icon });
        root.openWindows = wins;
    }
}
