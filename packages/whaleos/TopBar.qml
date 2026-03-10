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
    property bool timeOpPending: false

    // ── Network/WiFi state ──
    property bool netPanelVisible: false
    property bool wifiEnabled: true
    property bool wifiScanning: false
    property bool wifiConnecting: false
    property string wifiConnectingSSID: ""
    property string currentSSID: ""
    property int currentSignal: 0
    property string currentIP: ""
    property string connectionType: "none"  // "wifi", "ethernet", "none"
    property var wifiNetworks: []  // [{ssid, signal, security, connected}]
    property string wifiError: ""
    property bool showPasswordDialog: false
    property string passwordSSID: ""
    property string passwordInput: ""

    Component.onCompleted: { checkOwHealth(); sysManager.getTimeInfoAsync(); refreshNetworkStatus(); }

    // ── Network Functions (via whaleos-helper /exec POST) ──
    function helperExec(cmd, callback, timeout) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/exec");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = timeout || 10000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (callback) callback(xhr.status, xhr.responseText);
            }
        };
        xhr.ontimeout = function() {
            if (callback) callback(0, "");
        };
        xhr.send(JSON.stringify({command: cmd}));
    }

    function refreshNetworkStatus() {
        helperExec(
            "nmcli -t -f TYPE,NAME,DEVICE connection show --active 2>/dev/null; echo '---IP---'; " +
            "ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' 2>/dev/null; echo '---WIFI---'; " +
            "nmcli -t -f WIFI general 2>/dev/null",
            function(status, body) {
                if (status === 200) {
                    try {
                        var d = JSON.parse(body);
                        var out = d.stdout || "";
                        var parts = out.split("---IP---");
                        var connPart = parts[0] || "";
                        var rest = (parts[1] || "").split("---WIFI---");
                        var ipPart = (rest[0] || "").trim();
                        var wifiPart = (rest[1] || "").trim();

                        currentIP = ipPart.split("/")[0] || "";
                        wifiEnabled = (wifiPart.toLowerCase() === "enabled");

                        // Parse active connection
                        var lines = connPart.trim().split("\n");
                        connectionType = "none";
                        currentSSID = "";
                        for (var i = 0; i < lines.length; i++) {
                            var cols = lines[i].split(":");
                            if (cols.length >= 2) {
                                if (cols[0] === "802-11-wireless" || cols[0] === "wifi") {
                                    connectionType = "wifi";
                                    currentSSID = cols[1];
                                } else if (cols[0] === "802-3-ethernet" || cols[0] === "ethernet") {
                                    connectionType = "ethernet";
                                }
                            }
                        }
                    } catch(e) {}
                }
            }, 5000
        );
    }

    function scanWifi() {
        wifiScanning = true;
        wifiError = "";
        helperExec(
            "nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE device wifi list --rescan yes 2>/dev/null",
            function(status, body) {
                wifiScanning = false;
                if (status === 200) {
                    try {
                        var d = JSON.parse(body);
                        var out = d.stdout || "";
                        var lines = out.trim().split("\n");
                        var nets = [];
                        var seen = {};
                        for (var i = 0; i < lines.length; i++) {
                            var cols = lines[i].split(":");
                            if (cols.length >= 3 && cols[0].trim() !== "" && cols[0] !== "--") {
                                var ssid = cols[0].trim();
                                if (seen[ssid]) continue;
                                seen[ssid] = true;
                                nets.push({
                                    ssid: ssid,
                                    signal: parseInt(cols[1]) || 0,
                                    security: cols[2] || "Open",
                                    connected: (cols.length >= 4 && cols[3].trim() === "yes")
                                });
                            }
                        }
                        nets.sort(function(a, b) {
                            if (a.connected !== b.connected) return a.connected ? -1 : 1;
                            return b.signal - a.signal;
                        });
                        wifiNetworks = nets;
                        if (nets.length === 0 && out.trim() === "") {
                            wifiError = "No WiFi adapter found (VM has ethernet only)";
                        }
                    } catch(e) {
                        wifiError = "Failed to parse WiFi scan results";
                    }
                } else {
                    wifiError = "WiFi scan failed. Is NetworkManager running?";
                }
            }, 15000
        );
    }

    function connectWifi(ssid, password) {
        wifiConnecting = true;
        wifiConnectingSSID = ssid;
        wifiError = "";
        var cmd = password
            ? "nmcli device wifi connect '" + ssid.replace(/'/g, "'\\''") + "' password '" + password.replace(/'/g, "'\\''") + "' 2>&1"
            : "nmcli device wifi connect '" + ssid.replace(/'/g, "'\\''") + "' 2>&1";
        helperExec(cmd, function(status, body) {
            wifiConnecting = false;
            wifiConnectingSSID = "";
            if (status === 200) {
                try {
                    var d = JSON.parse(body);
                    var out = (d.stdout || "").toLowerCase();
                    if (out.indexOf("error") !== -1 || out.indexOf("failed") !== -1) {
                        wifiError = d.stdout || "Connection failed";
                    } else {
                        showPasswordDialog = false;
                        passwordInput = "";
                        refreshNetworkStatus();
                        scanWifi();
                    }
                } catch(e) {
                    wifiError = "Connection error";
                }
            }
        }, 30000);
    }

    function disconnectWifi() {
        helperExec(
            "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1) 2>/dev/null",
            function() { refreshNetworkStatus(); scanWifi(); }
        );
    }

    function toggleWifi(enable) {
        helperExec(
            "nmcli radio wifi " + (enable ? "on" : "off") + " 2>/dev/null",
            function() {
                wifiEnabled = enable;
                if (enable) { scanWifi(); }
                refreshNetworkStatus();
            }
        );
    }

    // Refresh network status periodically
    Timer {
        interval: 15000; running: true; repeat: true
        onTriggered: refreshNetworkStatus()
    }

    function fetchTimeInfo() {
        timeLoading = true;
        sysManager.getTimeInfoAsync();
    }

    function fetchTimezones() {
        sysManager.getTimezonesAsync();
    }

    function setTimezone(tz) {
        sysManager.setTimezoneAsync(tz);
    }

    function toggleNtp(enable) {
        timeOpPending = true;
        sysManager.toggleNtpAsync(enable);
    }

    function setManualTime(timeStr) {
        sysManager.setManualTimeAsync(timeStr);
    }

    // ── Signal handlers for C++ time management ──
    Connections {
        target: sysManager

        function onTimeInfoReady(timezone, ntpSync, ntpActive, localTime, utcTime) {
            timeLoading = false;
            currentTimezone = timezone || "Unknown";
            localTimeStr = localTime || "";
            utcTimeStr = utcTime || "";
            // Don't override toggle state while an operation is pending
            if (!topBar.timeOpPending) {
                topBar.ntpSynced = ntpSync || false;
                topBar.ntpActive = ntpActive || false;
            }
        }

        function onTimezonesReady(timezones) {
            timezoneList = timezones || [];
        }

        function onTimeOpResult(operation, success, detail) {
            topBar.timeOpPending = false;
            if (operation === "toggleNtp" && success) {
                topBar.ntpActive = (detail === "enabled");
                if (!topBar.ntpActive) topBar.ntpSynced = false;
            } else if (operation === "setTimezone" && success) {
                currentTimezone = detail;
            } else if (operation === "setTime" && success) {
                clockText.text = Qt.formatTime(new Date(), "h:mm AP");
            }
            // Delayed refresh to confirm state after system settles
            delayedRefreshTimer.restart();
        }
    }

    Timer {
        id: delayedRefreshTimer
        interval: 2000; repeat: false
        onTriggered: sysManager.getTimeInfoAsync()
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: checkOwHealth()
    }

    // Refresh time info periodically when time panel is open
    Timer {
        interval: 15000; running: timePanelVisible; repeat: true
        onTriggered: sysManager.getTimeInfoAsync()
    }
    onTimePanelVisibleChanged: {
        if (timePanelVisible) {
            sysManager.getTimeInfoAsync();
            if (timezoneList.length === 0) sysManager.getTimezonesAsync();
        }
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
            id: brandPill
            Layout.alignment: Qt.AlignVCenter
            width: owLeftRow.width + Math.round(28 * root.sf)
            height: Math.round(32 * root.sf)
            radius: Math.round(16 * root.sf)
            color: Qt.rgba(0.08, 0.08, 0.12, 0.70)
            border.width: 1
            clip: true

            // PERF: Static border — glowPhase Math.sin binding forced border repaint every frame of an 8s loop
            border.color: owAreaMouse.containsMouse
                ? Qt.rgba(0.4, 0.6, 1.0, 0.35)
                : Qt.rgba(1, 1, 1, 0.10)

            scale: owAreaMouse.containsMouse ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 250 } }

            // ── Shimmer sweep on hover ──
            Rectangle {
                id: brandShimmer
                width: Math.round(40 * root.sf); height: parent.height
                radius: parent.radius
                rotation: -20
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.08) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                    GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                property real sweepX: -width
                x: sweepX; y: 0

                SequentialAnimation {
                    running: owAreaMouse.containsMouse
                    loops: Animation.Infinite
                    PropertyAction { target: brandShimmer; property: "opacity"; value: 1 }
                    NumberAnimation { target: brandShimmer; property: "sweepX"; from: -brandShimmer.width; to: brandPill.width + brandShimmer.width; duration: 1200; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 600 }
                }
                // Hide shimmer when not hovering
                Binding { target: brandShimmer; property: "opacity"; value: 0; when: !owAreaMouse.containsMouse }
            }

            Row {
                id: owLeftRow
                anchors.centerIn: parent
                spacing: Math.round(7 * root.sf)

                // Whale logo with subtle rotation on hover
                Image {
                    id: whaleLogo
                    width: Math.round(16 * root.sf); height: Math.round(16 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter
                    source: "assets/whale_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                    rotation: owAreaMouse.containsMouse ? 8 : 0
                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                }

                // ── Status indicator — static dot (PERF: removed ripple animations
                // that ran infinite scale+opacity loops and dirtied scene every frame)
                Item {
                    width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter

                    // Outer ring (static)
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(13 * root.sf); height: width; radius: width / 2
                        color: "transparent"
                        border.color: owOnline ? Qt.rgba(0.2, 0.83, 0.6, 0.20) : Qt.rgba(0.97, 0.44, 0.44, 0.20)
                        border.width: 1
                    }

                    // Core dot
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(7 * root.sf); height: width; radius: width / 2
                        color: owOnline ? "#34d399" : "#f87171"
                    }
                }

                Text {
                    text: "TensorAgent OS"
                    font.pixelSize: Math.round(11.5 * root.sf)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.3
                    color: owAreaMouse.containsMouse ? "#f8fafc" : "#e2e8f0"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            MouseArea {
                id: owAreaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    owPanelVisible = !owPanelVisible;
                    userMenu.visible = false; netPanelVisible = false; timePanelVisible = false;
                    if (owPanelVisible) { checkOwHealth(); }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ═══════════════════════════════════
        // CENTER WIDGET — Clock Pill
        // ═══════════════════════════════════
        Rectangle {
            id: clockPill
            Layout.alignment: Qt.AlignVCenter
            width: clockRow.width + Math.round(30 * root.sf)
            height: Math.round(32 * root.sf)
            radius: Math.round(16 * root.sf)
            color: Qt.rgba(0.08, 0.08, 0.12, 0.70)
            border.width: 1
            clip: true

            // PERF: Static border — clockGlow Math.sin binding forced repaint every frame
            border.color: Qt.rgba(1, 1, 1, 0.10)

            scale: clockMa.containsMouse ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 250 } }

            // ── Shimmer sweep ──
            Rectangle {
                id: clockShimmer
                width: Math.round(35 * root.sf); height: parent.height
                radius: parent.radius; rotation: -20; opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.06) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.12) }
                    GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                property real sweepX: -width
                x: sweepX; y: 0

                SequentialAnimation {
                    running: clockMa.containsMouse
                    loops: Animation.Infinite
                    PropertyAction { target: clockShimmer; property: "opacity"; value: 1 }
                    NumberAnimation { target: clockShimmer; property: "sweepX"; from: -clockShimmer.width; to: clockPill.width + clockShimmer.width; duration: 1000; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 800 }
                }
                Binding { target: clockShimmer; property: "opacity"; value: 0; when: !clockMa.containsMouse }
            }

            Row {
                id: clockRow; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)

                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "h:mm AP")
                    font.pixelSize: Math.round(12.5 * root.sf)
                    font.weight: Font.DemiBold
                    color: clockMa.containsMouse ? "#ffffff" : "#f1f5f9"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Timer {
                        interval: 30000; running: true; repeat: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "h:mm AP")
                    }
                }

                // Animated separator — pulses
                Rectangle {
                    visible: currentTimezone !== ""
                    width: Math.round(3 * root.sf); height: Math.round(3 * root.sf)
                    radius: width / 2; anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.25)

                    // PERF: Removed always-running opacity pulse on separator dot
                    opacity: 0.4
                }

                Text {
                    visible: currentTimezone !== ""
                    text: {
                        var parts = currentTimezone.split("/");
                        return parts.length > 1 ? parts[parts.length - 1].replace(/_/g, " ") : currentTimezone;
                    }
                    font.pixelSize: Math.round(10 * root.sf)
                    font.weight: Font.Medium
                    color: clockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            MouseArea {
                id: clockMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    timePanelVisible = !timePanelVisible;
                    owPanelVisible = false; netPanelVisible = false;
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
            id: controlsPill
            Layout.alignment: Qt.AlignVCenter
            width: rightRow.width + Math.round(22 * root.sf)
            height: Math.round(32 * root.sf)
            radius: Math.round(16 * root.sf)
            color: Qt.rgba(0.08, 0.08, 0.12, 0.70)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.sf)

                // Settings gear with rotation
                Rectangle {
                    width: Math.round(26 * root.sf)
                    height: Math.round(26 * root.sf)
                    radius: Math.round(13 * root.sf)
                    color: settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: 200 } }
                    scale: settingsMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    Canvas {
                        id: gearCanvas
                        anchors.centerIn: parent
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                        property real s: root.sf

                        // Slow rotation on hover
                        rotation: 0
                        RotationAnimation on rotation {
                            running: settingsMouse.containsMouse
                            from: gearCanvas.rotation; to: gearCanvas.rotation + 360
                            duration: 3000; loops: Animation.Infinite
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = settingsMouse.containsMouse ? "#e2e8f0" : "#94a3b8";
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

                // WiFi/Network indicator
                Rectangle {
                    width: Math.round(26 * root.sf)
                    height: Math.round(26 * root.sf)
                    radius: Math.round(13 * root.sf)
                    color: wifiMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                    scale: wifiMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    Canvas {
                        id: wifiCanvas
                        anchors.centerIn: parent
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                        property real s: root.sf
                        property string connType: connectionType
                        property bool enabled: wifiEnabled

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);

                            if (connType === "ethernet") {
                                // Ethernet icon — monitor with cable
                                ctx.strokeStyle = "#34d399"; ctx.lineWidth = 1.3;
                                ctx.strokeRect(2, 1, 10, 7);
                                ctx.beginPath(); ctx.moveTo(7, 8); ctx.lineTo(7, 11); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(4, 11); ctx.lineTo(10, 11); ctx.stroke();
                            } else if (connType === "wifi" && enabled) {
                                // WiFi connected — signal arcs
                                var cx = 7, cy = 12;
                                ctx.strokeStyle = "#34d399"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
                                // Three arcs
                                ctx.beginPath(); ctx.arc(cx, cy, 9, -Math.PI * 0.85, -Math.PI * 0.15); ctx.stroke();
                                ctx.beginPath(); ctx.arc(cx, cy, 6, -Math.PI * 0.80, -Math.PI * 0.20); ctx.stroke();
                                ctx.beginPath(); ctx.arc(cx, cy, 3, -Math.PI * 0.75, -Math.PI * 0.25); ctx.stroke();
                                // Center dot
                                ctx.fillStyle = "#34d399";
                                ctx.beginPath(); ctx.arc(cx, cy, 1.2, 0, Math.PI * 2); ctx.fill();
                            } else if (!enabled) {
                                // WiFi disabled — crossed out
                                var cx2 = 7, cy2 = 12;
                                ctx.strokeStyle = "#6b7280"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
                                ctx.beginPath(); ctx.arc(cx2, cy2, 9, -Math.PI * 0.85, -Math.PI * 0.15); ctx.stroke();
                                ctx.beginPath(); ctx.arc(cx2, cy2, 6, -Math.PI * 0.80, -Math.PI * 0.20); ctx.stroke();
                                // Slash through
                                ctx.strokeStyle = "#ef4444"; ctx.lineWidth = 1.5;
                                ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(12, 12); ctx.stroke();
                            } else {
                                // No connection — gray wifi
                                var cx3 = 7, cy3 = 12;
                                ctx.strokeStyle = "#6b7280"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
                                ctx.beginPath(); ctx.arc(cx3, cy3, 9, -Math.PI * 0.85, -Math.PI * 0.15); ctx.stroke();
                                ctx.beginPath(); ctx.arc(cx3, cy3, 6, -Math.PI * 0.80, -Math.PI * 0.20); ctx.stroke();
                                ctx.beginPath(); ctx.arc(cx3, cy3, 3, -Math.PI * 0.75, -Math.PI * 0.25); ctx.stroke();
                                ctx.fillStyle = "#6b7280";
                                ctx.beginPath(); ctx.arc(cx3, cy3, 1.2, 0, Math.PI * 2); ctx.fill();
                            }
                            ctx.restore();
                        }
                        onConnTypeChanged: requestPaint()
                        onEnabledChanged: requestPaint()
                        onSChanged: requestPaint()
                        property bool hov: wifiMouse.containsMouse
                        onHovChanged: requestPaint()
                    }

                    MouseArea {
                        id: wifiMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            netPanelVisible = !netPanelVisible;
                            owPanelVisible = false; timePanelVisible = false; userMenu.visible = false;
                            if (netPanelVisible) { refreshNetworkStatus(); scanWifi(); }
                        }
                    }
                }

                // Animated separator
                Rectangle {
                    width: 1; height: Math.round(16 * root.sf)
                    color: Qt.rgba(1, 1, 1, 0.10)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // User avatar with animated ring
                Item {
                    width: Math.round(28 * root.sf)
                    height: Math.round(28 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter

                    // Animated gradient ring
                    Canvas {
                        id: avatarRing
                        anchors.centerIn: parent
                        width: parent.width; height: parent.height
                        // PERF: Replaced 4s loop calling requestPaint() on every frame
                        // with a slow Timer — avatar ring rotates subtly every 3s
                        property real ringPhase: 0
                        Timer {
                            interval: 3000; running: true; repeat: true
                            onTriggered: { avatarRing.ringPhase += 0.8; avatarRing.requestPaint(); }
                        }
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2, cy = height / 2, r = width / 2 - 1;
                            ctx.lineWidth = 1.5;

                            // Create rotating gradient border
                            var grad = ctx.createConicalGradient(cx, cy, ringPhase);
                            grad.addColorStop(0.0, "#6366f1");
                            grad.addColorStop(0.25, "#8b5cf6");
                            grad.addColorStop(0.5, "#a78bfa");
                            grad.addColorStop(0.75, "#818cf8");
                            grad.addColorStop(1.0, "#6366f1");
                            ctx.strokeStyle = grad;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.stroke();
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(22 * root.sf)
                        height: width; radius: width / 2

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#6366f1" }
                            GradientStop { position: 1.0; color: "#8b5cf6" }
                        }

                        scale: avatarMa.containsMouse ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: root.currentUser.charAt(0).toUpperCase()
                            font.pixelSize: Math.round(10 * root.sf)
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: avatarMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { userMenu.visible = !userMenu.visible; owPanelVisible = false; netPanelVisible = false; timePanelVisible = false; }
                        }
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

            // ── System Power Options ──
            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            RowLayout {
                width: parent.width
                spacing: Math.round(8 * root.sf)

                // Restart System button
                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(34 * root.sf)
                    radius: root.radiusSm
                    color: restartSysMa.containsMouse ? Qt.rgba(0.98, 0.62, 0.04, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * root.sf)
                        Canvas {
                            width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            property real s: root.sf
                            onPaint: {
                                var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                ctx.save(); ctx.scale(s, s);
                                ctx.strokeStyle = "#f59e0b"; ctx.lineWidth = 1.5;
                                ctx.beginPath(); ctx.arc(7, 7, 5, -0.5, Math.PI * 1.5); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(7, 1); ctx.lineTo(10, 3); ctx.lineTo(7, 5); ctx.fill();
                                ctx.restore();
                            }
                            onSChanged: requestPaint()
                        }
                        Text {
                            text: "Restart"
                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                            color: restartSysMa.containsMouse ? "#f59e0b" : root.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: restartSysMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: sysManager.runCommandAsync("sudo reboot", "")
                    }
                }

                // Shut Down button
                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(34 * root.sf)
                    radius: root.radiusSm
                    color: shutdownMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * root.sf)
                        Canvas {
                            width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            property real s: root.sf
                            onPaint: {
                                var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                ctx.save(); ctx.scale(s, s);
                                ctx.strokeStyle = "#ef4444"; ctx.lineWidth = 1.8;
                                ctx.beginPath(); ctx.moveTo(7, 1); ctx.lineTo(7, 6); ctx.stroke();
                                ctx.beginPath(); ctx.arc(7, 7, 5, -1.2, Math.PI + 1.2); ctx.stroke();
                                ctx.restore();
                            }
                            onSChanged: requestPaint()
                        }
                        Text {
                            text: "Shut Down"
                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                            color: shutdownMa.containsMouse ? "#ef4444" : root.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: shutdownMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: sysManager.runCommandAsync("sudo shutdown -h now", "")
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════
    // ── Network / WiFi Panel (Dropdown) ──
    // ════════════════════════════════════════════
    Rectangle {
        id: netPanel
        visible: netPanelVisible
        parent: topBar.parent
        x: topBar.width - width - Math.round(10 * root.sf)
        y: topBar.height + Math.round(6 * root.sf)
        width: Math.round(340 * root.sf)
        height: netPanelCol.height + Math.round(20 * root.sf)
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor; border.width: 1
        z: 1001

        Column {
            id: netPanelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(10 * root.sf)
            spacing: Math.round(10 * root.sf)

            // ── Header ──
            RowLayout {
                width: parent.width
                spacing: Math.round(8 * root.sf)

                Canvas {
                    Layout.preferredWidth: Math.round(20 * root.sf)
                    Layout.preferredHeight: Math.round(20 * root.sf)
                    property real s: root.sf
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s * 1.4, s * 1.4);
                        var cx = 7, cy = 12;
                        ctx.strokeStyle = connectionType !== "none" ? "#34d399" : "#94a3b8";
                        ctx.lineWidth = 1.4; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.arc(cx, cy, 9, -Math.PI * 0.85, -Math.PI * 0.15); ctx.stroke();
                        ctx.beginPath(); ctx.arc(cx, cy, 6, -Math.PI * 0.80, -Math.PI * 0.20); ctx.stroke();
                        ctx.beginPath(); ctx.arc(cx, cy, 3, -Math.PI * 0.75, -Math.PI * 0.25); ctx.stroke();
                        ctx.fillStyle = ctx.strokeStyle;
                        ctx.beginPath(); ctx.arc(cx, cy, 1.2, 0, Math.PI * 2); ctx.fill();
                        ctx.restore();
                    }
                    onSChanged: requestPaint()
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Network"
                        font.pixelSize: Math.round(14 * root.sf)
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    Text {
                        text: connectionType === "wifi" ? "Connected to " + currentSSID
                            : connectionType === "ethernet" ? "Wired Connection"
                            : "Not Connected"
                        font.pixelSize: Math.round(10 * root.sf)
                        color: root.textMuted
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                // Close button
                Rectangle {
                    Layout.preferredWidth: Math.round(24 * root.sf)
                    Layout.preferredHeight: Math.round(24 * root.sf)
                    radius: Math.round(12 * root.sf)
                    color: netCloseMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent; text: "✕"
                        font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                    }
                    MouseArea { id: netCloseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: netPanelVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── Connection Status ──
            Rectangle {
                width: parent.width
                height: Math.round(44 * root.sf)
                radius: root.radiusSm
                color: connectionType !== "none"
                    ? Qt.rgba(0.13, 0.77, 0.37, 0.06)
                    : Qt.rgba(0.42, 0.46, 0.50, 0.06)
                border.color: connectionType !== "none"
                    ? Qt.rgba(0.13, 0.77, 0.37, 0.15)
                    : Qt.rgba(0.42, 0.46, 0.50, 0.15)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(10 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Rectangle {
                        width: Math.round(9 * root.sf); height: width; radius: width/2
                        color: connectionType !== "none" ? root.accentGreen : "#6b7280"
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: connectionType === "wifi" ? currentSSID
                                : connectionType === "ethernet" ? "Ethernet"
                                : "Disconnected"
                            font.pixelSize: Math.round(12 * root.sf)
                            font.weight: Font.Medium
                            color: connectionType !== "none" ? root.accentGreen : "#9ca3af"
                        }
                        Text {
                            visible: currentIP !== ""
                            text: currentIP
                            font.pixelSize: Math.round(9 * root.sf)
                            color: root.textMuted
                        }
                    }

                    // Disconnect button (for WiFi)
                    Rectangle {
                        visible: connectionType === "wifi"
                        width: Math.round(70 * root.sf); height: Math.round(24 * root.sf)
                        radius: Math.round(12 * root.sf)
                        color: disconnMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.15) : Qt.rgba(1,1,1,0.05)
                        border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                        Text {
                            anchors.centerIn: parent; text: "Disconnect"
                            font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Medium
                            color: disconnMa.containsMouse ? "#ef4444" : root.textMuted
                        }
                        MouseArea { id: disconnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: disconnectWifi() }
                    }
                }
            }

            // ── WiFi Toggle ──
            Rectangle {
                width: parent.width
                height: Math.round(40 * root.sf)
                radius: root.radiusSm
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(10 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Text {
                        text: "Wi-Fi"
                        font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium
                        color: "#e2e8f0"; Layout.fillWidth: true
                    }

                    // Toggle switch
                    Rectangle {
                        width: Math.round(40 * root.sf); height: Math.round(22 * root.sf)
                        radius: Math.round(11 * root.sf)
                        color: wifiEnabled ? "#34d399" : "#374151"
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                            radius: Math.round(9 * root.sf)
                            color: "#ffffff"
                            x: wifiEnabled ? parent.width - width - Math.round(2 * root.sf) : Math.round(2 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: toggleWifi(!wifiEnabled)
                        }
                    }
                }
            }

            // ── WiFi Networks Header ──
            RowLayout {
                visible: wifiEnabled
                width: parent.width
                spacing: Math.round(6 * root.sf)

                Text {
                    text: "Available Networks"
                    font.pixelSize: Math.round(10 * root.sf)
                    font.weight: Font.DemiBold
                    color: root.textMuted
                    Layout.fillWidth: true
                    font.letterSpacing: 0.5
                }

                // Scan/refresh
                Rectangle {
                    Layout.preferredWidth: Math.round(24 * root.sf)
                    Layout.preferredHeight: Math.round(24 * root.sf)
                    radius: Math.round(12 * root.sf)
                    color: scanMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"

                    Canvas {
                        anchors.centerIn: parent
                        width: Math.round(12 * root.sf); height: Math.round(12 * root.sf)
                        property real s: root.sf
                        rotation: wifiScanning ? 360 : 0
                        Behavior on rotation { RotationAnimation { duration: 1000; loops: Animation.Infinite } }
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = wifiScanning ? "#3b82f6" : "#999"; ctx.lineWidth = 1.5;
                            ctx.beginPath(); ctx.arc(6, 6, 4, -0.5, Math.PI * 1.5); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(6, 1); ctx.lineTo(9, 2.5); ctx.lineTo(6, 4); ctx.stroke();
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                    }
                    MouseArea { id: scanMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: scanWifi() }
                }
            }

            // ── Error message ──
            Text {
                visible: wifiError !== ""
                width: parent.width
                text: wifiError
                font.pixelSize: Math.round(10 * root.sf)
                color: "#ef4444"
                wrapMode: Text.WordWrap
            }

            // ── Scanning indicator ──
            Text {
                visible: wifiScanning && wifiNetworks.length === 0
                width: parent.width
                text: "Scanning for networks..."
                font.pixelSize: Math.round(11 * root.sf)
                color: root.textMuted
                horizontalAlignment: Text.AlignHCenter
            }

            // ── Network List ──
            Rectangle {
                visible: wifiEnabled && wifiNetworks.length > 0
                width: parent.width
                height: Math.min(Math.round(240 * root.sf), netListCol.height + Math.round(4 * root.sf))
                radius: root.radiusSm
                color: Qt.rgba(0, 0, 0, 0.2)
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Math.round(2 * root.sf)
                    contentHeight: netListCol.height
                    clip: true; boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: netListCol
                        width: parent.width
                        spacing: Math.round(2 * root.sf)

                        Repeater {
                            model: wifiNetworks

                            Rectangle {
                                width: netListCol.width
                                height: Math.round(42 * root.sf)
                                radius: root.radiusSm
                                color: netItemMa.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.08)
                                    : modelData.connected ? Qt.rgba(0.13, 0.77, 0.37, 0.05) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(10 * root.sf)
                                    anchors.rightMargin: Math.round(10 * root.sf)
                                    spacing: Math.round(8 * root.sf)

                                    // Signal strength bars
                                    Row {
                                        spacing: Math.round(1.5 * root.sf)
                                        Layout.alignment: Qt.AlignVCenter

                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                width: Math.round(3 * root.sf)
                                                height: Math.round((4 + index * 3) * root.sf)
                                                radius: Math.round(1 * root.sf)
                                                anchors.bottom: parent.bottom
                                                color: {
                                                    var sig = modelData.signal;
                                                    var threshold = [0, 25, 50, 75][index];
                                                    if (sig > threshold) {
                                                        return modelData.connected ? "#34d399" : "#94a3b8";
                                                    }
                                                    return Qt.rgba(1,1,1,0.1);
                                                }
                                            }
                                        }
                                    }

                                    // SSID + security
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData.ssid
                                            font.pixelSize: Math.round(11.5 * root.sf)
                                            font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                                            color: modelData.connected ? "#34d399" : "#e2e8f0"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: modelData.connected ? "Connected"
                                                : modelData.security !== "" && modelData.security !== "--" ? "🔒 " + modelData.security
                                                : "Open"
                                            font.pixelSize: Math.round(9 * root.sf)
                                            color: modelData.connected ? Qt.rgba(0.2, 0.83, 0.6, 0.6) : root.textMuted
                                        }
                                    }

                                    // Connect button
                                    Rectangle {
                                        visible: !modelData.connected && !(wifiConnecting && wifiConnectingSSID === modelData.ssid)
                                        width: Math.round(60 * root.sf); height: Math.round(24 * root.sf)
                                        radius: Math.round(12 * root.sf)
                                        color: Qt.rgba(0.23, 0.51, 0.96, netConnMa.containsMouse ? 0.25 : 0.10)
                                        border.color: Qt.rgba(0.23, 0.51, 0.96, 0.3); border.width: 1
                                        Text {
                                            anchors.centerIn: parent; text: "Connect"
                                            font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Medium
                                            color: "#60a5fa"
                                        }
                                        MouseArea {
                                            id: netConnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var sec = modelData.security || "";
                                                if (sec !== "" && sec !== "--" && sec.toLowerCase() !== "open") {
                                                    passwordSSID = modelData.ssid;
                                                    passwordInput = "";
                                                    showPasswordDialog = true;
                                                } else {
                                                    connectWifi(modelData.ssid, "");
                                                }
                                            }
                                        }
                                    }

                                    // Connecting spinner text
                                    Text {
                                        visible: wifiConnecting && wifiConnectingSSID === modelData.ssid
                                        text: "Connecting..."
                                        font.pixelSize: Math.round(9 * root.sf)
                                        color: "#60a5fa"
                                    }
                                }

                                MouseArea {
                                    id: netItemMa; anchors.fill: parent; hoverEnabled: true
                                    // Just hover effect, clicking is via Connect button
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
            }

            // ── Password Dialog ──
            Rectangle {
                visible: showPasswordDialog
                width: parent.width
                height: pwdCol.height + Math.round(16 * root.sf)
                radius: root.radiusSm
                color: Qt.rgba(0.23, 0.51, 0.96, 0.06)
                border.color: Qt.rgba(0.23, 0.51, 0.96, 0.2); border.width: 1

                Column {
                    id: pwdCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Math.round(8 * root.sf)
                    spacing: Math.round(8 * root.sf)

                    Text {
                        text: "Enter password for \"" + passwordSSID + "\""
                        font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                        color: "#e2e8f0"; wrapMode: Text.WordWrap; width: parent.width
                    }

                    Rectangle {
                        width: parent.width; height: Math.round(34 * root.sf)
                        radius: root.radiusSm
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.color: pwdInput.activeFocus ? "#60a5fa" : Qt.rgba(1,1,1,0.1)
                        border.width: 1

                        TextInput {
                            id: pwdInput
                            anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                            font.pixelSize: Math.round(12 * root.sf)
                            color: "#ffffff"; echoMode: TextInput.Password
                            clip: true
                            onTextChanged: passwordInput = text
                            onAccepted: { if (passwordInput.length > 0) connectWifi(passwordSSID, passwordInput); }

                            Text {
                                visible: parent.text === ""
                                text: "Password"
                                font.pixelSize: Math.round(12 * root.sf)
                                color: Qt.rgba(1,1,1,0.3)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Math.round(6 * root.sf)

                        Rectangle {
                            Layout.fillWidth: true; height: Math.round(30 * root.sf)
                            radius: root.radiusSm
                            color: cancelPwdMa.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                            border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                            MouseArea { id: cancelPwdMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { showPasswordDialog = false; passwordInput = ""; }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; height: Math.round(30 * root.sf)
                            radius: root.radiusSm
                            color: connectPwdMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.3) : Qt.rgba(0.23, 0.51, 0.96, 0.15)
                            border.color: Qt.rgba(0.23, 0.51, 0.96, 0.4); border.width: 1
                            Text { anchors.centerIn: parent; text: wifiConnecting ? "Connecting..." : "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: "#60a5fa" }
                            MouseArea { id: connectPwdMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: passwordInput.length > 0 && !wifiConnecting
                                onClicked: connectWifi(passwordSSID, passwordInput)
                            }
                        }
                    }
                }
            }

            // ── No WiFi networks found ──
            Text {
                visible: wifiEnabled && !wifiScanning && wifiNetworks.length === 0 && wifiError === ""
                width: parent.width
                text: "No WiFi networks found"
                font.pixelSize: Math.round(11 * root.sf)
                color: root.textMuted
                horizontalAlignment: Text.AlignHCenter
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
                            onClicked: {
                                var newState = !ntpActive;
                                ntpActive = newState;
                                if (!newState) ntpSynced = false;
                                toggleNtp(newState);
                            }
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
