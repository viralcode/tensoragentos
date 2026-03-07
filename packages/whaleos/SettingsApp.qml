import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsApp; anchors.fill: parent; color: "transparent"
    property string activeTab: "profile"
    property var userList: []
    property bool showAddUser: false
    property string newUsername: ""
    property string newPassword: ""
    property bool waConnecting: false
    property string waQrCode: ""
    property bool waConnected: false
    property string tgToken: ""
    property string dcToken: ""
    // Display settings
    property var displayModes: []
    property var currentRes: ({"width": 1920, "height": 1080, "refresh": 60.0})
    property var gpuInfo: ({"name": "Detecting...", "driver": "-", "renderer": "-"})
    property var gfxInfo: ({"modules": "", "compositor": ""})
    property string selectedRes: ""
    property bool resApplied: false
    property int revertCountdown: 0
    Component.onCompleted: { loadUsers(); checkChannelStatus(); loadDisplayInfo(); }

    // Watch for settingsOpenTab — context menu sets this to jump to Display tab
    Connections {
        target: root
        function onSettingsOpenTabChanged() {
            if (root.settingsOpenTab === "display") {
                activeTab = "display";
                root.settingsOpenTab = ""; // reset
                loadDisplayInfo();
            }
        }
    }

    // ── Async signal handlers for SystemManager ──
    Connections {
        target: sysManager

        function onUserOpResult(operation, success, detail) {
            if (operation === "addUser") {
                if (success) {
                    root.showToast("User '" + detail + "' created successfully", "success");
                } else {
                    root.showToast("Failed to create user: " + detail, "error");
                }
                showAddUser = false; newUsername = ""; newPassword = ""; loadUsers();
            } else if (operation === "deleteUser") {
                if (success) {
                    root.showToast("User '" + detail + "' deleted", "success");
                } else {
                    root.showToast("Failed to delete user: " + detail, "error");
                }
                loadUsers();
            } else if (operation === "changePassword") {
                if (success) {
                    root.showToast("Password updated successfully", "success");
                } else {
                    root.showToast("Failed to update password: " + detail, "error");
                }
            }
        }

        function onDisplayInfoReady(xrandrText) {
            if (xrandrText && xrandrText.length > 10) {
                var parsed = parseXrandrModes(xrandrText);
                if (parsed.modes.length === 0) {
                    displayModes = defaultDisplayModes();
                    currentRes = {"width": 1280, "height": 800, "refresh": 60.0};
                } else {
                    displayModes = parsed.modes;
                    currentRes = parsed.current;
                    if (currentRes.width === 0) currentRes = {"width": 1280, "height": 800, "refresh": 60.0};
                }
            } else {
                displayModes = defaultDisplayModes();
                currentRes = {"width": 1280, "height": 800, "refresh": 60.0};
            }
            selectedRes = currentRes.width + "x" + currentRes.height;
            // Now fetch GPU info (async)
            sysManager.getGpuInfoAsync();
        }

        function onGpuInfoReady(gpuLine) {
            gpuInfo = {
                "name": gpuLine.length > 5 ? gpuLine.replace(/.*VGA.*:\s*/,"").split("[")[0].trim() : "VirtIO GPU (QEMU)",
                "driver": "virtio_gpu / pixman",
                "renderer": "wlroots (Cage compositor)"
            };
            gfxInfo = {"modules": "virtio_gpu, drm, kms", "compositor": "Cage (wlroots)"};
        }
    }

    function checkChannelStatus() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/channels/whatsapp/status");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try { var d = JSON.parse(xhr.responseText); waConnected = d.connected || false; } catch(e) {}
            }
        };
        xhr.send();
    }
    function loadUsers() {
        try {
            var result = sysManager.listUsers();
            userList = JSON.parse(result);
        } catch(e) {
            userList = [{ username: root.currentUser, role: "admin" }];
        }
    }
    function addUser() {
        if (!newUsername || !newPassword) { root.showToast("Username and password required", "error"); return; }
        if (typeof sysManager.addUserAsync === "function") {
            sysManager.addUserAsync(newUsername, newPassword);
        } else {
            var ok = sysManager.addUser(newUsername, newPassword);
            if (ok) { root.showToast("User '" + newUsername + "' created successfully", "success"); }
            else { root.showToast("Failed to create user '" + newUsername + "'", "error"); }
            showAddUser = false; newUsername = ""; newPassword = ""; loadUsers();
        }
    }
    function deleteUser(u) {
        if (u === root.currentUser) { root.showToast("Cannot delete your own account", "error"); return; }
        if (typeof sysManager.deleteUserAsync === "function") {
            sysManager.deleteUserAsync(u);
        } else {
            var ok = sysManager.deleteUser(u);
            if (ok) { root.showToast("User '" + u + "' deleted", "success"); }
            else { root.showToast("Failed to delete user '" + u + "'", "error"); }
            loadUsers();
        }
    }
    function changePassword(newPass) {
        if (!newPass) { root.showToast("Enter a new password", "error"); return; }
        if (typeof sysManager.changePasswordAsync === "function") {
            sysManager.changePasswordAsync(root.currentUser, newPass);
        } else {
            var ok = sysManager.changePassword(root.currentUser, newPass);
            if (ok) { root.showToast("Password updated successfully", "success"); }
            else { root.showToast("Failed to update password", "error"); }
        }
    }
    property int qrPollCount: 0
    function connectWhatsApp() {
        waConnecting = true; waQrCode = ""; qrPollCount = 0;
        root.showToast("Initializing WhatsApp...", "success");
        // First disconnect to clear any stuck state, then reconnect
        var dxhr = new XMLHttpRequest();
        dxhr.open("POST", root.apiBase + "/channels/whatsapp/disconnect");
        dxhr.setRequestHeader("Content-Type", "application/json");
        dxhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        dxhr.onreadystatechange = function() {
            if (dxhr.readyState === 4) {
                // Now reconnect fresh
                var xhr = new XMLHttpRequest();
                xhr.open("POST", root.apiBase + "/channels/whatsapp/connect");
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        if (xhr.status === 200) { qrTimer.start(); }
                        else { root.showToast("Failed to start WhatsApp (HTTP " + xhr.status + ")", "error"); waConnecting = false; }
                    }
                };
                xhr.send();
            }
        };
        dxhr.send();
    }
    function pollWAQR() {
        qrPollCount++;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/channels/whatsapp/status");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    waConnected = d.connected || false;
                    if (d.qrCode) { waQrCode = d.qrCode; root.showToast("Scan QR code with WhatsApp", "success"); }
                    if (waConnected) { root.showToast("WhatsApp connected!", "success"); waConnecting = false; }
                    else if (waConnecting && qrPollCount < 20) { qrTimer.start(); }
                    else { waConnecting = false; if (!waConnected) root.showToast("WhatsApp connection timed out", "error"); }
                } catch(e) { waConnecting = false; root.showToast("WhatsApp error", "error"); }
            } else if (xhr.readyState === 4) { waConnecting = false; root.showToast("WhatsApp status check failed", "error"); }
        };
        xhr.send();
    }
    Timer { id: qrTimer; interval: 3000; repeat: false; onTriggered: pollWAQR() }
    function connectCh(t, tok) {
        if (!tok) { root.showToast("Enter a token for " + t, "error"); return; }
        root.showToast("Connecting " + t.charAt(0).toUpperCase() + t.slice(1) + "...", "success");
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/channels/" + t);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { root.showToast(t.charAt(0).toUpperCase() + t.slice(1) + " connected successfully!", "success"); }
                else {
                    try { var e = JSON.parse(xhr.responseText); root.showToast(e.error || "Failed to connect " + t, "error"); }
                    catch(ex) { root.showToast("Failed to connect " + t + " (HTTP " + xhr.status + ")", "error"); }
                }
            }
        };
        xhr.send(JSON.stringify({ token: tok, enabled: true }));
    }
    // Parse xrandr output to extract display modes
    function parseXrandrModes(xrandrText) {
        var modes = [];
        var lines = xrandrText.split("\n");
        var inScreen = false;
        var curW = 0; var curH = 0; var curR = 0;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            // Screen resolution line: "   1280x800..."
            if (line.match(/^\s+\d+x\d+/)) {
                var parts = line.trim().split(/\s+/);
                var resDims = parts[0].split("x");
                var mW = parseInt(resDims[0]); var mH = parseInt(resDims[1]);
                var mR = 60.0;
                var isCurrent = line.indexOf("*") >= 0;
                var isPreferred = line.indexOf("+") >= 0;
                // Parse refresh rates
                for (var j = 1; j < parts.length; j++) {
                    var rStr = parts[j].replace("*","").replace("+","");
                    var r = parseFloat(rStr);
                    if (!isNaN(r) && r > 0) { mR = r; break; }
                }
                if (isCurrent) { curW = mW; curH = mH; curR = mR; }
                modes.push({"width": mW, "height": mH, "refresh": mR, "preferred": isPreferred, "current": isCurrent});
            }
        }
        return { modes: modes, current: {"width": curW || 1280, "height": curH || 800, "refresh": curR || 60.0} };
    }

    function defaultDisplayModes() {
        return [
            {"width":1920,"height":1080,"refresh":60.0,"preferred":true,"current":false},
            {"width":1680,"height":1050,"refresh":60.0,"preferred":false,"current":false},
            {"width":1600,"height":900,"refresh":60.0,"preferred":false,"current":false},
            {"width":1440,"height":900,"refresh":60.0,"preferred":false,"current":false},
            {"width":1366,"height":768,"refresh":60.0,"preferred":false,"current":false},
            {"width":1280,"height":1024,"refresh":60.0,"preferred":false,"current":false},
            {"width":1280,"height":800,"refresh":60.0,"preferred":false,"current":true},
            {"width":1280,"height":720,"refresh":60.0,"preferred":false,"current":false},
            {"width":1024,"height":768,"refresh":60.0,"preferred":false,"current":false}
        ];
    }

    function loadDisplayInfo() {
        if (typeof sysManager.getDisplayInfoAsync === "function") {
            // ASYNC: non-blocking display info fetch — result comes via onDisplayInfoReady
            sysManager.getDisplayInfoAsync();
        } else {
            // Sync fallback for current binary
            try {
                var xrandrText = sysManager.getDisplayInfo();
                if (xrandrText && xrandrText.length > 10) {
                    var parsed = parseXrandrModes(xrandrText);
                    if (parsed.modes.length === 0) {
                        displayModes = defaultDisplayModes();
                        currentRes = {"width": 1280, "height": 800, "refresh": 60.0};
                    } else {
                        displayModes = parsed.modes;
                        currentRes = parsed.current;
                        if (currentRes.width === 0) currentRes = {"width": 1280, "height": 800, "refresh": 60.0};
                    }
                } else {
                    throw new Error("no xrandr");
                }
            } catch(e) {
                displayModes = defaultDisplayModes();
                currentRes = {"width": 1280, "height": 800, "refresh": 60.0};
            }
            // GPU info (sync)
            try {
                var gpuRaw = JSON.parse(sysManager.runCommand("lspci 2>/dev/null | grep -i vga || echo 'VirtIO GPU'", "/"));
                var gpuLine = (gpuRaw.stdout || "").trim();
                gpuInfo = {
                    "name": gpuLine.length > 5 ? gpuLine.replace(/.*VGA.*:\s*/,"").split("[")[0].trim() : "VirtIO GPU (QEMU)",
                    "driver": "virtio_gpu / pixman",
                    "renderer": "wlroots (Cage compositor)"
                };
            } catch(e) {
                gpuInfo = {"name": "VirtIO GPU (QEMU)", "driver": "virtio_gpu", "renderer": "wlroots/pixman"};
            }
            gfxInfo = {"modules": "virtio_gpu, drm, kms", "compositor": "Cage (wlroots)"};
            selectedRes = currentRes.width + "x" + currentRes.height;
        }
    }

    function applyResolution(res) {
        var parts = res.split("x");
        if (parts.length !== 2) { root.showToast("Invalid resolution: " + res, "error"); return; }
        var w = parseInt(parts[0]); var h = parseInt(parts[1]);
        if (isNaN(w) || isNaN(h) || w < 640 || h < 480) { root.showToast("Invalid resolution", "error"); return; }

        var ok = sysManager.setDisplayResolution(w, h);
        if (ok) {
            resApplied = true;
            revertCountdown = 15;
            revertTimer.start();
            root.showToast("Resolution changed to " + res + ". Reverting in 15s if not confirmed.", "success");
        } else {
            // xrandr might fail if mode doesn't exist — try adding it first
            var modeName = w + "x" + h + "_60.00";
            var runFn = (typeof sysManager.runCommandQuick === "function") ? "runCommandQuick" : "runCommand";
            var cvtResult = JSON.parse(sysManager[runFn](
                "cvt " + w + " " + h + " 60 2>/dev/null | grep Modeline | sed 's/Modeline //'", "/"
            ));
            var modeline = (cvtResult.stdout || "").trim();
            if (modeline) {
                // Add mode then retry
                sysManager[runFn](
                    "xrandr --newmode " + modeline + " 2>/dev/null; " +
                    "xrandr --addmode XWAYLAND0 '" + modeName + "' 2>/dev/null; " +
                    "xrandr --output XWAYLAND0 --mode '" + modeName + "' 2>/dev/null", "/"
                );
                resApplied = true;
                revertCountdown = 15;
                revertTimer.start();
                root.showToast("Resolution changed to " + res + " (mode added). Reverting in 15s if not confirmed.", "success");
            } else {
                root.showToast("Cannot change to " + res + " — mode not supported by display", "error");
            }
        }
    }

    function confirmResolution() {
        resApplied = false;
        revertTimer.stop();
        var parts = selectedRes.split("x");
        currentRes = {"width": parseInt(parts[0]), "height": parseInt(parts[1]), "refresh": 60.0};
        root.showToast("Resolution confirmed: " + selectedRes, "success");
    }
    function revertResolution() {
        resApplied = false;
        revertTimer.stop();
        var oldRes = currentRes.width + "x" + currentRes.height;
        selectedRes = oldRes;
        // Apply the old resolution directly (not through applyResolution to avoid countdown)
        var parts2 = oldRes.split("x");
        sysManager.setDisplayResolution(parseInt(parts2[0]), parseInt(parts2[1]));
        root.showToast("Resolution reverted to " + oldRes, "info");
    }

    Timer {
        id: revertTimer; interval: 1000; repeat: true
        onTriggered: {

            revertCountdown--;
            if (revertCountdown <= 0) { revertResolution(); }
        }
    }
    RowLayout {
        anchors.fill: parent; spacing: Math.round(0 * root.sf)
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: Math.round(170 * root.sf); color: Qt.rgba(0,0,0,0.2)
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: Math.round(1 * root.sf); color: root.borderColor }
            Column {
                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); anchors.topMargin: Math.round(10 * root.sf); spacing: Math.round(2 * root.sf)
                Repeater {
                    model: [{ id: "profile", icon: "\uf007", label: "Profile" }, { id: "users", icon: "\uf0c0", label: "Users" }, { id: "channels", icon: "\uf1e6", label: "Channels" }, { id: "display", icon: "\uf108", label: "Display" }]
                    delegate: Rectangle {
                        width: parent ? parent.width : 150; height: Math.round(34 * root.sf); radius: root.radiusSm
                        color: activeTab === modelData.id ? Qt.rgba(1,1,1,0.08) : sMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"
                        Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(10 * root.sf); spacing: Math.round(8 * root.sf)
                            Text { text: modelData.icon; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(13 * root.sf); color: root.accentBlue }
                            Text { text: modelData.label; font.pixelSize: Math.round(13 * root.sf); color: activeTab === modelData.id ? "#fff" : root.textSecondary }
                        }
                        Rectangle { visible: activeTab === modelData.id; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Math.round(3 * root.sf); height: Math.round(18 * root.sf); radius: 2; color: root.accentBlue }
                        MouseArea { id: sMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = modelData.id }
                    }
                }
            }
        }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; contentHeight: cCol.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: cCol; width: parent.width - 32; x: Math.round(16 * root.sf); y: Math.round(16 * root.sf); spacing: Math.round(14 * root.sf)
                // PROFILE
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "profile"
                    Text { text: "Profile"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Manage your account settings"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                    Rectangle { width: parent.width; height: pI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: pI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            RowLayout { spacing: Math.round(10 * root.sf)
                                Rectangle { width: Math.round(48 * root.sf); height: Math.round(48 * root.sf); radius: 24; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: root.currentUser.charAt(0).toUpperCase(); font.pixelSize: Math.round(20 * root.sf); font.weight: Font.Bold; color: "#fff" }
                            }
                                Column { spacing: Math.round(2 * root.sf); Layout.fillWidth: true
                                Text { text: root.currentUser; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                Text { text: "Administrator"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                            }
                            }
                            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }
                            Text { text: "Change Password"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Rectangle { Layout.fillWidth: true; height: Math.round(32 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { id: pwField; anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(12 * root.sf); echoMode: TextInput.Password; clip: true
                                Text { visible: !parent.text; text: "New password..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                            } }
                                Rectangle { width: Math.round(65 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Update"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: changePassword(pwField.text) }
                            }
                            }
                        }
                    }
                }
                // USERS
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "users"
                    RowLayout { width: parent.width
                        Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                        Text { text: "User Management"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        Text { text: "Manage who can access this system"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                    }
                        Rectangle { width: Math.round(90 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                        Text { anchors.centerIn: parent; text: "+ Add User"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showAddUser = true }
                    }
                    }
                    Rectangle { visible: showAddUser; width: parent.width; height: aUI.height + 24; radius: root.radiusMd; color: Qt.rgba(0.13,0.77,0.37,0.08); border.color: Qt.rgba(0.13,0.77,0.37,0.2); border.width: 1
                        Column { id: aUI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            Text { text: "Create New User"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            RowLayout { width: parent.width; spacing: Math.round(8 * root.sf)
                                Column { Layout.fillWidth: true; spacing: Math.round(4 * root.sf)
                                Text { text: "Username"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                Rectangle { width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true; onTextChanged: newUsername = text
                                Text { visible: !parent.text; text: "Username..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                            } }
                            }
                                Column { Layout.fillWidth: true; spacing: Math.round(4 * root.sf)
                                Text { text: "Password"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                Rectangle { width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(12 * root.sf); echoMode: TextInput.Password; clip: true; onTextChanged: newPassword = text
                                Text { visible: !parent.text; text: "Password..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                            } }
                            }
                            }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                            Item { Layout.fillWidth: true }
                                Rectangle { width: Math.round(55 * root.sf); height: Math.round(26 * root.sf); radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06)
                                Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showAddUser = false }
                            }
                                Rectangle { width: Math.round(55 * root.sf); height: Math.round(26 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addUser() }
                            }
                            }
                        }
                    }
                    Repeater { model: userList; delegate: Rectangle { width: cCol.width; height: Math.round(52 * root.sf); radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        RowLayout { anchors.fill: parent; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            Rectangle { width: Math.round(32 * root.sf); height: Math.round(32 * root.sf); radius: 16; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: (modelData.username || "?").charAt(0).toUpperCase(); color: "#fff"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Medium }
                        }
                            Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                            Text { text: modelData.username || ""; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.Medium; color: "#fff" }
                            Text { text: modelData.role || "user"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                        }
                            Rectangle { width: Math.round(50 * root.sf); height: Math.round(20 * root.sf); radius: 10; color: Qt.rgba(0.13,0.77,0.37,0.15)
                            Text { anchors.centerIn: parent; text: "Active"; font.pixelSize: Math.round(9 * root.sf); color: root.accentGreen }
                        }
                            Rectangle { visible: (modelData.username || "") !== root.currentUser; width: Math.round(50 * root.sf); height: Math.round(22 * root.sf); radius: root.radiusSm; color: Qt.rgba(0.94,0.27,0.27,0.1); border.color: Qt.rgba(0.94,0.27,0.27,0.3); border.width: 1
                            Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: Math.round(9 * root.sf); color: "#ef4444" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deleteUser(modelData.username) }
                        }
                        }
                    }
                }
                }
                // CHANNELS
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "channels"
                    Text { text: "Channels"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Connect messaging platforms"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                    Rectangle { width: parent.width; height: wI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: waConnected ? Qt.rgba(0.13,0.77,0.37,0.35) : root.borderColor; border.width: waConnected ? 2 : 1
                        // Connected glow effect
                        Rectangle { visible: waConnected; anchors.fill: parent; radius: parent.radius; color: Qt.rgba(0.13,0.77,0.37,0.04) }
                        Column { id: wI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width; spacing: Math.round(10 * root.sf)
                                Rectangle { width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: waConnected ? Qt.rgba(0.15,0.68,0.38,0.25) : Qt.rgba(0.15,0.68,0.38,0.15)
                                Text { anchors.centerIn: parent; text: "\uf232"; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(16 * root.sf); color: "#25D366" }
                            }
                                Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                                Text { text: "WhatsApp"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                Row { spacing: Math.round(6 * root.sf)
                                    Rectangle { visible: waConnected; width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: width / 2; color: "#22c55e"; anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on opacity { running: waConnected; loops: Animation.Infinite; NumberAnimation { to: 0.4; duration: 1500 } NumberAnimation { to: 1.0; duration: 1500 } }
                                    }
                                    Text { text: waConnected ? "Connected & active" : "Connect via QR code"; font.pixelSize: Math.round(11 * root.sf); color: waConnected ? "#22c55e" : root.textMuted }
                                }
                            }
                                // Connected: green pill badge + disconnect option
                                Row { visible: waConnected; spacing: Math.round(6 * root.sf)
                                    Rectangle { width: connBadge.width + Math.round(16 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(14 * root.sf); color: Qt.rgba(0.13,0.85,0.42,0.15); border.color: Qt.rgba(0.13,0.85,0.42,0.3); border.width: 1
                                        Row { id: connBadge; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                                            Text { text: "✓"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Bold; color: "#22c55e" }
                                            Text { text: "Connected"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#22c55e" }
                                        }
                                    }
                                    Rectangle { width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(14 * root.sf); color: waDisMa.containsMouse ? Qt.rgba(0.94,0.27,0.27,0.2) : Qt.rgba(1,1,1,0.06)
                                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: Math.round(10 * root.sf); color: waDisMa.containsMouse ? "#ef4444" : root.textMuted }
                                        MouseArea { id: waDisMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { waConnected = false; root.showToast("WhatsApp disconnected", "success"); } }
                                    }
                                }
                                // Not connected: connect / waiting button
                                Rectangle { visible: !waConnected; width: Math.round(70 * root.sf); height: Math.round(28 * root.sf); radius: root.radiusSm; color: waConnecting ? Qt.rgba(1,1,1,0.08) : root.accentBlue
                                Text { anchors.centerIn: parent; text: waConnecting ? "Waiting..." : "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: waConnecting ? root.textMuted : "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!waConnected && !waConnecting) connectWhatsApp() }
                            }
                            }
                            Rectangle { visible: waQrCode !== "" && !waConnected; width: Math.round(200 * root.sf); height: Math.round(200 * root.sf); radius: root.radiusMd; color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter
                            Image { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); source: waQrCode; fillMode: Image.PreserveAspectFit; smooth: true }
                        }
                            Text { visible: waConnecting && waQrCode === ""; text: "Initializing WhatsApp..."; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                    Rectangle { width: parent.width; height: tI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: tI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width; spacing: Math.round(10 * root.sf)
                            Rectangle { width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: Qt.rgba(0.16,0.55,0.85,0.15)
                            Text { anchors.centerIn: parent; text: "\uf2c6"; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(16 * root.sf); color: "#0088cc" }
                        }
                            Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                            Text { text: "Telegram"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Connect with bot token"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        } }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                            Rectangle { Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(11 * root.sf); clip: true; onTextChanged: tgToken = text
                            Text { visible: !parent.text; text: "Bot token from @BotFather..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(11 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                        } }
                            Rectangle { width: Math.round(65 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectCh("telegram", tgToken) }
                        } }
                        }
                    }
                    Rectangle { width: parent.width; height: dI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: dI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width; spacing: Math.round(10 * root.sf)
                            Rectangle { width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: Qt.rgba(0.35,0.40,0.95,0.15)
                            Text { anchors.centerIn: parent; text: "\uf11b"; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(16 * root.sf); color: "#5865F2" }
                        }
                            Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                            Text { text: "Discord"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Connect with bot token"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        } }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                            Rectangle { Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(11 * root.sf); clip: true; onTextChanged: dcToken = text
                            Text { visible: !parent.text; text: "Discord bot token..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(11 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                        } }
                            Rectangle { width: Math.round(65 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectCh("discord", dcToken) }
                        } }
                        }
                    }
                }
                // DISPLAY
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "display"
                    Text { text: "Display Settings"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Configure screen resolution, scaling, and graphics"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }

                    // ── Current Resolution Card ──
                    Rectangle { width: parent.width; height: curResCol.height + Math.round(24 * root.sf); radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: curResCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            Text { text: "Current Resolution"; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            RowLayout { width: parent.width; spacing: Math.round(16 * root.sf)
                                Column { spacing: Math.round(2 * root.sf)
                                    Text { text: currentRes.width + " × " + currentRes.height; font.pixelSize: Math.round(22 * root.sf); font.weight: Font.Bold; color: root.accentBlue }
                                    Text { text: currentRes.refresh + " Hz refresh rate"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: refreshCol.width + Math.round(16 * root.sf); height: refreshCol.height + Math.round(12 * root.sf); radius: root.radiusSm; color: Qt.rgba(0.15, 0.7, 0.4, 0.1); border.color: Qt.rgba(0.15, 0.7, 0.4, 0.2); border.width: 1
                                    Column { id: refreshCol; anchors.centerIn: parent; spacing: Math.round(1 * root.sf)
                                        Text { text: "Active"; font.pixelSize: Math.round(9 * root.sf); color: root.accentGreen; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: currentRes.refresh + " Hz"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: root.accentGreen; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                }
                            }
                        }
                    }

                    // ── Resolution Picker Card ──
                    Rectangle { width: parent.width; height: resPickerCol.height + Math.round(24 * root.sf); radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: resPickerCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width
                                Text { text: "Screen Resolution"; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: reloadText.width + Math.round(16 * root.sf); height: Math.round(24 * root.sf); radius: root.radiusSm
                                    color: reloadMa.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                                    Text { id: reloadText; anchors.centerIn: parent; text: "Refresh"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                                    MouseArea { id: reloadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: loadDisplayInfo() }
                                }
                            }
                            Text { text: "Select a resolution for your display"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }

                            // Resolution list
                            Repeater {
                                model: displayModes
                                delegate: Rectangle {
                                    width: resPickerCol.width; height: Math.round(36 * root.sf); radius: root.radiusSm
                                    property bool isSelected: selectedRes === (modelData.width + "x" + modelData.height)
                                    property bool isCurrent: currentRes.width === modelData.width && currentRes.height === modelData.height
                                    color: resItemMa.containsMouse ? Qt.rgba(1,1,1,0.06) : isSelected ? Qt.rgba(0.24, 0.39, 1, 0.08) : "transparent"
                                    border.color: isSelected ? Qt.rgba(0.24, 0.39, 1, 0.3) : "transparent"
                                    border.width: isSelected ? 1 : 0
                                    RowLayout { anchors.fill: parent; anchors.leftMargin: Math.round(10 * root.sf); anchors.rightMargin: Math.round(10 * root.sf); spacing: Math.round(8 * root.sf)
                                        // Radio indicator
                                        Rectangle { width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); radius: Math.round(7 * root.sf)
                                            color: "transparent"; border.color: isSelected ? root.accentBlue : Qt.rgba(1,1,1,0.2); border.width: 1.5
                                            Rectangle { anchors.centerIn: parent; width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: Math.round(4 * root.sf); color: root.accentBlue; visible: isSelected }
                                        }
                                        Text { text: modelData.width + " × " + modelData.height; font.pixelSize: Math.round(12 * root.sf); color: isSelected ? "#fff" : root.textPrimary; font.weight: isSelected ? Font.DemiBold : Font.Normal }
                                        Text {
                                            text: {
                                                var ratio = modelData.width / modelData.height;
                                                if (Math.abs(ratio - 16/9) < 0.05) return "16:9";
                                                if (Math.abs(ratio - 16/10) < 0.05) return "16:10";
                                                if (Math.abs(ratio - 4/3) < 0.05) return "4:3";
                                                if (Math.abs(ratio - 5/4) < 0.05) return "5:4";
                                                if (Math.abs(ratio - 21/9) < 0.05) return "21:9";
                                                return "";
                                            }
                                            font.pixelSize: Math.round(10 * root.sf); color: root.textMuted
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text { text: modelData.refresh + " Hz"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                                        Rectangle { visible: isCurrent; width: curLabel.width + Math.round(10 * root.sf); height: Math.round(16 * root.sf); radius: 8; color: Qt.rgba(0.15, 0.7, 0.4, 0.15)
                                            Text { id: curLabel; anchors.centerIn: parent; text: "Current"; font.pixelSize: Math.round(8 * root.sf); color: root.accentGreen }
                                        }
                                        Rectangle { visible: modelData.preferred || false; width: prefLabel.width + Math.round(10 * root.sf); height: Math.round(16 * root.sf); radius: 8; color: Qt.rgba(0.24, 0.39, 1, 0.15)
                                            Text { id: prefLabel; anchors.centerIn: parent; text: "Recommended"; font.pixelSize: Math.round(8 * root.sf); color: root.accentBlue }
                                        }
                                    }
                                    MouseArea { id: resItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: selectedRes = modelData.width + "x" + modelData.height }
                                }
                            }

                            // Apply / Revert buttons
                            RowLayout { width: parent.width; spacing: Math.round(8 * root.sf); visible: selectedRes !== (currentRes.width + "x" + currentRes.height) && !resApplied
                                Item { Layout.fillWidth: true }
                                Rectangle { width: Math.round(70 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06)
                                    Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selectedRes = currentRes.width + "x" + currentRes.height }
                                }
                                Rectangle { width: Math.round(130 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                    Text { anchors.centerIn: parent; text: "Apply Resolution"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: applyResolution(selectedRes) }
                                }
                            }

                            // Revert countdown bar
                            Rectangle { width: parent.width; height: revertCol.height + Math.round(16 * root.sf); radius: root.radiusSm; color: Qt.rgba(0.9, 0.6, 0.1, 0.1); border.color: Qt.rgba(0.9, 0.6, 0.1, 0.3); border.width: 1; visible: resApplied
                                Column { id: revertCol; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
                                    Text { text: "Keep this resolution?"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fbbf24"; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: "Reverting in " + revertCountdown + " seconds..."; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                                    RowLayout { spacing: Math.round(8 * root.sf); anchors.horizontalCenter: parent.horizontalCenter
                                        Rectangle { width: Math.round(80 * root.sf); height: Math.round(28 * root.sf); radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06)
                                            Text { anchors.centerIn: parent; text: "Revert Now"; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: revertResolution() }
                                        }
                                        Rectangle { width: Math.round(130 * root.sf); height: Math.round(28 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                            Text { anchors.centerIn: parent; text: "Keep Resolution"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: confirmResolution() }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── UI Scaling Card ──
                    Rectangle { width: parent.width; height: scaleCol.height + Math.round(24 * root.sf); radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: scaleCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            Text { text: "UI Scaling"; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Adjust the size of text, icons, and interface elements"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                            Repeater {
                                model: [
                                    { label: "Compact (Small UI)", scale: 0.75, desc: "More content, smaller elements" },
                                    { label: "Default", scale: 1.0, desc: "Balanced layout" },
                                    { label: "Comfortable", scale: 1.15, desc: "Slightly larger elements" },
                                    { label: "Large", scale: 1.35, desc: "Easier to read" },
                                    { label: "Extra Large", scale: 1.6, desc: "Maximum readability" }
                                ]
                                delegate: Rectangle {
                                    width: scaleCol.width; height: Math.round(38 * root.sf); radius: root.radiusSm
                                    property bool isActive: Math.abs(root.userScale - modelData.scale) < 0.01
                                    color: scaleMa.containsMouse ? Qt.rgba(1,1,1,0.06) : isActive ? Qt.rgba(0.24, 0.39, 1, 0.08) : "transparent"
                                    border.color: isActive ? Qt.rgba(0.24, 0.39, 1, 0.3) : "transparent"; border.width: isActive ? 1 : 0
                                    RowLayout { anchors.fill: parent; anchors.leftMargin: Math.round(10 * root.sf); anchors.rightMargin: Math.round(10 * root.sf); spacing: Math.round(8 * root.sf)
                                        Rectangle { width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); radius: Math.round(7 * root.sf)
                                            color: "transparent"; border.color: isActive ? root.accentBlue : Qt.rgba(1,1,1,0.2); border.width: 1.5
                                            Rectangle { anchors.centerIn: parent; width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: Math.round(4 * root.sf); color: root.accentBlue; visible: isActive }
                                        }
                                        Column { Layout.fillWidth: true; spacing: Math.round(1 * root.sf)
                                            Text { text: modelData.label; font.pixelSize: Math.round(12 * root.sf); color: isActive ? "#fff" : root.textPrimary; font.weight: isActive ? Font.DemiBold : Font.Normal }
                                            Text { text: modelData.desc; font.pixelSize: Math.round(9 * root.sf); color: root.textMuted }
                                        }
                                        Text { text: (modelData.scale * 100).toFixed(0) + "%"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                                    }
                                    MouseArea { id: scaleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.userScale = modelData.scale; root.showToast("Display: " + modelData.label, "success"); } }
                                }
                            }
                        }
                    }

                    // ── GPU & Driver Info Card ──
                    Rectangle { width: parent.width; height: gpuCol.height + Math.round(24 * root.sf); radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: gpuCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            Text { text: "Graphics & Driver Information"; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            // GPU Name row
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Text { text: "GPU"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; Layout.preferredWidth: Math.round(80 * root.sf) }
                                Text { text: gpuInfo.name || "Unknown"; font.pixelSize: Math.round(11 * root.sf); color: root.textPrimary }
                            }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }
                            // Driver row
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Text { text: "Driver"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; Layout.preferredWidth: Math.round(80 * root.sf) }
                                Text { text: gpuInfo.driver || "-"; font.pixelSize: Math.round(11 * root.sf); color: root.textPrimary }
                            }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }
                            // Renderer row
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Text { text: "Renderer"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; Layout.preferredWidth: Math.round(80 * root.sf) }
                                Text { text: gpuInfo.renderer || "-"; font.pixelSize: Math.round(11 * root.sf); color: root.textPrimary }
                            }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }
                            // Compositor row
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Text { text: "Compositor"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; Layout.preferredWidth: Math.round(80 * root.sf) }
                                Text { text: gfxInfo.compositor || "-"; font.pixelSize: Math.round(11 * root.sf); color: root.textPrimary }
                            }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }
                            // Kernel modules row
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Text { text: "Modules"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; Layout.preferredWidth: Math.round(80 * root.sf) }
                                Text { text: gfxInfo.modules || "None detected"; font.pixelSize: Math.round(11 * root.sf); color: root.textPrimary; wrapMode: Text.Wrap; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
