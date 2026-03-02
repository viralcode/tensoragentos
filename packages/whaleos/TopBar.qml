import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: topBar
    height: Math.round(44 * root.sf)
    color: "transparent"

    // ── OpenWhale state ──
    property bool owOnline: false
    property bool owPanelVisible: false
    property string owLogs: ""
    property bool owLogsFetching: false
    property bool owRestarting: false
    property string owUptime: ""

    // ── Time settings state ──
    property bool timePanelVisible: false
    property string currentTimezone: ""
    property bool ntpSynced: false
    property bool ntpActive: false
    property string localTimeStr: ""
    property string utcTimeStr: ""
    property var timezoneList: []
    property string tzSearchFilter: ""
    property bool timeLoading: false

    Component.onCompleted: { checkOwHealth(); fetchTimeInfo(); }

    function fetchTimeInfo() {
        timeLoading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:7778/time/info");
        xhr.timeout = 5000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                timeLoading = false;
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        if (d.ok) {
                            currentTimezone = d.timezone || "Unknown";
                            ntpSynced = d.ntpSync || false;
                            ntpActive = d.ntpActive || false;
                            localTimeStr = d.localTime || "";
                            utcTimeStr = d.utcTime || "";
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.send();
    }

    function fetchTimezones() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:7778/time/timezones");
        xhr.timeout = 10000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    if (d.ok) timezoneList = d.timezones || [];
                } catch(e) {}
            }
        };
        xhr.send();
    }

    function setTimezone(tz) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/time/timezone");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    currentTimezone = tz;
                    fetchTimeInfo();
                }
            }
        };
        xhr.send(JSON.stringify({ timezone: tz }));
    }

    function toggleNtp(enable) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/time/ntp");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    ntpActive = enable;
                    fetchTimeInfo();
                }
            }
        };
        xhr.send(JSON.stringify({ enable: enable }));
    }

    function setManualTime(timeStr) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/time/set");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    clockText.text = Qt.formatTime(new Date(), "h:mm AP");
                    fetchTimeInfo();
                }
            }
        };
        xhr.send(JSON.stringify({ time: timeStr }));
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: checkOwHealth()
    }

    function checkOwHealth() {
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

    // ── Widget Layout ──
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(10 * root.sf)
        anchors.rightMargin: Math.round(10 * root.sf)
        anchors.topMargin: Math.round(6 * root.sf)
        anchors.bottomMargin: Math.round(4 * root.sf)
        spacing: Math.round(8 * root.sf)

        // ═══════════════════════════════════
        // LEFT WIDGET — Brand + Status Pill
        // ═══════════════════════════════════
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: owLeftRow.width + Math.round(24 * root.sf)
            height: Math.round(32 * root.sf)
            radius: Math.round(16 * root.sf)
            color: owAreaMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.08, 0.08, 0.12, 0.65)
            border.color: owAreaMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Row {
                id: owLeftRow
                anchors.centerIn: parent
                spacing: Math.round(7 * root.sf)

                // Whale logo
                Image {
                    width: Math.round(16 * root.sf); height: Math.round(16 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter
                    source: "assets/whale_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                }

                // Status dot
                Rectangle {
                    width: Math.round(7 * root.sf); height: Math.round(7 * root.sf); radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: owOnline ? "#34d399" : "#f87171"

                    SequentialAnimation on opacity {
                        running: owOnline
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: "TensorAgent OS"
                    font.pixelSize: Math.round(11.5 * root.sf)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.3
                    color: "#e2e8f0"
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

        // ═══════════════════════════════════
        // CENTER WIDGET — Clock Pill
        // ═══════════════════════════════════
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: clockRow.width + Math.round(28 * root.sf)
            height: Math.round(32 * root.sf)
            radius: Math.round(16 * root.sf)
            color: clockMa.containsMouse || timePanelVisible ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.08, 0.08, 0.12, 0.65)
            border.color: clockMa.containsMouse || timePanelVisible ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Row {
                id: clockRow; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)

                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "h:mm AP")
                    font.pixelSize: Math.round(12.5 * root.sf)
                    font.weight: Font.DemiBold
                    color: "#f1f5f9"
                    anchors.verticalCenter: parent.verticalCenter

                    Timer {
                        interval: 30000; running: true; repeat: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "h:mm AP")
                    }
                }

                // Subtle separator dot
                Rectangle {
                    visible: currentTimezone !== ""
                    width: Math.round(3 * root.sf); height: Math.round(3 * root.sf)
                    radius: width / 2; color: Qt.rgba(1, 1, 1, 0.25)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Timezone
                Text {
                    visible: currentTimezone !== ""
                    text: {
                        var parts = currentTimezone.split("/");
                        return parts.length > 1 ? parts[parts.length - 1].replace(/_/g, " ") : currentTimezone;
                    }
                    font.pixelSize: Math.round(10 * root.sf)
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.50)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: clockMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    timePanelVisible = !timePanelVisible;
                    owPanelVisible = false;
                    userMenu.visible = false;
                    if (timePanelVisible) {
                        fetchTimeInfo();
                        if (timezoneList.length === 0) fetchTimezones();
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ═══════════════════════════════════
        // RIGHT WIDGET — Controls Pill
        // ═══════════════════════════════════
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: rightRow.width + Math.round(20 * root.sf)
            height: Math.round(32 * root.sf)
            radius: Math.round(16 * root.sf)
            color: Qt.rgba(0.08, 0.08, 0.12, 0.65)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.sf)

                // Settings gear
                Rectangle {
                    width: Math.round(26 * root.sf)
                    height: Math.round(26 * root.sf)
                    radius: Math.round(13 * root.sf)
                    color: settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Canvas {
                        anchors.centerIn: parent
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = settingsMouse.containsMouse ? "#cbd5e1" : "#94a3b8";
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
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                        property bool hov: settingsMouse.containsMouse
                        onHovChanged: requestPaint()
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openApp("settings", "Settings", "settings")
                    }
                }

                // Subtle separator
                Rectangle {
                    width: 1; height: Math.round(16 * root.sf)
                    color: Qt.rgba(1, 1, 1, 0.10)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // User avatar
                Rectangle {
                    width: Math.round(24 * root.sf)
                    height: Math.round(24 * root.sf)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#6366f1" }
                        GradientStop { position: 1.0; color: "#8b5cf6" }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.currentUser.charAt(0).toUpperCase()
                        font.pixelSize: Math.round(11 * root.sf)
                        font.weight: Font.Bold
                        color: "#ffffff"
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
    }

    // ════════════════════════════════════════════
    // ── OpenWhale Status Panel (Dropdown) ──
    // ════════════════════════════════════════════
    Rectangle {
        id: owPanel
        visible: owPanelVisible
        parent: topBar.parent
        x: Math.round(10 * root.sf)
        y: topBar.height + Math.round(6 * root.sf)
        width: Math.round(360 * root.sf)
        height: owPanelCol.height + Math.round(20 * root.sf)
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor
        border.width: 1
        z: 1001

        Column {
            id: owPanelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(10 * root.sf)
            spacing: Math.round(10 * root.sf)

            // ── Header ──
            RowLayout {
                width: parent.width
                spacing: Math.round(8 * root.sf)

                Image {
                    Layout.preferredWidth: Math.round(22 * root.sf)
                    Layout.preferredHeight: Math.round(22 * root.sf)
                    Layout.maximumWidth: Math.round(22 * root.sf)
                    Layout.maximumHeight: Math.round(22 * root.sf)
                    source: "assets/whale_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "TensorAgent OS"
                        font.pixelSize: Math.round(14 * root.sf)
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    Text {
                        text: owUptime || "Powered by OpenWhale Engine"
                        font.pixelSize: Math.round(10 * root.sf)
                        color: root.textMuted
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── Status Row ──
            Rectangle {
                width: parent.width
                height: Math.round(44 * root.sf)
                radius: root.radiusSm
                color: owOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.06) : Qt.rgba(0.94, 0.27, 0.27, 0.06)
                border.color: owOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.15) : Qt.rgba(0.94, 0.27, 0.27, 0.15)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(10 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Rectangle {
                        width: Math.round(9 * root.sf); height: Math.round(9 * root.sf); radius: width / 2
                        color: owRestarting ? root.accentOrange : owOnline ? root.accentGreen : root.accentRed
                    }

                    Text {
                        text: owRestarting ? "Restarting..." : owOnline ? "Online" : "Offline"
                        font.pixelSize: Math.round(13 * root.sf)
                        font.weight: Font.Medium
                        color: owRestarting ? root.accentOrange : owOnline ? root.accentGreen : root.accentRed
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Port 7777"
                        font.pixelSize: Math.round(10 * root.sf)
                        color: root.textMuted
                    }
                }
            }

            // ── Action Buttons ──
            RowLayout {
                width: parent.width
                spacing: Math.round(8 * root.sf)

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(32 * root.sf)
                    radius: root.radiusSm
                    color: restartMa.containsMouse ? Qt.rgba(0.98, 0.45, 0.09, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * root.sf)
                        Canvas {
                            width: Math.round(12 * root.sf); height: Math.round(12 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            property real s: root.sf
                            onPaint: {
                                var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                ctx.save(); ctx.scale(s, s);
                                ctx.strokeStyle = owRestarting ? "#f97316" : "#999"; ctx.lineWidth = 1.5;
                                ctx.beginPath(); ctx.arc(6, 6, 4, -0.5, Math.PI * 1.5); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(6, 1); ctx.lineTo(9, 2.5); ctx.lineTo(6, 4); ctx.stroke();
                                ctx.restore();
                            }
                            onSChanged: requestPaint()
                        }
                        Text {
                            text: owRestarting ? "Restarting..." : "Restart"
                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                            color: owRestarting ? root.accentOrange : root.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { id: restartMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !owRestarting; onClicked: restartOw() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(32 * root.sf)
                    radius: root.radiusSm
                    color: logsMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * root.sf)
                        Canvas {
                            width: Math.round(12 * root.sf); height: Math.round(12 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            property real s: root.sf
                            onPaint: {
                                var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                ctx.save(); ctx.scale(s, s);
                                ctx.strokeStyle = owLogsFetching ? "#3b82f6" : "#999"; ctx.lineWidth = 1.2;
                                ctx.strokeRect(1, 0, 10, 12);
                                ctx.beginPath(); ctx.moveTo(3.5, 3); ctx.lineTo(8.5, 3); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(3.5, 6); ctx.lineTo(8.5, 6); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(3.5, 9); ctx.lineTo(6.5, 9); ctx.stroke();
                                ctx.restore();
                            }
                            onSChanged: requestPaint()
                        }
                        Text {
                            text: owLogsFetching ? "Fetching..." : "View Logs"
                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                            color: owLogsFetching ? root.accentBlue : root.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { id: logsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !owLogsFetching; onClicked: fetchLogs() }
                }

                Rectangle {
                    width: Math.round(32 * root.sf); height: Math.round(32 * root.sf)
                    radius: root.radiusSm
                    color: refreshMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                    Canvas {
                        anchors.centerIn: parent
                        width: Math.round(12 * root.sf); height: Math.round(12 * root.sf)
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = "#999"; ctx.lineWidth = 1.5;
                            ctx.beginPath(); ctx.arc(6, 6, 4, -0.5, Math.PI * 1.5); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(6, 1); ctx.lineTo(9, 2.5); ctx.lineTo(6, 4); ctx.stroke();
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                    }
                    MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: checkOwHealth() }
                }
            }

            // ── Logs Viewer ──
            Rectangle {
                visible: owLogs !== ""
                width: parent.width
                height: Math.round(200 * root.sf)
                radius: root.radiusSm
                color: Qt.rgba(0, 0, 0, 0.4)
                border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
                clip: true

                Rectangle {
                    id: logsHeader
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    height: Math.round(24 * root.sf)
                    color: Qt.rgba(1, 1, 1, 0.03)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf)

                        Text {
                            text: "LOGS — openwhale.service"
                            font.pixelSize: Math.round(9 * root.sf)
                            color: root.textMuted; Layout.fillWidth: true
                        }

                        Text {
                            text: "x"
                            font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Bold
                            color: clearLogsMa.containsMouse ? root.accentRed : root.textMuted
                            MouseArea { id: clearLogsMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: owLogs = "" }
                        }
                    }

                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.04) }
                }

                Flickable {
                    anchors.top: logsHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: Math.round(6 * root.sf)
                    contentHeight: logsText.height; clip: true; boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: logsText
                        width: parent.width
                        text: owLogs
                        font.pixelSize: Math.round(10 * root.sf); font.family: "monospace"
                        color: "#a1a1aa"; wrapMode: Text.WrapAnywhere; lineHeight: 1.4
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════
    // ── Time Settings Panel (Dropdown) ──
    // ════════════════════════════════════════════
    Rectangle {
        id: timePanel
        visible: timePanelVisible
        parent: topBar.parent
        x: (topBar.width - width) / 2 // centered below clock
        y: topBar.height + Math.round(6 * root.sf)
        width: Math.round(340 * root.sf)
        height: timePanelCol.height + Math.round(24 * root.sf)
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor; border.width: 1
        z: 1001

        Column {
            id: timePanelCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Math.round(14 * root.sf)
            spacing: Math.round(12 * root.sf)

            // ── Header: Date & Time ──
            RowLayout {
                width: parent.width; spacing: Math.round(10 * root.sf)

                Canvas {
                    width: Math.round(20 * root.sf); height: Math.round(20 * root.sf)
                    Layout.alignment: Qt.AlignVCenter
                    property real s: root.sf
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 1.5;
                        ctx.beginPath(); ctx.arc(10, 10, 8, 0, Math.PI * 2); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(10, 4); ctx.lineTo(10, 10); ctx.lineTo(14, 12); ctx.stroke();
                        ctx.restore();
                    }
                    onSChanged: requestPaint()
                }

                Column {
                    Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                    Text {
                        text: "Date & Time"
                        font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff"
                    }
                    Text {
                        text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                        font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                    }
                }

                Rectangle {
                    width: Math.round(24 * root.sf); height: Math.round(24 * root.sf)
                    radius: Math.round(6 * root.sf)
                    color: closeTimeMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"

                    Text {
                        anchors.centerIn: parent; text: "✕"
                        font.pixelSize: Math.round(12 * root.sf); color: root.textMuted
                    }
                    MouseArea {
                        id: closeTimeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: timePanelVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── Current Time Display ──
            Rectangle {
                width: parent.width; height: Math.round(54 * root.sf); radius: Math.round(8 * root.sf)
                color: Qt.rgba(0.06, 0.06, 0.12, 0.8)
                border.color: Qt.rgba(0.35, 0.55, 1.0, 0.15); border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: Math.round(12 * root.sf)

                    Text {
                        text: Qt.formatTime(new Date(), "h:mm:ss AP")
                        font.pixelSize: Math.round(22 * root.sf); font.weight: Font.Bold
                        font.family: "monospace"; color: "#e2e8f0"
                        anchors.verticalCenter: parent.verticalCenter

                        Timer {
                            interval: 1000; running: timePanelVisible; repeat: true
                            onTriggered: parent.text = Qt.formatTime(new Date(), "h:mm:ss AP")
                        }
                    }

                    // NTP badge
                    Rectangle {
                        visible: ntpActive
                        width: ntpBadgeText.width + Math.round(12 * root.sf)
                        height: Math.round(20 * root.sf); radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: ntpSynced ? Qt.rgba(0.13, 0.77, 0.37, 0.15) : Qt.rgba(0.96, 0.62, 0.04, 0.15)

                        Text {
                            id: ntpBadgeText; anchors.centerIn: parent
                            text: ntpSynced ? "NTP ✓" : "NTP ⋯"
                            font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold
                            color: ntpSynced ? "#22c55e" : "#f59e0b"
                        }
                    }
                }
            }

            // ── Timezone Section ──
            Column {
                width: parent.width; spacing: Math.round(8 * root.sf)

                RowLayout {
                    width: parent.width; spacing: Math.round(8 * root.sf)

                    Text {
                        text: "Timezone"
                        font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: currentTimezone || "Loading..."
                        font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                        color: "#60a5fa"
                    }
                }

                // Timezone search
                Rectangle {
                    width: parent.width; height: Math.round(34 * root.sf); radius: Math.round(8 * root.sf)
                    color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    TextInput {
                        id: tzSearch; anchors.fill: parent
                        anchors.leftMargin: Math.round(10 * root.sf); anchors.rightMargin: Math.round(10 * root.sf)
                        color: "#fff"; font.pixelSize: Math.round(12 * root.sf)
                        clip: true; verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: tzSearchFilter = text.toLowerCase()

                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            text: "🔍 Search timezones..."
                            color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(11 * root.sf)
                            visible: !parent.text
                        }
                    }
                }

                // Timezone list (scrollable, filtered)
                Rectangle {
                    visible: tzSearchFilter.length >= 2
                    width: parent.width; height: Math.min(Math.round(180 * root.sf), tzListView.contentHeight + 4)
                    radius: Math.round(8 * root.sf)
                    color: Qt.rgba(0, 0, 0, 0.25); border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                    clip: true

                    ListView {
                        id: tzListView; anchors.fill: parent; anchors.margins: 2
                        clip: true; spacing: 1
                        model: {
                            if (tzSearchFilter.length < 2) return [];
                            var filtered = [];
                            for (var i = 0; i < timezoneList.length && filtered.length < 50; i++) {
                                if (timezoneList[i].toLowerCase().indexOf(tzSearchFilter) >= 0) {
                                    filtered.push(timezoneList[i]);
                                }
                            }
                            return filtered;
                        }

                        delegate: Rectangle {
                            width: tzListView.width; height: Math.round(30 * root.sf); radius: Math.round(4 * root.sf)
                            color: tzItemMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.15) :
                                   modelData === currentTimezone ? Qt.rgba(0.35, 0.55, 1.0, 0.08) : "transparent"

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: Math.round(10 * root.sf)
                                text: (modelData === currentTimezone ? "✓ " : "") + modelData
                                font.pixelSize: Math.round(11 * root.sf)
                                color: modelData === currentTimezone ? "#60a5fa" : root.textPrimary
                                font.weight: modelData === currentTimezone ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: tzItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { setTimezone(modelData); tzSearch.text = ""; tzSearchFilter = ""; }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── NTP Sync Toggle ──
            Rectangle {
                width: parent.width; height: Math.round(44 * root.sf); radius: Math.round(8 * root.sf)
                color: Qt.rgba(0,0,0,0.15); border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: Math.round(10 * root.sf); spacing: Math.round(10 * root.sf)

                    Column {
                        Layout.fillWidth: true; spacing: Math.round(2 * root.sf)

                        Text {
                            text: "Automatic Time Sync (NTP)"
                            font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium; color: root.textPrimary
                        }
                        Text {
                            text: ntpActive ? (ntpSynced ? "Synchronized with time server" : "Waiting for sync...") : "Manual time mode"
                            font.pixelSize: Math.round(10 * root.sf); color: root.textMuted
                        }
                    }

                    // Toggle button
                    Rectangle {
                        width: Math.round(46 * root.sf); height: Math.round(24 * root.sf)
                        radius: Math.round(12 * root.sf)
                        color: ntpActive ? Qt.rgba(0.13, 0.77, 0.37, 0.3) : Qt.rgba(1,1,1,0.1)
                        border.color: ntpActive ? Qt.rgba(0.13, 0.77, 0.37, 0.5) : Qt.rgba(1,1,1,0.15)
                        border.width: 1

                        Rectangle {
                            width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                            radius: Math.round(9 * root.sf)
                            x: ntpActive ? parent.width - width - Math.round(3 * root.sf) : Math.round(3 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            color: ntpActive ? "#22c55e" : "#888"
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: toggleNtp(!ntpActive)
                        }
                    }
                }
            }

            // ── Manual Time (visible when NTP is off) ──
            Rectangle {
                visible: !ntpActive
                width: parent.width; height: manualTimeCol.height + Math.round(16 * root.sf)
                radius: Math.round(8 * root.sf)
                color: Qt.rgba(0,0,0,0.15); border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                Column {
                    id: manualTimeCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Math.round(10 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Text {
                        text: "Set Time Manually"
                        font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary
                    }

                    Row {
                        spacing: Math.round(8 * root.sf)

                        Rectangle {
                            width: Math.round(190 * root.sf); height: Math.round(32 * root.sf); radius: Math.round(6 * root.sf)
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                            TextInput {
                                id: manualTimeInput; anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf)
                                color: "#fff"; font.pixelSize: Math.round(12 * root.sf); font.family: "monospace"
                                clip: true; verticalAlignment: TextInput.AlignVCenter
                                Keys.onReturnPressed: setManualTime(text.trim())

                                Text {
                                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                    text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                                    color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(11 * root.sf); font.family: "monospace"
                                    visible: !parent.text
                                }
                            }
                        }

                        Rectangle {
                            width: Math.round(60 * root.sf); height: Math.round(32 * root.sf); radius: Math.round(6 * root.sf)
                            color: setTimeMa.containsMouse ? "#2563eb" : "#3b82f6"

                            Text {
                                anchors.centerIn: parent; text: "Set"
                                font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff"
                            }
                            MouseArea {
                                id: setTimeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (manualTimeInput.text.trim()) setManualTime(manualTimeInput.text.trim()); }
                            }
                        }
                    }

                    Text {
                        text: "Format: YYYY-MM-DD HH:MM:SS"
                        font.pixelSize: Math.round(9 * root.sf); color: root.textMuted
                    }
                }
            }

            // ── UTC time ──
            Row {
                visible: utcTimeStr !== ""; spacing: Math.round(6 * root.sf)
                Text { text: "UTC:"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textMuted }
                Text { text: utcTimeStr; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; font.family: "monospace" }
            }
        }
    }

    // ── Click-outside to close panels ──
    MouseArea {
        visible: owPanelVisible || timePanelVisible
        parent: topBar.parent
        anchors.fill: parent
        anchors.topMargin: topBar.height
        z: 999
        onClicked: { owPanelVisible = false; timePanelVisible = false; }
    }

    // ── User Dropdown Menu ──
    Rectangle {
        id: userMenu
        visible: false
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.rightMargin: Math.round(14 * root.sf)
        anchors.topMargin: Math.round(6 * root.sf)
        width: Math.round(160 * root.sf)
        height: menuCol.height + Math.round(12 * root.sf)
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor; border.width: 1
        z: 1000

        Column {
            id: menuCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Math.round(6 * root.sf)
            spacing: 2

            Rectangle {
                width: parent.width; height: Math.round(36 * root.sf)
                radius: root.radiusSm; color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Canvas {
                        width: Math.round(13 * root.sf); height: Math.round(13 * root.sf)
                        anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = "#999"; ctx.lineWidth = 1.2;
                            ctx.beginPath(); ctx.arc(6.5, 4.5, 3, 0, Math.PI * 2); ctx.stroke();
                            ctx.beginPath(); ctx.arc(6.5, 15, 6, Math.PI * 1.2, Math.PI * 1.8); ctx.stroke();
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                    }
                    Text {
                        text: root.currentUser
                        font.pixelSize: Math.round(12 * root.sf)
                        color: root.textPrimary; font.weight: Font.Medium
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            Rectangle {
                width: parent.width; height: Math.round(34 * root.sf)
                radius: root.radiusSm
                color: logoutMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Canvas {
                        width: Math.round(13 * root.sf); height: Math.round(13 * root.sf)
                        anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = "#999"; ctx.lineWidth = 1.2;
                            ctx.beginPath();
                            ctx.moveTo(5, 1); ctx.lineTo(1, 1); ctx.lineTo(1, 12);
                            ctx.lineTo(5, 12); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(5, 6.5); ctx.lineTo(12, 6.5); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(9, 3.5); ctx.lineTo(12, 6.5); ctx.lineTo(9, 9.5); ctx.stroke();
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                    }
                    Text {
                        text: "Sign Out"
                        font.pixelSize: Math.round(12 * root.sf)
                        color: root.textSecondary
                    }
                }

                MouseArea { id: logoutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { userMenu.visible = false; root.doLogout(); } }
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
