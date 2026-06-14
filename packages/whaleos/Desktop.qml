import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "api.js" as API

Rectangle {
    id: desktop
    anchors.fill: parent
    color: "#030712"

    // ── Open Files App ──
    function openFilesApp() {
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].appId === "files") return;
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: "files", title: "Works", icon: "files" });
        root.openWindows = wins;
    }

    function focusWindow(appId) {
        for (var i = 0; i < windowRepeater.count; i++) {
            var win = windowRepeater.itemAt(i);
            if (win && win.appId === appId) {
                root.bringToFront(win);
                win.focusNativeSurface();
                break;
            }
        }
    }

    // ── Wallpaper State ──
    property string currentWallpaper: "warm-desert"
    property bool wpExpanded: false
    property bool displayExpanded: false
    property var wallpaperList: [
        { id: "default",        name: "Default Aurora",    file: "" },
        { id: "warm-desert",    name: "☀ Warm Desert",     file: "assets/wallpapers/warm-desert.png" },
        { id: "nebula",         name: "★ Nebula",          file: "assets/wallpapers/nebula.png" },
        { id: "cyber-grid",     name: "◈ Cyber Grid",      file: "assets/wallpapers/cyber-grid.png" },
        { id: "aurora",         name: "◌ Aurora",          file: "assets/wallpapers/aurora.png" },
        { id: "ocean-depth",    name: "≋ Ocean Depth",     file: "assets/wallpapers/ocean-depth.png" },
        { id: "abstract-waves", name: "∿ Abstract Waves",  file: "assets/wallpapers/abstract-waves.png" },
        { id: "crystal",        name: "◆ Crystal",         file: "assets/wallpapers/crystal.png" },
        { id: "ocean",          name: "≈ Ocean",           file: "assets/wallpapers/ocean.png" },
        { id: "topology",       name: "⬡ Topology",        file: "assets/wallpapers/topology.png" },
        { id: "abstract",       name: "✦ Abstract",        file: "assets/wallpapers/abstract.png" },
        { id: "alien",          name: "⊕ Alien",           file: "assets/wallpapers/alien.png" },
        { id: "cosmic",         name: "⬢ Cosmic",          file: "assets/wallpapers/cosmic.png" },
        { id: "cyberpunk",      name: "⚡ Cyberpunk",      file: "assets/wallpapers/cyberpunk.png" }
    ]

    // ── Wallpaper Image (shown when not "default") ──
    Image {
        id: wallpaperImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: currentWallpaper !== "default"
        source: {
            for (var i = 0; i < wallpaperList.length; i++) {
                if (wallpaperList[i].id === currentWallpaper && wallpaperList[i].file !== "") {
                    return wallpaperList[i].file;
                }
            }
            return "";
        }

        // Very subtle overlay to keep UI readable
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.08)
        }
    }

    // ── Default Gradient Wallpaper (shown when "default") ──
    Item {
        anchors.fill: parent
        visible: currentWallpaper === "default"

        // Base warm gradient
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#e8d5c4" }
                GradientStop { position: 0.15; color: "#dcc4b0" }
                GradientStop { position: 0.4; color: "#c9a88a" }
                GradientStop { position: 0.7; color: "#b89878" }
                GradientStop { position: 1.0; color: "#a08060" }
            }
        }

        // Large cyan aurora — top-left sweep
        Rectangle {
            x: -parent.width * 0.15
            y: -parent.height * 0.05
            width: parent.width * 0.8
            height: parent.height * 0.6
            radius: width / 2
            opacity: 0.28
            rotation: -12
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#38bdf8" }
                GradientStop { position: 0.35; color: "#0ea5e9" }
                GradientStop { position: 0.7; color: "#0284c7" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Deep purple nebula — center
        Rectangle {
            x: parent.width * 0.15
            y: parent.height * 0.05
            width: parent.width * 0.7
            height: parent.height * 0.6
            radius: width / 2
            opacity: 0.24
            rotation: 8
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#a78bfa" }
                GradientStop { position: 0.4; color: "#7c3aed" }
                GradientStop { position: 0.8; color: "#6d28d9" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Electric blue ribbon — right side
        Rectangle {
            x: parent.width * 0.35
            y: parent.height * 0.1
            width: parent.width * 0.6
            height: parent.height * 0.5
            radius: width / 2
            opacity: 0.20
            rotation: 18
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0ea5e9" }
                GradientStop { position: 0.5; color: "#2563eb" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Rose/magenta accent — bottom right
        Rectangle {
            x: parent.width * 0.45
            y: parent.height * 0.5
            width: parent.width * 0.55
            height: parent.height * 0.45
            radius: width / 2
            opacity: 0.16
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f472b6" }
                GradientStop { position: 0.5; color: "#ec4899" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Teal secondary glow — bottom left
        Rectangle {
            x: -parent.width * 0.05
            y: parent.height * 0.55
            width: parent.width * 0.5
            height: parent.height * 0.4
            radius: width / 2
            opacity: 0.12
            rotation: -8
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2dd4bf" }
                GradientStop { position: 0.6; color: "#14b8a6" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Star field Canvas
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var seed = 42;
                function pseudoRandom() {
                    seed = (seed * 16807 + 0) % 2147483647;
                    return seed / 2147483647;
                }

                // More stars, varied sizes for depth
                for (var i = 0; i < 120; i++) {
                    var sx = pseudoRandom() * width;
                    var sy = pseudoRandom() * height;
                    var sr = pseudoRandom() * 1.5 + 0.2;
                    var so = pseudoRandom() * 0.5 + 0.1;
                    ctx.beginPath();
                    ctx.fillStyle = "rgba(255, 255, 255, " + so + ")";
                    ctx.arc(sx, sy, sr, 0, Math.PI * 2);
                    ctx.fill();
                }

                // A few brighter accent stars
                for (var j = 0; j < 8; j++) {
                    var bx = pseudoRandom() * width;
                    var by = pseudoRandom() * height;
                    ctx.beginPath();
                    ctx.fillStyle = "rgba(56, 189, 248, 0.3)";
                    ctx.arc(bx, by, 2, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
    }

    // ── Right-Click Desktop Context Menu ──
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: 1
        onClicked: function(mouse) {
            contextMenu.x = mouse.x;
            contextMenu.y = mouse.y;
            contextMenu.visible = !contextMenu.visible;
        }
    }

    // ── Click-Outside Dismiss Overlay (only visible when context menu is open) ──
    MouseArea {
        anchors.fill: parent
        visible: contextMenu.visible
        z: 499  // Below context menu (500) but above everything else
        onClicked: contextMenu.visible = false
    }

    // ── Context Menu ──
    Rectangle {
        id: contextMenu
        visible: false
        width: Math.round(220 * root.sf)
        height: menuCol.height + Math.round(16 * root.sf)
        radius: root.radiusMd
        color: root.bgElevated
        border.color: root.borderColor
        border.width: 1
        z: 500

        // Close when clicking elsewhere
        Connections {
            target: desktop
            function onWidthChanged() { contextMenu.visible = false; }
        }

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(8 * root.sf)
            spacing: 2

            // ── Copy ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: copyMa.containsMouse ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(s,s);
                            ctx.strokeStyle = "#8b9dc3"; ctx.lineWidth = 1.2;
                            ctx.strokeRect(1, 3, 8, 10); ctx.strokeRect(5, 1, 8, 10);
                            ctx.restore(); }
                        onSChanged: requestPaint()
                    }
                    Text { text: "Copy"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary }
                    Item { width: Math.round(40 * root.sf); height: 1 }
                    Text { text: "Ctrl+C"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                }
                MouseArea { id: copyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.showToast("Copied to clipboard", "success"); contextMenu.visible = false; } }
            }

            // ── Paste ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: pasteMa2.containsMouse ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(s,s);
                            ctx.strokeStyle = "#8b9dc3"; ctx.lineWidth = 1.2;
                            ctx.strokeRect(2, 4, 10, 10);
                            ctx.beginPath(); ctx.moveTo(4, 1); ctx.lineTo(10, 1); ctx.lineTo(10, 4); ctx.lineTo(4, 4); ctx.closePath(); ctx.stroke();
                            ctx.fillStyle = "#8b9dc3"; ctx.fillRect(5, 7, 6, 1); ctx.fillRect(5, 9, 4, 1); ctx.fillRect(5, 11, 5, 1);
                            ctx.restore(); }
                        onSChanged: requestPaint()
                    }
                    Text { text: "Paste"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary }
                    Item { width: Math.round(36 * root.sf); height: 1 }
                    Text { text: "Ctrl+V"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                }
                MouseArea { id: pasteMa2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { var clip = sysManager.pasteFromClipboard(); if (clip) root.showToast("Pasted: " + clip.substring(0, 30), "info"); contextMenu.visible = false; } }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── Open Works Folder ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: worksMa.containsMouse ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(s,s);
                            ctx.fillStyle = "#38bdf8";
                            ctx.beginPath(); ctx.moveTo(1,5); ctx.lineTo(6,5); ctx.lineTo(7,3); ctx.lineTo(1,3); ctx.closePath(); ctx.fill();
                            ctx.beginPath(); ctx.moveTo(1,5); ctx.lineTo(13,5); ctx.lineTo(13,13); ctx.lineTo(1,13); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = "#00b0ff";
                            ctx.beginPath(); ctx.moveTo(1,7); ctx.lineTo(13,7); ctx.lineTo(13,13); ctx.lineTo(1,13); ctx.closePath(); ctx.fill();
                            ctx.restore(); }
                        onSChanged: requestPaint()
                    }
                    Text { text: "Open Works"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary }
                }
                MouseArea { id: worksMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { desktop.openFilesApp(); contextMenu.visible = false; } }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // ── Wallpaper Section (expandable/collapsible) ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: wpHeaderMa.containsMouse ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)
                    Text { text: desktop.wpExpanded ? "▾" : "▸"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(s,s);
                            ctx.strokeStyle = "#a78bfa"; ctx.lineWidth = 1.2; ctx.strokeRect(1, 1, 12, 12);
                            ctx.fillStyle = "#a78bfa";
                            ctx.beginPath(); ctx.moveTo(3,10); ctx.lineTo(5,6); ctx.lineTo(7,8); ctx.lineTo(9,4); ctx.lineTo(11,10); ctx.closePath(); ctx.fill();
                            ctx.restore(); }
                        onSChanged: requestPaint()
                    }
                    Text { text: "Change Wallpaper"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: wpHeaderMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: desktop.wpExpanded = !desktop.wpExpanded }
            }

            // Wallpaper list (shown when expanded)
            Repeater {
                model: desktop.wpExpanded ? desktop.wallpaperList : []

                delegate: Rectangle {
                    width: parent.width
                    height: Math.round(36 * root.sf)
                    radius: root.radiusSm
                    color: wpItemMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.04) :
                           desktop.currentWallpaper === modelData.id ? Qt.rgba(0, 0, 0, 0.02) :
                           "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(10 * root.sf)
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(10 * root.sf)
                        spacing: Math.round(10 * root.sf)

                        // Thumbnail preview
                        Rectangle {
                            width: Math.round(26 * root.sf); height: Math.round(26 * root.sf)
                            radius: Math.round(4 * root.sf)
                            color: modelData.file === "" ? "#0f1628" : "transparent"
                            border.color: desktop.currentWallpaper === modelData.id ? root.accentBlue : root.borderColor
                            border.width: desktop.currentWallpaper === modelData.id ? 1.5 : 1
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter

                            // Default gradient thumbnail
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Math.round(3 * root.sf)
                                visible: modelData.file === ""
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "#0c0a1a" }
                                    GradientStop { position: 0.4; color: "#0f1628" }
                                    GradientStop { position: 1.0; color: "#101830" }
                                }
                                Rectangle {
                                    width: parent.width * 0.7; height: parent.height * 0.5
                                    x: parent.width * 0.1; y: parent.height * 0.15
                                    radius: width / 2; opacity: 0.4
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#0ea5e9" }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: modelData.file !== "" ? modelData.file : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: modelData.file !== ""
                                asynchronous: true
                                sourceSize.width: Math.round(52 * root.sf)
                                sourceSize.height: Math.round(52 * root.sf)
                            }
                        }

                        Text {
                            text: modelData.name
                            font.pixelSize: Math.round(13 * root.sf)
                            color: desktop.currentWallpaper === modelData.id ? root.accentBlue : root.textPrimary
                            font.weight: desktop.currentWallpaper === modelData.id ? Font.Medium : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: 1; height: 1; Layout.fillWidth: true }

                        // Active indicator dot
                        Rectangle {
                            width: Math.round(6 * root.sf); height: Math.round(6 * root.sf)
                            radius: Math.round(3 * root.sf)
                            color: root.accentBlue
                            visible: desktop.currentWallpaper === modelData.id
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: wpItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            desktop.currentWallpaper = modelData.id;
                            contextMenu.visible = false;
                            // Persist wallpaper choice
                            API.saveOsConfig({ wallpaper: modelData.id }, function(s, d) {});
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: root.borderColor
            }

            // ── Display Settings Section (expandable) ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: dispHeaderMa.containsMouse ? Qt.rgba(0.22, 0.74, 0.97, 0.08) : "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)
                    Text { text: desktop.displayExpanded ? "▾" : "▸"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(s,s);
                            ctx.strokeStyle = root.accentBlue; ctx.lineWidth = 1.2;
                            ctx.strokeRect(1, 2, 12, 8);
                            ctx.beginPath(); ctx.moveTo(4, 10); ctx.lineTo(10, 10); ctx.lineTo(10, 12); ctx.lineTo(4, 12); ctx.closePath(); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(3, 12); ctx.lineTo(11, 12); ctx.stroke();
                            ctx.restore(); }
                        onSChanged: requestPaint()
                    }
                    Text { text: "Display Settings"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: dispHeaderMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: desktop.displayExpanded = !desktop.displayExpanded }
            }

            // Display options (shown when expanded)
            Column {
                width: parent.width; spacing: 1; visible: desktop.displayExpanded

                // Resolution label
                Text { text: "Resolution"; font.pixelSize: Math.round(9 * root.sf); color: root.textMuted; leftPadding: Math.round(30 * root.sf); topPadding: Math.round(4 * root.sf) }

                // Resolution options
                Repeater {
                    model: [
                        { label: "1920 × 1080", res: "1920x1080", tag: "Full HD" },
                        { label: "1680 × 1050", res: "1680x1050", tag: "WSXGA+" },
                        { label: "1600 × 900",  res: "1600x900",  tag: "HD+" },
                        { label: "1440 × 900",  res: "1440x900",  tag: "WXGA+" },
                        { label: "1366 × 768",  res: "1366x768",  tag: "WXGA" },
                        { label: "1280 × 720",  res: "1280x720",  tag: "HD" },
                        { label: "1024 × 768",  res: "1024x768",  tag: "XGA" }
                    ]

                    delegate: Rectangle {
                        width: parent.width; height: Math.round(26 * root.sf); radius: root.radiusSm
                        color: resCtxMa.containsMouse ? Qt.rgba(0.22, 0.74, 0.97, 0.08) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Math.round(30 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)
                            Text { text: "●"; font.pixelSize: Math.round(8 * root.sf); color: root.accentBlue; visible: false /* TODO: check current */ }
                            Text { text: modelData.label; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                            Item { width: Math.round(4 * root.sf); height: 1 }
                            Text { text: modelData.tag; font.pixelSize: Math.round(8 * root.sf); color: root.textMuted }
                        }
                        MouseArea {
                            id: resCtxMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var parts = modelData.res.split("x");
                                var w = parseInt(parts[0]); var h = parseInt(parts[1]);
                                var ok = sysManager.setDisplayResolution(w, h);
                                if (ok) {
                                    root.showToast("Resolution set to " + modelData.label, "success");
                                } else {
                                    // Mode doesn't exist — add it via cvt + xrandr --newmode/--addmode
                                    var modeName = w + "x" + h + "_60.00";
                                    try {
                                        var runFn = (typeof sysManager.runCommandQuick === "function") ? "runCommandQuick" : "runCommand";
                                        var cvtResult = JSON.parse(sysManager[runFn](
                                            "cvt " + w + " " + h + " 60 2>/dev/null | grep Modeline | sed 's/Modeline //'", "/"
                                        ));
                                        var modeline = (cvtResult.stdout || "").trim();
                                        if (modeline) {
                                            var outputName = sysManager.getActiveOutputName();
                                            sysManager[runFn](
                                                "xrandr --newmode " + modeline + " 2>/dev/null; " +
                                                "xrandr --addmode " + outputName + " '" + modeName + "' 2>/dev/null; " +
                                                "xrandr --output " + outputName + " --mode '" + modeName + "' 2>/dev/null", "/"
                                            );
                                            root.showToast("Resolution set to " + modelData.label + " (mode added)", "success");
                                        } else {
                                            root.showToast("Cannot change resolution (mode not supported)", "error");
                                        }
                                    } catch(e) {
                                        root.showToast("Cannot change resolution (may need to add mode first)", "error");
                                    }
                                }
                                contextMenu.visible = false;
                            }
                        }
                    }
                }

                // Separator
                Rectangle { width: parent.width; height: 1; color: root.borderColor; visible: desktop.displayExpanded }

                // Scaling label
                Text { text: "UI Scaling"; font.pixelSize: Math.round(9 * root.sf); color: root.textMuted; leftPadding: Math.round(30 * root.sf); topPadding: Math.round(4 * root.sf) }

                // Scaling options
                Repeater {
                    model: [
                        { label: "Compact", scale: 0.75 },
                        { label: "Default", scale: 1.0 },
                        { label: "Comfortable", scale: 1.15 },
                        { label: "Large", scale: 1.35 },
                        { label: "Extra Large", scale: 1.6 }
                    ]

                    delegate: Rectangle {
                        width: parent.width; height: Math.round(26 * root.sf); radius: root.radiusSm
                        color: dscaleMa.containsMouse ? Qt.rgba(0.22, 0.74, 0.97, 0.08) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                            anchors.leftMargin: Math.round(30 * root.sf); spacing: Math.round(8 * root.sf)
                            Text { text: Math.abs(root.userScale - modelData.scale) < 0.01 ? "●" : "○"; font.pixelSize: Math.round(10 * root.sf); color: Math.abs(root.userScale - modelData.scale) < 0.01 ? root.accentBlue : root.textMuted }
                            Text { text: modelData.label; font.pixelSize: Math.round(11 * root.sf); color: Math.abs(root.userScale - modelData.scale) < 0.01 ? root.accentBlue : root.textSecondary; font.bold: Math.abs(root.userScale - modelData.scale) < 0.01 }
                        }
                        MouseArea {
                            id: dscaleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.userScale = modelData.scale;
                                root.showToast("Display: " + modelData.label, "success");
                                contextMenu.visible = false;
                            }
                        }
                    }
                }

                // Separator
                Rectangle { width: parent.width; height: 1; color: root.borderColor }

                // Open Display Settings (full)
                Rectangle {
                    width: parent.width; height: Math.round(28 * root.sf); radius: root.radiusSm
                    color: openDispMa.containsMouse ? Qt.rgba(0.22, 0.74, 0.97, 0.08) : "transparent"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                        anchors.leftMargin: Math.round(30 * root.sf); spacing: Math.round(6 * root.sf)
                        Text { text: "Open Display Settings..."; font.pixelSize: Math.round(11 * root.sf); color: root.accentBlue }
                    }
                    MouseArea {
                        id: openDispMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.settingsOpenTab = "display";
                            root.openAppWindow("settings", "Settings", "\uf013");
                            contextMenu.visible = false;
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: root.borderColor
            }

            // Close option
            Rectangle {
                width: parent.width
                height: Math.round(30 * root.sf)
                radius: root.radiusSm
                color: closeMenuMouse.containsMouse ? Qt.rgba(0.22, 0.74, 0.97, 0.08) : "transparent"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(10 * root.sf)
                    text: "✕  Close"
                    font.pixelSize: Math.round(12 * root.sf)
                    color: root.textSecondary
                }

                MouseArea {
                    id: closeMenuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: contextMenu.visible = false
                }
            }
        }
    }

    // ── Works Folder Desktop Icon (hidden when dashboard is showing) ──
    Rectangle {
        id: worksIcon
        x: Math.round(24 * root.sf); y: Math.round(60 * root.sf)
        width: Math.round(72 * root.sf); height: Math.round(78 * root.sf)
        radius: root.radiusMd; z: 10
        visible: root.openWindows.length > 0
        color: worksIconMa.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"

        Column {
            anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
            Canvas {
                width: Math.round(36 * root.sf); height: Math.round(36 * root.sf)
                anchors.horizontalCenter: parent.horizontalCenter
                property real s: root.sf
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                    ctx.save(); ctx.scale(s, s);
                    // Folder shape
                    ctx.fillStyle = "#38bdf8";
                    ctx.beginPath();
                    ctx.moveTo(2, 10); ctx.lineTo(2, 30); ctx.lineTo(34, 30);
                    ctx.lineTo(34, 12); ctx.lineTo(18, 12); ctx.lineTo(15, 8);
                    ctx.lineTo(2, 8); ctx.closePath(); ctx.fill();
                    // Folder tab
                    ctx.fillStyle = "#67f0ff";
                    ctx.beginPath();
                    ctx.moveTo(2, 8); ctx.lineTo(15, 8); ctx.lineTo(18, 12);
                    ctx.lineTo(2, 12); ctx.closePath(); ctx.fill();
                    // Folder front
                    ctx.fillStyle = "#00b0ff";
                    ctx.beginPath();
                    ctx.moveTo(2, 14); ctx.lineTo(34, 14); ctx.lineTo(34, 30);
                    ctx.lineTo(2, 30); ctx.closePath(); ctx.fill();
                    ctx.restore();
                }
                onSChanged: requestPaint()
            }
            Text {
                text: "Works"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium
                color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.6)
            }
        }

        MouseArea {
            id: worksIconMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onDoubleClicked: desktop.openFilesApp()
        }
    }

    // ── Dashboard Home Screen ──
    Item {
        id: dashboardHome
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: appDock.top
        anchors.topMargin: Math.round(12 * root.sf)
        anchors.leftMargin: Math.round(40 * root.sf)
        anchors.rightMargin: Math.round(40 * root.sf)
        anchors.bottomMargin: Math.round(12 * root.sf)
        visible: root.openWindows.length === 0
        z: 2

        // Dashboard data
        property var providersList: []
        property var agentsList: []
        property var activeRunsList: []
        property var toolsList: []
        property var skillsList: []
        property int totalTools: 0
        property int totalSkills: 0
        property int activeProviders: 0
        property int totalAgents: 0
        property bool dataLoaded: false
        property bool authSuccessful: false

        // Timer to periodically refresh dashboard data
        Timer {
            id: refreshTimer
            interval: 10000 // 10 seconds
            running: root.loggedIn
            repeat: true
            onTriggered: {
                console.log("Dashboard refresh timer triggered...");
                dashboardHome.loadDashboardData(true);
            }
        }

        function loadDashboardData(force) {
            if (dataLoaded && !force) return;

            // Check if we need to auto-authenticate
            if (root.sessionId === "system" || root.sessionId === "" || !authSuccessful) {
                console.log("No valid active dashboard session, attempting auto-login...");
                var loginUser = (root.currentUser && root.currentUser !== "") ? root.currentUser : "ainux";
                var loginPass = loginUser; // System convention: username is password
                
                API.login(loginUser, loginPass, function(status, data) {
                    if (status === 200 && data && data.ok && data.sessionId) {
                        console.log("Auto-login as " + loginUser + " succeeded. Session:", data.sessionId);
                        root.sessionId = data.sessionId;
                        API.setSession(data.sessionId);
                        authSuccessful = true;
                        fetchDashboardData();
                    } else {
                        // Fallback to admin/admin
                        console.log("Auto-login as " + loginUser + " failed. Trying admin/admin...");
                        API.login("admin", "admin", function(status2, data2) {
                            if (status2 === 200 && data2 && data2.ok && data2.sessionId) {
                                console.log("Auto-login as admin succeeded. Session:", data2.sessionId);
                                root.sessionId = data2.sessionId;
                                API.setSession(data2.sessionId);
                                authSuccessful = true;
                                fetchDashboardData();
                            } else {
                                console.warn("All auto-login attempts failed. Status:", status2);
                                // We will retry on the next timer tick
                            }
                        });
                    }
                });
            } else {
                fetchDashboardData();
            }
        }

        function fetchDashboardData() {
            API.getProviders(function(s, d) {
                if (s === 200 && d) {
                    var provs = d.providers || d || [];
                    var arr = [];
                    var active = 0;
                    for (var k in provs) {
                        if (provs.hasOwnProperty(k)) {
                            var p = provs[k];
                            var configured = (p && p.configured) || false;
                            arr.push({ name: k, configured: configured, model: (p && p.model) || "" });
                            if (configured) active++;
                        }
                    }
                    providersList = arr;
                    activeProviders = active;
                    dataLoaded = true;
                }
            });
            API.getTools(function(s, d) {
                if (s === 200 && d) {
                    var t = d.tools || d || [];
                    totalTools = (typeof t.length !== "undefined") ? t.length : 0;
                    toolsList = t;
                    dataLoaded = true;
                }
            });
            API.getSkills(function(s, d) {
                if (s === 200 && d) {
                    var sk = d.skills || d || [];
                    totalSkills = (typeof sk.length !== "undefined") ? sk.length : 0;
                    skillsList = sk;
                    dataLoaded = true;
                }
            });
            API.getAgents(function(s, d) {
                if (s === 200 && d) {
                    var ag = d.agents || d || [];
                    agentsList = ag;
                    totalAgents = (typeof ag.length !== "undefined") ? ag.length : 0;
                    dataLoaded = true;
                }
            });
            API.getActiveRuns(function(s, d) {
                if (s === 200 && d) {
                    var r = d.runs || d || [];
                    activeRunsList = r;
                }
            });
        }

        Component.onCompleted: {
            console.log("Desktop completed. loggedIn:", root.loggedIn, "openWindows length:", root.openWindows.length);
            if (root.loggedIn) loadDashboardData();
        }

        Connections {
            target: root
            function onLoggedInChanged() {
                if (root.loggedIn) dashboardHome.loadDashboardData();
            }
        }

        // Dashboard content — fits viewport
        Flickable {
            anchors.fill: parent
            contentHeight: dashCol.height + Math.round(20 * root.sf)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: dashCol
                width: parent.width
                spacing: Math.round(20 * root.sf)

                // ── Greeting ──
                Column {
                    width: parent.width
                    spacing: Math.round(4 * root.sf)
                    topPadding: Math.round(8 * root.sf)

                    Text {
                        text: {
                            var h = new Date().getHours();
                            var greeting = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
                            return "👋  " + greeting + ", " + (root.currentUser || "user");
                        }
                        font.pixelSize: Math.round(24 * root.sf)
                        font.weight: Font.Bold
                        color: root.textPrimary
                    }
                    Text {
                        text: "Your AI workspace is ready. What shall we build today?"
                        font.pixelSize: Math.round(13 * root.sf)
                        color: root.textSecondary
                    }
                }

                // ── Launchpad Cards ──
                Column {
                    width: parent.width
                    spacing: Math.round(10 * root.sf)

                    Text {
                        text: "Launchpad"
                        font.pixelSize: Math.round(14 * root.sf)
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }

                    Row {
                        width: parent.width
                        spacing: Math.round(12 * root.sf)

                        Repeater {
                            model: [
                                { title: "Create Agent",  sub: "Build a new AI agent\nfrom scratch", icon: "\uf544", accent: "#38bdf8", appId: "agents",   appTitle: "Agents",   appIcon: "agents" },
                                { title: "New Task",      sub: "Send a task to your\nAI agents",     icon: "\uf0ae", accent: "#34d399", appId: "",          appTitle: "",         appIcon: "" },
                                { title: "Browse Skills", sub: "Discover and install\nskills",        icon: "\uf0e7", accent: "#fb923c", appId: "skills",   appTitle: "Skills",   appIcon: "skills" },
                                { title: "Open Terminal", sub: "Command line\naccess",               icon: "\uf120", accent: "#a78bfa", appId: "terminal", appTitle: "Terminal", appIcon: "terminal" }
                            ]

                            delegate: Rectangle {
                                width: (dashCol.width - Math.round(36 * root.sf)) / 4
                                height: Math.round(130 * root.sf)
                                radius: root.radiusMd
                                color: lpMa.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.95)
                                    : Qt.rgba(1, 1, 1, 0.85)
                                border.color: lpMa.containsMouse
                                    ? Qt.rgba(0, 0, 0, 0.12)
                                    : Qt.rgba(0, 0, 0, 0.06)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                transform: Translate {
                                    y: lpMa.containsMouse ? Math.round(-3 * root.sf) : 0
                                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: Math.round(16 * root.sf)
                                    spacing: Math.round(10 * root.sf)

                                    // Icon circle
                                    Rectangle {
                                        width: Math.round(40 * root.sf); height: width
                                        radius: Math.round(10 * root.sf)
                                        color: Qt.rgba(Qt.color(modelData.accent).r, Qt.color(modelData.accent).g, Qt.color(modelData.accent).b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.family: root.iconFont
                                            font.weight: Font.Black
                                            font.pixelSize: Math.round(18 * root.sf)
                                            color: modelData.accent
                                        }
                                    }

                                    Text {
                                        text: modelData.title
                                        font.pixelSize: Math.round(13 * root.sf)
                                        font.weight: Font.DemiBold
                                        color: root.textPrimary
                                    }
                                    Text {
                                        text: modelData.sub
                                        font.pixelSize: Math.round(10 * root.sf)
                                        color: root.textSecondary
                                        lineHeight: 1.3
                                    }
                                }

                                // Arrow icon bottom-right
                                Text {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Math.round(14 * root.sf)
                                    text: "\u2192"
                                    font.pixelSize: Math.round(16 * root.sf)
                                    font.weight: Font.Bold
                                    color: lpMa.containsMouse ? modelData.accent : root.textSecondary
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                MouseArea {
                                    id: lpMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.appId === "") {
                                            // New Task → Open dialog to specify prompt and agent
                                            newTaskDialog.open();
                                        } else {
                                            root.openAppWindow(modelData.appId, modelData.appTitle, modelData.appIcon);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Active Agent Tasks Table (real API) ──
                Rectangle {
                    width: parent.width
                    height: agentsTableCol.height + Math.round(24 * root.sf)
                    radius: root.radiusMd
                    color: Qt.rgba(1, 1, 1, 0.85)
                    border.color: Qt.rgba(0, 0, 0, 0.06)
                    border.width: 1

                    Column {
                        id: agentsTableCol
                        width: parent.width - Math.round(24 * root.sf)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Math.round(12 * root.sf)
                        spacing: Math.round(2 * root.sf)

                        // Header
                        Row {
                            width: parent.width
                            spacing: 0
                            Text {
                                text: "Active Agent Tasks"
                                font.pixelSize: Math.round(14 * root.sf)
                                font.weight: Font.DemiBold
                                color: root.textPrimary
                                width: parent.width * 0.5
                            }
                            Text {
                                text: "View all tasks"
                                font.pixelSize: Math.round(11 * root.sf)
                                color: root.accentBlue
                                width: parent.width * 0.5
                                horizontalAlignment: Text.AlignRight
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openAppWindow("agents", "Agents", "agents")
                                }
                            }
                        }

                        Item { width: 1; height: Math.round(8 * root.sf) }

                        // Column headers
                        Rectangle {
                            width: parent.width
                            height: Math.round(32 * root.sf)
                            color: Qt.rgba(0, 0, 0, 0.03)
                            radius: root.radiusSm

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(12 * root.sf)
                                anchors.rightMargin: Math.round(12 * root.sf)
                                spacing: 0

                                Text { text: "Task / Prompt";    width: parent.width * 0.40; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary; verticalAlignment: Text.AlignVCenter; height: parent.height }
                                Text { text: "Agent";          width: parent.width * 0.20; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary; verticalAlignment: Text.AlignVCenter; height: parent.height }
                                Text { text: "Status";         width: parent.width * 0.15; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary; verticalAlignment: Text.AlignVCenter; height: parent.height }
                                Text { text: "Model";          width: parent.width * 0.25; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary; verticalAlignment: Text.AlignVCenter; height: parent.height; horizontalAlignment: Text.AlignRight }
                            }
                        }

                        // Task runs rows — real data from /api/agents/runs
                        Repeater {
                            model: dashboardHome.activeRunsList

                            delegate: Rectangle {
                                width: parent.width
                                height: Math.round(44 * root.sf)
                                color: agentRowMa.containsMouse ? Qt.rgba(0, 0, 0, 0.03) : "transparent"
                                radius: root.radiusSm

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(12 * root.sf)
                                    anchors.rightMargin: Math.round(12 * root.sf)
                                    spacing: 0

                                    // Task description elided
                                    Text {
                                        text: modelData.task || "No description"
                                        width: parent.width * 0.40
                                        font.pixelSize: Math.round(12 * root.sf)
                                        font.weight: Font.Medium
                                        color: root.textPrimary
                                        verticalAlignment: Text.AlignVCenter
                                        height: parent.height
                                        elide: Text.ElideRight
                                    }

                                    // Agent ID
                                    Text {
                                        text: modelData.agentId || "main"
                                        width: parent.width * 0.20
                                        font.pixelSize: Math.round(12 * root.sf)
                                        color: root.textSecondary
                                        verticalAlignment: Text.AlignVCenter
                                        height: parent.height
                                        elide: Text.ElideRight
                                    }

                                    // Status
                                    Row {
                                        width: parent.width * 0.15
                                        height: parent.height
                                        spacing: Math.round(4 * root.sf)

                                        Rectangle {
                                            width: Math.round(6 * root.sf); height: width
                                            radius: width / 2
                                            color: {
                                                var st = (modelData.status || "").toLowerCase();
                                                if (st === "running") return "#22c55e";     // green
                                                if (st === "pending") return "#f97316";     // orange
                                                if (st === "paused") return "#eab308";      // yellow
                                                if (st === "completed") return "#3b82f6";   // blue
                                                if (st === "error" || st === "stopped") return "#ef4444"; // red
                                                return "#94a3b8"; // gray
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: (modelData.status || "pending").charAt(0).toUpperCase() + (modelData.status || "pending").slice(1)
                                            font.pixelSize: Math.round(11 * root.sf)
                                            font.weight: Font.Medium
                                            color: {
                                                var st = (modelData.status || "").toLowerCase();
                                                if (st === "running") return "#22c55e";
                                                if (st === "pending") return "#f97316";
                                                if (st === "paused") return "#eab308";
                                                if (st === "completed") return "#3b82f6";
                                                if (st === "error" || st === "stopped") return "#ef4444";
                                                return root.textSecondary;
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    // Model
                                    Text {
                                        text: modelData.model || "default"
                                        width: parent.width * 0.25
                                        font.pixelSize: Math.round(11 * root.sf)
                                        color: root.textSecondary
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                        height: parent.height
                                        elide: Text.ElideRight
                                        font.family: "monospace"
                                    }
                                }

                                MouseArea {
                                    id: agentRowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openAppWindow("agents", "Agents", "agents")
                                }
                            }
                        }

                        // Empty state
                        Text {
                            visible: dashboardHome.activeRunsList.length === 0
                            text: "No active agent tasks running. Click \"New Task\" to start a background task."
                            font.pixelSize: Math.round(11 * root.sf)
                            color: root.textSecondary
                            topPadding: Math.round(16 * root.sf)
                            bottomPadding: Math.round(16 * root.sf)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // ── System Stats ──
                Rectangle {
                    width: parent.width
                    height: Math.round(100 * root.sf)
                    radius: root.radiusMd
                    color: Qt.rgba(1, 1, 1, 0.85)
                    border.color: Qt.rgba(0, 0, 0, 0.06)
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Math.round(16 * root.sf)
                        spacing: Math.round(8 * root.sf)

                        Text {
                            text: "System Health"
                            font.pixelSize: Math.round(13 * root.sf)
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        Row {
                            spacing: Math.round(32 * root.sf)
                            Column {
                                spacing: Math.round(2 * root.sf)
                                Text { text: "Agents"; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary }
                                Text { text: "" + dashboardHome.totalAgents; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: root.accentBlue }
                            }
                            Column {
                                spacing: Math.round(2 * root.sf)
                                Text { text: "Providers"; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary }
                                Text { text: dashboardHome.activeProviders + " / " + dashboardHome.providersList.length; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: root.accentPurple }
                            }
                            Column {
                                spacing: Math.round(2 * root.sf)
                                Text { text: "Tools"; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary }
                                Text { text: "" + dashboardHome.totalTools; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: root.accentGreen }
                            }
                            Column {
                                spacing: Math.round(2 * root.sf)
                                Text { text: "Skills"; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary }
                                Text { text: "" + dashboardHome.totalSkills; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: root.accentOrange }
                            }
                        }

                        Row {
                            spacing: Math.round(4 * root.sf)
                            Rectangle { width: Math.round(6 * root.sf); height: width; radius: width/2; color: root.accentGreen; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "All systems operational"; font.pixelSize: Math.round(10 * root.sf); color: root.accentGreen; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }

    // ── Top Bar ──
    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        z: 20
    }

    // ── Window Area (full height — dock/chatbar float on top) ──
    Item {
        id: winArea
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    // ── App Windows ──
    Repeater {
        id: windowRepeater
        model: root.openWindows
        delegate: AppWindow {
            windowTitle: modelData.title
            windowIcon: modelData.icon
            appId: modelData.appId
            windowArea: winArea
            nativeCmd: modelData.cmd || ""
            nativeSearchName: modelData.searchName || ""
            shellSurface: modelData.surface || null
            toplevelObj: modelData.toplevel || null
            initialX: parent.width / 2 - Math.round(350 * root.sf) + index * Math.round(30 * root.sf)
            initialY: Math.round(80 * root.sf) + index * Math.round(30 * root.sf)
        }
    }

    // ── AI Processing Chime Sound (via system) ──
    function playChime() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:7778/system/exec?cmd=aplay+-q+/opt/ainux/whaleos/assets/ai_chime.wav+%26");
        xhr.send();
    }

    // ── Siri-like Orb Animation ──
    Item {
        id: siriGlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: appDock.top
        anchors.bottomMargin: Math.round(-10 * root.sf)
        width: Math.round(200 * root.sf)
        height: Math.round(200 * root.sf)
        visible: chatBarItem.chatExpanded
        opacity: (chatBarItem.isSending || chatBarItem.isStreaming) ? 1.0 : 0.45

        property real phase: 0
        property bool active: chatBarItem.isSending || chatBarItem.isStreaming
        property bool wasActive: false

        // Play chime when processing starts
        onActiveChanged: {
            if (active && !wasActive) { playChime(); }
            wasActive = active;
        }

        // PERF: Replaced heavy Canvas orb + 150ms timer + pulse animation
        // with a simple static radial glow rectangle
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(100 * root.sf); height: width; radius: width / 2
            color: siriGlow.active ? Qt.rgba(0.35, 0.45, 1.0, 0.15) : Qt.rgba(0.3, 0.35, 0.8, 0.08)
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(50 * root.sf); height: width; radius: width / 2
            color: siriGlow.active ? Qt.rgba(0.6, 0.7, 1.0, 0.3) : Qt.rgba(0.5, 0.55, 0.9, 0.12)
        }
    }

    // ── Dock ──
    AppDock {
        id: appDock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(90 * root.sf)
        z: 5
    }

    // ── Chat Bar (overlay, expands upward — z:20 floats above dock so dock stays in place) ──
    ChatBar {
        id: chatBarItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: chatBarItem.chatFullScreen ? 0 : Math.round(24 * root.sf)
        width: chatBarItem.chatFullScreen ? parent.width : Math.min(parent.width - Math.round(32 * root.sf), Math.round(620 * root.sf))
        z: 20
    }

    // ── Launch Agent Task Dialog Overlay ──
    Item {
        id: newTaskDialog
        anchors.fill: parent
        visible: false
        z: 1000 // float on top of everything!

        function open() {
            taskPromptArea.text = "";
            selectedAgentId = "main";
            agentSelector.currentIndex = 0;
            agentSelector.expanded = false;
            visible = true;
            taskPromptArea.forceActiveFocus();
        }

        function close() {
            visible = false;
        }

        property string selectedAgentId: "main"

        // Backdrop
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea {
                anchors.fill: parent
                onClicked: newTaskDialog.close()
            }
        }

        // Dialog Card
        Rectangle {
            id: dialogCard
            width: Math.round(480 * root.sf)
            height: Math.round(360 * root.sf)
            anchors.centerIn: parent
            radius: root.radiusLg
            color: root.bgElevated
            border.color: root.borderColor
            border.width: 1
            
            MouseArea {
                anchors.fill: parent
                onClicked: {} // Prevent click-through
            }

            Column {
                anchors.fill: parent
                anchors.margins: Math.round(24 * root.sf)
                spacing: Math.round(16 * root.sf)

                // Title
                Row {
                    width: parent.width
                    Text {
                        text: "Launch AI Agent Task"
                        font.pixelSize: Math.round(16 * root.sf)
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                        width: parent.width - closeBtn.width
                    }
                    Text {
                        id: closeBtn
                        text: "✕"
                        font.pixelSize: Math.round(14 * root.sf)
                        color: root.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: newTaskDialog.close()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.borderColor
                }

                // Dropdown/Selector: Agent
                Column {
                    width: parent.width
                    spacing: Math.round(6 * root.sf)

                    Text {
                        text: "Select Agent"
                        font.pixelSize: Math.round(11 * root.sf)
                        font.weight: Font.DemiBold
                        color: root.textSecondary
                    }

                    Rectangle {
                        id: agentSelector
                        width: parent.width
                        height: Math.round(36 * root.sf)
                        radius: root.radiusSm
                        color: Qt.rgba(0, 0, 0, 0.03)
                        border.color: root.borderColor
                        border.width: 1
                        z: expanded ? 100 : 1

                        property int currentIndex: 0
                        property bool expanded: false

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(10 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var list = dashboardHome.agentsList;
                                if (list && list.length > agentSelector.currentIndex) {
                                    return list[agentSelector.currentIndex].name + " (" + list[agentSelector.currentIndex].id + ")";
                                }
                                return "Select an agent...";
                            }
                            font.pixelSize: Math.round(12 * root.sf)
                            color: root.textPrimary
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Math.round(10 * root.sf)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "▼"
                            font.pixelSize: Math.round(10 * root.sf)
                            color: root.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: agentSelector.expanded = !agentSelector.expanded
                        }
                    }
                }

                // Prompt Input Text Area
                Column {
                    width: parent.width
                    spacing: Math.round(6 * root.sf)

                    Text {
                        text: "Task Prompt / Instructions"
                        font.pixelSize: Math.round(11 * root.sf)
                        font.weight: Font.DemiBold
                        color: root.textSecondary
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.round(110 * root.sf)
                        radius: root.radiusSm
                        color: Qt.rgba(0, 0, 0, 0.03)
                        border.color: taskPromptArea.activeFocus ? root.accentBlue : root.borderColor
                        border.width: 1

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: Math.round(8 * root.sf)
                            contentHeight: taskPromptArea.height
                            clip: true

                            TextEdit {
                                id: taskPromptArea
                                width: parent.width
                                wrapMode: TextEdit.Wrap
                                font.pixelSize: Math.round(12 * root.sf)
                                color: root.textPrimary
                                selectByMouse: true
                                focus: true
                            }

                            Text {
                                visible: taskPromptArea.text === ""
                                text: "What task should the agent perform in the background?"
                                font.pixelSize: Math.round(12 * root.sf)
                                color: root.textMuted
                                wrapMode: Text.Wrap
                                width: parent.width
                            }
                        }
                    }
                }

                // Action buttons
                Row {
                    width: parent.width
                    spacing: Math.round(10 * root.sf)
                    layoutDirection: Qt.RightToLeft

                    // Start Button
                    Rectangle {
                        width: Math.round(100 * root.sf)
                        height: Math.round(32 * root.sf)
                        radius: root.radiusSm
                        color: startMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.3) : root.accentBlue

                        Text {
                            anchors.centerIn: parent
                            text: "Start Task"
                            font.pixelSize: Math.round(12 * root.sf)
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: startMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (taskPromptArea.text.trim().length === 0) {
                                    root.showToast("Please enter a task prompt", "error");
                                    return;
                                }
                                var agentId = newTaskDialog.selectedAgentId;
                                var prompt = taskPromptArea.text.trim();
                                newTaskDialog.close();
                                root.showToast("Starting background task...", "info");

                                API.startAgentRun(agentId, prompt, "", function(status, data) {
                                    if (status === 200 && data && data.ok) {
                                        root.showToast("Task started successfully in background", "success");
                                        dashboardHome.loadDashboardData(true);
                                    } else {
                                        root.showToast("Failed to start task: " + (data.error || "Unknown error"), "error");
                                    }
                                });
                            }
                        }
                    }

                    // Cancel Button
                    Rectangle {
                        width: Math.round(80 * root.sf)
                        height: Math.round(32 * root.sf)
                        radius: root.radiusSm
                        color: cancelBtnMa.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"
                        border.color: root.borderColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Math.round(12 * root.sf)
                            color: root.textSecondary
                        }

                        MouseArea {
                            id: cancelBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: newTaskDialog.close()
                        }
                    }
                }
            }

            // Dropdown list popup (placed inside dialogCard to escape column positioning and clipping)
            Rectangle {
                id: dropdownList
                visible: agentSelector.expanded
                // Position it dynamically relative to agentSelector
                x: agentSelector.parent.parent.x + agentSelector.x
                y: agentSelector.parent.parent.y + agentSelector.y + agentSelector.height + Math.round(4 * root.sf)
                width: agentSelector.width
                height: Math.min(Math.round(150 * root.sf), dropdownCol.height + Math.round(8 * root.sf))
                radius: root.radiusSm
                color: root.bgElevated
                border.color: root.borderColor
                border.width: 1
                z: 2000 // Float on top of prompt instructions area and other column elements!

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Math.round(4 * root.sf)
                    contentHeight: dropdownCol.height
                    clip: true

                    Column {
                        id: dropdownCol
                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: dashboardHome.agentsList

                            delegate: Rectangle {
                                width: dropdownCol.width
                                height: Math.round(30 * root.sf)
                                radius: root.radiusSm
                                color: itemMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.1) : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.round(8 * root.sf)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name + " (" + modelData.id + ")"
                                    font.pixelSize: Math.round(12 * root.sf)
                                    color: root.textPrimary
                                }

                                MouseArea {
                                    id: itemMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        agentSelector.currentIndex = index;
                                        newTaskDialog.selectedAgentId = modelData.id;
                                        agentSelector.expanded = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    // Load persisted OS config on startup
    Component.onCompleted: {
        API.getOsConfig(function(status, data) {
            if (data && data.config) {
                if (data.config.wallpaper) desktop.currentWallpaper = data.config.wallpaper;
            }
        });
    }
}
