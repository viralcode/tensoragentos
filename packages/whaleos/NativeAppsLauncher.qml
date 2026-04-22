import QtQuick
import QtQuick.Layouts

Rectangle {
    id: nativeAppsLauncher
    anchors.fill: parent
    color: "#1e1e2e"

    property string activeTab: "installed"
    property string searchQuery: ""
    property var storeResults: []
    property bool storeLoading: false
    property int totalAvailable: 0
    property var featuredApps: []
    property var installedPkgList: []
    property var busyPkgs: []
    property string busyPkgStatus: ""
    property var userInstalledApps: []

    property var nativeApps: [
        { appId: "native-chromium", label: "Chromium", desc: "Web browser", cmd: "chromium --ozone-platform=wayland 2>/dev/null || chromium-browser --ozone-platform=wayland", searchName: "Chromium", iconType: "chromium", accent: "#4285f4", pkg: "chromium", builtIn: true },
        { appId: "native-mousepad", label: "Editor", desc: "Text editor", cmd: "mousepad", searchName: "Mousepad", iconType: "editor", accent: "#4ade80", pkg: "mousepad", builtIn: true },
        { appId: "native-galculator", label: "Calculator", desc: "Desktop calculator", cmd: "galculator", searchName: "galculator", iconType: "calculator", accent: "#c084fc", pkg: "galculator", builtIn: true },
        { appId: "native-libreoffice-writer", label: "Writer", desc: "Word processor", cmd: "libreoffice --writer", searchName: "libreoffice", iconType: "office-writer", accent: "#2563eb", pkg: "libreoffice-writer", builtIn: true },
        { appId: "native-libreoffice-calc", label: "Calc", desc: "Spreadsheets", cmd: "libreoffice --calc", searchName: "libreoffice", iconType: "office-calc", accent: "#16a34a", pkg: "libreoffice-calc", builtIn: true },
        { appId: "native-libreoffice-impress", label: "Impress", desc: "Presentations", cmd: "libreoffice --impress", searchName: "libreoffice", iconType: "office-impress", accent: "#dc2626", pkg: "libreoffice-impress", builtIn: true },
        { appId: "native-evince", label: "PDF Viewer", desc: "Document viewer", cmd: "evince", searchName: "evince", iconType: "pdf", accent: "#ef4444", pkg: "evince", builtIn: true }
    ]

    function getAllInstalledApps() {
        var all = [];
        for (var i = 0; i < nativeApps.length; i++) all.push(nativeApps[i]);
        for (var j = 0; j < userInstalledApps.length; j++) all.push(userInstalledApps[j]);
        return all;
    }

    Component.onCompleted: {
        refreshInstalled();
        loadFeatured();
        countAvailable();
        loadUserApps();
    }

    function launchNativeViaHelper(cmd, label) {
        // Launch via the helper service with proper Wayland env
        // nohup + & ensures the app runs independently
        var launchCmd = "nohup bash -c 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games; " +
            "export WAYLAND_DISPLAY=whaleos-0; " +
            "export XDG_RUNTIME_DIR=/run/user/1000; " +
            "export GDK_BACKEND=wayland; " +
            "export QT_QPA_PLATFORM=wayland; " +
            "export LIBGL_ALWAYS_SOFTWARE=1; " +
            "export GTK_CSD=0; " +
            "export GTK_USE_PORTAL=0; " +
            "export HOME=/home/ainux; " +
            "export DISPLAY=:0; " +
            "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; " +
            cmd + "' >/dev/null 2>&1 &";
        helperExec(launchCmd, function() {});
        root.showToast(label + " launching...", "info");
    }

    function helperExec(cmd, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/exec");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    if (callback) callback(resp.stdout || "");
                } catch(e) { if (callback) callback(""); }
            } else if (xhr.readyState === 4) {
                if (callback) callback("");
            }
        };
        xhr.send(JSON.stringify({ command: cmd }));
    }

    function refreshInstalled() {
        helperExec("dpkg --get-selections | grep -w install | awk '{print $1}'", function(output) {
            if (output && output.trim().length > 0) {
                installedPkgList = output.trim().split("\n");
            }
        });
    }

    function countAvailable() {
        helperExec("apt-cache pkgnames 2>/dev/null | wc -l", function(output) {
            var n = parseInt(output.trim());
            if (!isNaN(n)) totalAvailable = n;
        });
    }

    function loadFeatured() {
        helperExec("apt-cache search --names-only 'firefox-esr\\|gimp\\|vlc\\|inkscape\\|blender\\|audacity\\|krita\\|thunderbird\\|filezilla\\|mpv\\|geany\\|meld\\|gparted\\|keepassxc\\|shotwell\\|rhythmbox\\|supertuxkart\\|hexchat\\|htop\\|neofetch' 2>/dev/null | head -25", function(output) {
            if (!output || output.trim().length === 0) return;
            var lines = output.trim().split("\n");
            var results = [];
            for (var i = 0; i < lines.length; i++) {
                var idx = lines[i].indexOf(" - ");
                if (idx > 0) results.push({ pkg: lines[i].substring(0, idx).trim(), desc: lines[i].substring(idx + 3).trim() });
            }
            featuredApps = results;
        });
    }

    function searchStore(query) {
        if (!query || query.trim().length < 2) { storeResults = []; return; }
        storeLoading = true;
        helperExec("apt-cache search '" + query.trim() + "' 2>/dev/null | head -50", function(output) {
            storeLoading = false;
            if (!output || output.trim().length === 0) { storeResults = []; return; }
            var lines = output.trim().split("\n");
            var results = [];
            for (var i = 0; i < lines.length; i++) {
                var idx = lines[i].indexOf(" - ");
                if (idx > 0) results.push({ pkg: lines[i].substring(0, idx).trim(), desc: lines[i].substring(idx + 3).trim() });
            }
            storeResults = results;
        });
    }

    function isPkgInstalled(pkg) {
        for (var i = 0; i < installedPkgList.length; i++) {
            if (installedPkgList[i] === pkg || installedPkgList[i].indexOf(pkg + ":") === 0) return true;
        }
        return false;
    }
    function isPkgBusy(pkg) {
        for (var i = 0; i < busyPkgs.length; i++) { if (busyPkgs[i] === pkg) return true; }
        return false;
    }

    function saveUserApps() {
        var data = JSON.stringify(userInstalledApps);
        helperExec("echo '" + data.replace(/'/g, "'\\''") + "' > /home/ainux/.whaleos-user-apps.json", function() {});
    }
    function loadUserApps() {
        helperExec("cat /home/ainux/.whaleos-user-apps.json 2>/dev/null", function(output) {
            if (output && output.trim().length > 2) {
                try { userInstalledApps = JSON.parse(output.trim()); } catch(e) {}
            }
        });
    }

    function installPkg(pkg, desc) {
        var b = busyPkgs.slice(); b.push(pkg); busyPkgs = b;
        busyPkgStatus = "Downloading " + pkg + "...";
        root.showToast("Installing " + pkg + "...", "info");

        // Run apt-get install, then verify with dpkg -s
        var cmd = "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y " + pkg + " 2>&1; echo EXIT_CODE=$?";
        helperExec(cmd, function(output) {
            busyPkgStatus = "Verifying " + pkg + "...";

            // Check if apt-get reported errors
            if (output && (output.indexOf("E: Unable to locate") >= 0 || output.indexOf("E: Package") >= 0)) {
                var nb = []; for (var i = 0; i < busyPkgs.length; i++) { if (busyPkgs[i] !== pkg) nb.push(busyPkgs[i]); } busyPkgs = nb;
                busyPkgStatus = "";
                root.showToast("Package '" + pkg + "' not found", "error");
                return;
            }

            // Verify the package is really installed
            helperExec("dpkg -s " + pkg + " 2>&1 | grep 'Status:'", function(verify) {
                var nb = []; for (var i = 0; i < busyPkgs.length; i++) { if (busyPkgs[i] !== pkg) nb.push(busyPkgs[i]); } busyPkgs = nb;
                busyPkgStatus = "";
                refreshInstalled();

                if (!verify || verify.indexOf("install ok installed") < 0) {
                    root.showToast("Failed to install " + pkg, "error");
                    return;
                }

                root.showToast(pkg + " installed!", "success");

                helperExec("find /usr/share/applications -name '*" + pkg + "*.desktop' -o -name '" + pkg + ".desktop' 2>/dev/null | head -1", function(desktop) {
                    var launchCmd = pkg;
                    var appLabel = pkg;
                    var appDesc = desc || pkg;

                    if (desktop && desktop.trim().length > 0) {
                        helperExec("grep -P '^(Exec|Name)=' '" + desktop.trim() + "' | grep -v 'Name\\[' | head -4", function(deskData) {
                            if (deskData) {
                                var lines = deskData.trim().split("\n");
                                for (var k = 0; k < lines.length; k++) {
                                    if (lines[k].indexOf("Exec=") === 0) launchCmd = lines[k].substring(5).replace(/ %[fFuUdDnNickvm]/g, "").trim();
                                    if (lines[k].indexOf("Name=") === 0) appLabel = lines[k].substring(5).trim();
                                }
                            }
                            addUserApp(pkg, appLabel, appDesc, launchCmd);
                        });
                    } else {
                        addUserApp(pkg, appLabel, appDesc, launchCmd);
                    }
                });
            });
        });
    }

    function addUserApp(pkg, label, desc, cmd) {
        for (var i = 0; i < nativeApps.length; i++) { if (nativeApps[i].pkg === pkg) return; }
        for (var j = 0; j < userInstalledApps.length; j++) { if (userInstalledApps[j].pkg === pkg) return; }
        var apps = userInstalledApps.slice();
        apps.push({
            appId: "native-" + pkg, label: label, desc: desc, cmd: cmd,
            searchName: pkg, iconType: "generic", accent: accentFor(pkg), pkg: pkg, builtIn: false
        });
        userInstalledApps = apps;
        saveUserApps();
    }

    function removePkg(pkg) {
        var b = busyPkgs.slice(); b.push(pkg); busyPkgs = b;
        busyPkgStatus = "Removing " + pkg + "...";
        root.showToast("Removing " + pkg + "...", "info");
        helperExec("sudo apt-get purge -y " + pkg + " 2>&1 && sudo apt-get autoremove -y 2>&1", function() {
            var nb = []; for (var i = 0; i < busyPkgs.length; i++) { if (busyPkgs[i] !== pkg) nb.push(busyPkgs[i]); } busyPkgs = nb;
            busyPkgStatus = "";
            refreshInstalled();
            var apps = [];
            for (var j = 0; j < userInstalledApps.length; j++) {
                if (userInstalledApps[j].pkg !== pkg) apps.push(userInstalledApps[j]);
            }
            userInstalledApps = apps;
            saveUserApps();
            root.showToast(pkg + " removed", "success");
        });
    }

    function accentFor(pkg) {
        var c = ["#60a5fa","#4ade80","#c084fc","#f97316","#ef4444","#22c55e","#8b5cf6","#06b6d4","#eab308","#ec4899","#14b8a6","#a855f7","#0ea5e9"];
        var h = 0;
        for (var i = 0; i < pkg.length; i++) h = ((h << 5) - h) + pkg.charCodeAt(i);
        return c[Math.abs(h) % c.length];
    }

    Timer { id: searchDebounce; interval: 400; onTriggered: searchStore(searchQuery) }

    // ── Progress polling timer ──
    Timer {
        id: progressTimer; interval: 2000; repeat: true
        running: busyPkgs.length > 0
        onTriggered: {
            if (busyPkgs.length > 0) {
                var pkg = busyPkgs[0];
                busyPkgStatus = "Installing " + pkg + "...";
            }
        }
    }

    Column {
        anchors.fill: parent; spacing: 0

        // ── Tab bar ──
        Rectangle {
            width: parent.width; height: Math.round(42 * root.sf); color: "#15151f"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: Math.round(14 * root.sf)
                spacing: Math.round(4 * root.sf)

                Rectangle {
                    width: instLbl.width + Math.round(20 * root.sf); height: Math.round(30 * root.sf)
                    radius: Math.round(6 * root.sf)
                    color: activeTab === "installed" ? "#1e3a5f" : instTabMa.containsMouse ? "#1e1e30" : "transparent"
                    border.color: activeTab === "installed" ? "#3b82f6" : "transparent"; border.width: 1
                    Text { id: instLbl; anchors.centerIn: parent; text: "Installed (" + getAllInstalledApps().length + ")"; font.pixelSize: Math.round(11 * root.sf); font.weight: activeTab === "installed" ? Font.DemiBold : Font.Normal; color: activeTab === "installed" ? "#93c5fd" : "#94a3b8" }
                    MouseArea { id: instTabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = "installed" }
                }
                Rectangle {
                    width: storeLbl.width + Math.round(20 * root.sf); height: Math.round(30 * root.sf)
                    radius: Math.round(6 * root.sf)
                    color: activeTab === "store" ? "#1e3a5f" : storeTabMa.containsMouse ? "#1e1e30" : "transparent"
                    border.color: activeTab === "store" ? "#3b82f6" : "transparent"; border.width: 1
                    Text { id: storeLbl; anchors.centerIn: parent; text: "Package Store"; font.pixelSize: Math.round(11 * root.sf); font.weight: activeTab === "store" ? Font.DemiBold : Font.Normal; color: activeTab === "store" ? "#93c5fd" : "#94a3b8" }
                    MouseArea { id: storeTabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = "store" }
                }
                Item { width: Math.round(8 * root.sf); height: 1 }
                Rectangle {
                    visible: totalAvailable > 0; width: countLbl.width + Math.round(12 * root.sf); height: Math.round(20 * root.sf); radius: Math.round(10 * root.sf); color: "#1a1a2a"; anchors.verticalCenter: parent.verticalCenter
                    Text { id: countLbl; anchors.centerIn: parent; text: totalAvailable.toLocaleString() + " pkgs"; font.pixelSize: Math.round(9 * root.sf); color: "#4a5568" }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#2a2a3a" }
        }

        // ── Install progress bar ──
        Rectangle {
            visible: busyPkgs.length > 0
            width: parent.width; height: Math.round(28 * root.sf); color: "#111122"

            Row {
                anchors.fill: parent; anchors.leftMargin: Math.round(14 * root.sf); spacing: Math.round(8 * root.sf)
                anchors.verticalCenter: parent.verticalCenter

                // Animated spinner
                Rectangle {
                    width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); radius: width/2
                    color: "transparent"; border.color: "#3b82f6"; border.width: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: Math.round(6 * root.sf); height: Math.round(6 * root.sf); radius: width/2
                        color: "#3b82f6"; x: Math.round(4 * root.sf); y: 0
                    }
                    RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: busyPkgs.length > 0 }
                }

                Text {
                    text: busyPkgStatus || ("Working on " + (busyPkgs.length > 0 ? busyPkgs[0] : "") + "...")
                    font.pixelSize: Math.round(10 * root.sf); color: "#f59e0b"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Progress bar animation
            Rectangle {
                anchors.bottom: parent.bottom; height: 2; color: "#3b82f6"; radius: 1
                width: parent.width * progressAnim.value
                NumberAnimation on width { id: progressAnim; property: "value"; from: 0; to: 1; duration: 8000; loops: Animation.Infinite; running: busyPkgs.length > 0
                    // Workaround: use x-position based animation
                }
            }
            Rectangle {
                id: progressBar
                anchors.bottom: parent.bottom; height: 2; color: "#3b82f6"; radius: 1
                SequentialAnimation on width {
                    running: busyPkgs.length > 0; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: nativeAppsLauncher.width; duration: 3000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: nativeAppsLauncher.width; to: 0; duration: 3000; easing.type: Easing.InOutQuad }
                }
            }
        }

        // ═══════ INSTALLED TAB ═══════
        Flickable {
            visible: activeTab === "installed"
            width: parent.width; height: parent.height - Math.round(42 * root.sf) - (busyPkgs.length > 0 ? Math.round(28 * root.sf) : 0)
            contentHeight: installedGrid.height + Math.round(40 * root.sf); clip: true

            GridLayout {
                id: installedGrid
                x: Math.round(20 * root.sf); y: Math.round(16 * root.sf)
                width: parent.width - Math.round(40 * root.sf)
                columns: Math.max(1, Math.floor(width / Math.round(150 * root.sf)))
                columnSpacing: Math.round(12 * root.sf)
                rowSpacing: Math.round(12 * root.sf)

                Repeater {
                    model: getAllInstalledApps()
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.minimumWidth: Math.round(130 * root.sf)
                        height: Math.round(130 * root.sf); radius: Math.round(10 * root.sf)
                        color: iMa.containsMouse ? "#2a2a3e" : "#222236"
                        border.color: iMa.containsMouse ? modelData.accent : "#2e2e44"; border.width: 1

                        // Main click area — z:0 (bottom)
                        MouseArea {
                            id: iMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 0
                            onClicked: {
                                if (modelData.cmd && modelData.cmd.length > 0) {
                                    nativeAppsLauncher.launchNativeViaHelper(modelData.cmd, modelData.label);
                                } else {
                                    root.openAppWindow(modelData.appId, modelData.label, modelData.iconType || "generic", modelData.searchName || modelData.pkg, modelData.cmd);
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
                            width: parent.width - Math.round(16 * root.sf); z: 1

                            Rectangle {
                                width: Math.round(42 * root.sf); height: Math.round(42 * root.sf)
                                radius: Math.round(10 * root.sf); anchors.horizontalCenter: parent.horizontalCenter
                                color: "#181828"; border.color: modelData.accent; border.width: 1
                                Canvas {
                                    anchors.fill: parent; anchors.margins: Math.round(6 * root.sf)
                                    property string t: modelData.iconType; property string a: modelData.accent; property string lbl: modelData.label
                                    Component.onCompleted: requestPaint()
                                    onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); var sc = width/22; ctx.scale(sc,sc); nativeAppsLauncher.drawIcon(ctx,t,a,lbl); ctx.restore(); }
                                }
                            }

                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#e2e8f0"; elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.desc; font.pixelSize: Math.round(9 * root.sf); color: "#64748b"; elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter }

                            // Uninstall button (only for user-installed, not built-in)
                            Rectangle {
                                visible: !modelData.builtIn && iMa.containsMouse
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(70 * root.sf); height: Math.round(20 * root.sf); radius: Math.round(4 * root.sf)
                                color: unMa.containsMouse ? "#3b1111" : "#1e1e30"
                                border.color: "#ef4444"; border.width: 1; z: 10
                                Text { anchors.centerIn: parent; text: "Uninstall"; font.pixelSize: Math.round(9 * root.sf); color: "#ef4444"; font.weight: Font.DemiBold }
                                MouseArea {
                                    id: unMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { removePkg(modelData.pkg); }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════ STORE TAB ═══════
        Item {
            visible: activeTab === "store"
            width: parent.width; height: parent.height - Math.round(42 * root.sf) - (busyPkgs.length > 0 ? Math.round(28 * root.sf) : 0)

            Column {
                anchors.fill: parent; spacing: 0

                Rectangle {
                    width: parent.width; height: Math.round(48 * root.sf); color: "#15151f"
                    Row {
                        anchors.fill: parent; anchors.margins: Math.round(10 * root.sf); spacing: Math.round(8 * root.sf)
                        Rectangle {
                            width: parent.width - srcBadge2.width - Math.round(8 * root.sf); height: Math.round(30 * root.sf)
                            radius: Math.round(6 * root.sf); color: "#222236"; border.color: searchInput.activeFocus ? "#3b82f6" : "#333348"; border.width: 1
                            TextInput {
                                id: searchInput; anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                                font.pixelSize: Math.round(11 * root.sf); color: "#e2e8f0"; clip: true
                                onTextChanged: { searchQuery = text; searchDebounce.restart(); }
                                Keys.onReturnPressed: searchStore(text)
                            }
                            Text {
                                visible: searchInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf)
                                text: "Search " + (totalAvailable > 0 ? totalAvailable.toLocaleString() + " " : "") + "Debian packages..."
                                font.pixelSize: Math.round(11 * root.sf); color: "#4a5568"
                            }
                        }
                        Rectangle {
                            id: srcBadge2; width: Math.round(110 * root.sf); height: Math.round(30 * root.sf)
                            radius: Math.round(6 * root.sf); color: "#1a2744"; border.color: "#2a4070"; border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: "Debian Bookworm"; font.pixelSize: Math.round(9 * root.sf); font.weight: Font.DemiBold; color: "#93c5fd" }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#2a2a3a" }
                }

                Flickable {
                    width: parent.width; height: parent.height - Math.round(48 * root.sf)
                    contentHeight: resultsCol.height + Math.round(20 * root.sf); clip: true

                    Column {
                        id: resultsCol; width: parent.width
                        leftPadding: Math.round(14 * root.sf); rightPadding: Math.round(14 * root.sf)
                        topPadding: Math.round(10 * root.sf); spacing: Math.round(6 * root.sf)

                        Text { visible: storeLoading; text: "Searching Debian repositories..."; font.pixelSize: Math.round(12 * root.sf); color: "#94a3b8"; topPadding: Math.round(20 * root.sf) }

                        Text {
                            visible: !storeLoading && searchQuery.length >= 2 && storeResults.length > 0
                            text: storeResults.length + " results for \"" + searchQuery + "\""
                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#94a3b8"
                            bottomPadding: Math.round(4 * root.sf)
                        }

                        Text {
                            visible: !storeLoading && searchQuery.length >= 2 && storeResults.length === 0
                            text: "No packages found for \"" + searchQuery + "\""
                            font.pixelSize: Math.round(12 * root.sf); color: "#64748b"; topPadding: Math.round(30 * root.sf)
                        }

                        // Search results — expanded cards with description
                        Repeater {
                            model: searchQuery.length >= 2 ? storeResults : []
                            delegate: Rectangle {
                                width: resultsCol.width - Math.round(28 * root.sf)
                                height: Math.round(64 * root.sf); radius: Math.round(8 * root.sf)
                                color: srMa.containsMouse ? "#262640" : "#1e1e30"
                                border.color: srMa.containsMouse ? accentFor(modelData.pkg) : "#2a2a3a"; border.width: 1

                                MouseArea { id: srMa; anchors.fill: parent; hoverEnabled: true }

                                Row {
                                    anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); spacing: Math.round(10 * root.sf)

                                    Rectangle {
                                        width: Math.round(44 * root.sf); height: Math.round(44 * root.sf)
                                        radius: Math.round(10 * root.sf); color: "#181828"
                                        border.color: accentFor(modelData.pkg); border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { anchors.centerIn: parent; text: modelData.pkg.charAt(0).toUpperCase(); font.pixelSize: Math.round(18 * root.sf); font.weight: Font.Bold; color: accentFor(modelData.pkg) }
                                    }

                                    Column {
                                        width: parent.width - Math.round(150 * root.sf); spacing: Math.round(2 * root.sf)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: modelData.pkg; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#e2e8f0"; elide: Text.ElideRight; width: parent.width }
                                        Text { text: modelData.desc; font.pixelSize: Math.round(9 * root.sf); color: "#94a3b8"; elide: Text.ElideRight; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                                    }

                                    Rectangle {
                                        width: Math.round(82 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(6 * root.sf)
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: isPkgBusy(modelData.pkg) ? "#1a1a2a" : isPkgInstalled(modelData.pkg) ? (ibMa.containsMouse ? "#3b1111" : "#112211") : (ibMa.containsMouse ? "#1e3a5f" : "#192844")
                                        border.color: isPkgBusy(modelData.pkg) ? "#f59e0b" : isPkgInstalled(modelData.pkg) ? (ibMa.containsMouse ? "#ef4444" : "#22c55e") : "#3b82f6"; border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: isPkgBusy(modelData.pkg) ? "Installing..." : isPkgInstalled(modelData.pkg) ? (ibMa.containsMouse ? "Remove" : "Installed") : "Install"
                                            font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold
                                            color: isPkgBusy(modelData.pkg) ? "#f59e0b" : isPkgInstalled(modelData.pkg) ? (ibMa.containsMouse ? "#ef4444" : "#22c55e") : "#93c5fd"
                                        }
                                        MouseArea {
                                            id: ibMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (isPkgBusy(modelData.pkg)) return;
                                                if (isPkgInstalled(modelData.pkg)) removePkg(modelData.pkg);
                                                else installPkg(modelData.pkg, modelData.desc);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ═══ Browse / Featured ═══
                        Column {
                            visible: searchQuery.length < 2 && !storeLoading
                            width: parent.width - Math.round(28 * root.sf)
                            spacing: Math.round(10 * root.sf)

                            Rectangle {
                                width: parent.width; height: Math.round(70 * root.sf); radius: Math.round(10 * root.sf)
                                color: "#1a2744"; border.color: "#2a4070"; border.width: 1
                                Column {
                                    anchors.centerIn: parent; spacing: Math.round(3 * root.sf)
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Debian Package Store"; font.pixelSize: Math.round(15 * root.sf); font.weight: Font.Bold; color: "#e2e8f0" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: (totalAvailable > 0 ? totalAvailable.toLocaleString() + " packages" : "Packages") + " from official Debian repos"; font.pixelSize: Math.round(10 * root.sf); color: "#94a3b8" }
                                }
                            }

                            Text { text: "QUICK SEARCH"; font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: "#4a5568"; topPadding: Math.round(4 * root.sf) }
                            Flow {
                                width: parent.width; spacing: Math.round(5 * root.sf)
                                Repeater {
                                    model: ["browser", "editor", "image editor", "video player", "music", "office", "game", "terminal", "file manager", "email", "chat", "pdf", "screenshot", "disk", "archive", "network"]
                                    delegate: Rectangle {
                                        width: cLbl.width + Math.round(14 * root.sf); height: Math.round(24 * root.sf)
                                        radius: Math.round(12 * root.sf); color: cMa.containsMouse ? "#1e3a5f" : "#1e1e30"
                                        border.color: cMa.containsMouse ? "#3b82f6" : "#333348"; border.width: 1
                                        Text { id: cLbl; anchors.centerIn: parent; text: modelData; font.pixelSize: Math.round(10 * root.sf); color: cMa.containsMouse ? "#93c5fd" : "#94a3b8" }
                                        MouseArea { id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { searchInput.text = modelData; searchQuery = modelData; searchStore(modelData); }
                                        }
                                    }
                                }
                            }

                            Text { visible: featuredApps.length > 0; text: "POPULAR PACKAGES"; font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: "#4a5568"; topPadding: Math.round(6 * root.sf) }
                            Repeater {
                                model: featuredApps
                                delegate: Rectangle {
                                    width: parent.width; height: Math.round(56 * root.sf); radius: Math.round(8 * root.sf)
                                    color: fMa.containsMouse ? "#262640" : "#1e1e30"
                                    border.color: fMa.containsMouse ? accentFor(modelData.pkg) : "#2a2a3a"; border.width: 1
                                    MouseArea { id: fMa; anchors.fill: parent; hoverEnabled: true }
                                    Row {
                                        anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); spacing: Math.round(10 * root.sf)
                                        Rectangle {
                                            width: Math.round(36 * root.sf); height: Math.round(36 * root.sf)
                                            radius: Math.round(10 * root.sf); color: "#181828"
                                            border.color: accentFor(modelData.pkg); border.width: 1; anchors.verticalCenter: parent.verticalCenter
                                            Text { anchors.centerIn: parent; text: modelData.pkg.charAt(0).toUpperCase(); font.pixelSize: Math.round(15 * root.sf); font.weight: Font.Bold; color: accentFor(modelData.pkg) }
                                        }
                                        Column {
                                            width: parent.width - Math.round(140 * root.sf); spacing: Math.round(2 * root.sf); anchors.verticalCenter: parent.verticalCenter
                                            Text { text: modelData.pkg; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#e2e8f0"; elide: Text.ElideRight; width: parent.width }
                                            Text { text: modelData.desc; font.pixelSize: Math.round(9 * root.sf); color: "#94a3b8"; elide: Text.ElideRight; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                                        }
                                        Rectangle {
                                            width: Math.round(76 * root.sf); height: Math.round(26 * root.sf); radius: Math.round(6 * root.sf)
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: isPkgBusy(modelData.pkg) ? "#1a1a2a" : isPkgInstalled(modelData.pkg) ? "#112211" : (fBtnMa.containsMouse ? "#1e3a5f" : "#192844")
                                            border.color: isPkgBusy(modelData.pkg) ? "#f59e0b" : isPkgInstalled(modelData.pkg) ? "#22c55e" : "#3b82f6"; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: isPkgBusy(modelData.pkg) ? "Installing..." : isPkgInstalled(modelData.pkg) ? "Installed" : "Install"
                                                font.pixelSize: Math.round(9 * root.sf); font.weight: Font.DemiBold
                                                color: isPkgBusy(modelData.pkg) ? "#f59e0b" : isPkgInstalled(modelData.pkg) ? "#22c55e" : "#93c5fd"
                                            }
                                            MouseArea {
                                                id: fBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (isPkgBusy(modelData.pkg)) return;
                                                    if (isPkgInstalled(modelData.pkg)) removePkg(modelData.pkg);
                                                    else installPkg(modelData.pkg, modelData.desc);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function drawIcon(ctx, iconType, accent, label) {
        ctx.fillStyle = accent; ctx.strokeStyle = accent;
        ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round";
        if (iconType === "chromium") {
            // Chromium icon — circle with colored segments
            var cx=11,cy=11,r=9;
            ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.fillStyle="#4285f4";ctx.fill();
            ctx.beginPath();ctx.moveTo(cx,cy);ctx.arc(cx,cy,r,-Math.PI*0.5,Math.PI/6);ctx.fillStyle="#ea4335";ctx.fill();
            ctx.beginPath();ctx.moveTo(cx,cy);ctx.arc(cx,cy,r,Math.PI/6,Math.PI*5/6);ctx.fillStyle="#fbbc05";ctx.fill();
            ctx.beginPath();ctx.moveTo(cx,cy);ctx.arc(cx,cy,r,Math.PI*5/6,Math.PI*3/2);ctx.fillStyle="#34a853";ctx.fill();
            ctx.beginPath();ctx.arc(cx,cy,4.5,0,Math.PI*2);ctx.fillStyle="#fff";ctx.fill();
            ctx.beginPath();ctx.arc(cx,cy,3,0,Math.PI*2);ctx.fillStyle="#4285f4";ctx.fill();
        } else if (iconType === "firefox") {
            // Firefox icon — globe with flame
            var cx=11,cy=11,r=9;
            // Globe base (blue)
            ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.fillStyle="#1a0a3e";ctx.fill();
            // Flame wrap (orange arc)
            ctx.beginPath();ctx.arc(cx,cy,r,-Math.PI*0.8,Math.PI*0.9);ctx.lineWidth=3.5;ctx.strokeStyle="#ff6611";ctx.stroke();
            // Flame tail (orange-yellow)
            ctx.beginPath();ctx.moveTo(17,5);ctx.quadraticCurveTo(19,9,16,14);ctx.quadraticCurveTo(13,18,8,17);ctx.lineWidth=2.5;ctx.strokeStyle="#ff9500";ctx.stroke();
            // Inner glow
            ctx.beginPath();ctx.arc(cx,cy,4.5,0,Math.PI*2);ctx.fillStyle="#3a1578";ctx.fill();
            ctx.beginPath();ctx.arc(cx,cy,3,0,Math.PI*2);ctx.fillStyle="#5b2d9e";ctx.fill();
        } else if (iconType === "editor") {
            ctx.fillStyle="#1e293b";ctx.fillRect(4,2,14,18);ctx.strokeStyle=accent;ctx.lineWidth=1;ctx.strokeRect(4,2,14,18);
            ctx.fillStyle=accent;ctx.fillRect(7,6,8,1);ctx.fillRect(7,9,6,1);ctx.fillRect(7,12,9,1);ctx.fillRect(7,15,5,1);
        } else if (iconType === "calculator") {
            ctx.fillStyle="#1e1b4b";ctx.fillRect(4,2,14,18);ctx.strokeStyle=accent;ctx.lineWidth=1;ctx.strokeRect(4,2,14,18);
            ctx.fillStyle="#312e81";ctx.fillRect(6,4,10,4);ctx.fillStyle=accent;
            for(var rr=0;rr<3;rr++) for(var cc=0;cc<3;cc++) ctx.fillRect(6+cc*4,10+rr*3,3,2);
        } else if (iconType === "office-writer") {
            ctx.fillStyle="#1e3a8a";ctx.fillRect(3,1,16,20);ctx.strokeStyle="#2563eb";ctx.lineWidth=1;ctx.strokeRect(3,1,16,20);
            ctx.fillStyle="#93c5fd";ctx.fillRect(6,5,10,1);ctx.fillRect(6,8,8,1);ctx.fillRect(6,11,10,1);ctx.fillRect(6,14,6,1);ctx.fillRect(6,17,9,1);
        } else if (iconType === "office-calc") {
            ctx.fillStyle="#14532d";ctx.fillRect(3,1,16,20);ctx.strokeStyle="#16a34a";ctx.lineWidth=1;ctx.strokeRect(3,1,16,20);
            ctx.strokeStyle="#4ade80";ctx.lineWidth=0.5;
            for(var gi=0;gi<4;gi++){ctx.beginPath();ctx.moveTo(3,5+gi*4);ctx.lineTo(19,5+gi*4);ctx.stroke();}
            for(var gj=0;gj<3;gj++){ctx.beginPath();ctx.moveTo(8+gj*4,1);ctx.lineTo(8+gj*4,21);ctx.stroke();}
        } else if (iconType === "office-impress") {
            ctx.fillStyle="#7f1d1d";ctx.fillRect(3,1,16,20);ctx.strokeStyle="#dc2626";ctx.lineWidth=1;ctx.strokeRect(3,1,16,20);
            ctx.fillStyle="#991b1b";ctx.fillRect(5,4,12,8);
            ctx.fillStyle="#fca5a5";ctx.beginPath();ctx.moveTo(8,7);ctx.lineTo(14,8);ctx.lineTo(8,11);ctx.closePath();ctx.fill();
            ctx.fillStyle="#fca5a5";ctx.fillRect(5,15,3,2);ctx.fillRect(9,15,3,2);ctx.fillRect(13,15,3,2);
        } else if (iconType === "pdf") {
            ctx.fillStyle="#7f1d1d";ctx.fillRect(3,1,16,20);ctx.strokeStyle="#ef4444";ctx.lineWidth=1;ctx.strokeRect(3,1,16,20);
            ctx.fillStyle="#fca5a5";ctx.font="bold 7px sans-serif";ctx.textAlign="center";ctx.fillText("PDF",11,13);
        } else {
            ctx.fillStyle="#1a1a2e";ctx.fillRect(3,1,16,20);ctx.strokeStyle=accent;ctx.lineWidth=1;ctx.strokeRect(3,1,16,20);
            ctx.fillStyle=accent;ctx.font="bold 9px sans-serif";ctx.textAlign="center";
            var ch = (label && label.length > 0) ? label.charAt(0).toUpperCase() : "?";
            ctx.fillText(ch, 11, 14);
        }
    }
}
