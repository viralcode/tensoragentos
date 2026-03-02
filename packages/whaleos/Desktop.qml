import QtQuick
import QtQuick.Layouts

Rectangle {
    id: desktop
    anchors.fill: parent
    color: "#050510"

    // ── Open Files App ──
    function openFilesApp() {
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].appId === "files") return;
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: "files", title: "Works", icon: "files" });
        root.openWindows = wins;
    }

    // ── Wallpaper State ──
    property string currentWallpaper: "default"
    property bool wpExpanded: false
    property var wallpaperList: [
        { id: "default",        name: "Default Aurora",    file: "" },
        { id: "nebula",         name: "🌌 Nebula",         file: "wallpapers/nebula.png" },
        { id: "cyber-grid",     name: "🔮 Cyber Grid",     file: "wallpapers/cyber-grid.png" },
        { id: "aurora",         name: "🌈 Aurora",          file: "wallpapers/aurora.png" },
        { id: "ocean-depth",    name: "🌊 Ocean Depth",    file: "wallpapers/ocean-depth.png" },
        { id: "abstract-waves", name: "🔥 Abstract Waves", file: "wallpapers/abstract-waves.png" },
        { id: "crystal",        name: "💎 Crystal",         file: "wallpapers/crystal.png" },
        { id: "ocean",          name: "🐋 Ocean",           file: "wallpapers/ocean.png" },
        { id: "topology",       name: "🧬 Topology",       file: "wallpapers/topology.png" },
        { id: "abstract",       name: "🎨 Abstract",       file: "wallpapers/abstract.png" },
        { id: "alien",          name: "👽 Alien",           file: "wallpapers/alien.png" },
        { id: "cosmic",         name: "🪐 Cosmic",         file: "wallpapers/cosmic.png" },
        { id: "cyberpunk",      name: "⚡ Cyberpunk",      file: "wallpapers/cyberpunk.png" }
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

        // Subtle dark overlay to keep UI readable
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.25)
        }
    }

    // ── Default Gradient Wallpaper (shown when "default") ──
    Item {
        anchors.fill: parent
        visible: currentWallpaper === "default"

        // Base deep blue-purple gradient
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#0c0a1a" }
                GradientStop { position: 0.3; color: "#0f1628" }
                GradientStop { position: 0.6; color: "#101830" }
                GradientStop { position: 1.0; color: "#080e1c" }
            }
        }

        // Aurora glow - top left (teal/cyan)
        Rectangle {
            x: -parent.width * 0.1
            y: parent.height * 0.05
            width: parent.width * 0.7
            height: parent.height * 0.5
            radius: width / 2
            opacity: 0.15
            rotation: -15
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0ea5e9" }
                GradientStop { position: 0.4; color: "#06b6d4" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Aurora glow - center (purple/indigo)
        Rectangle {
            x: parent.width * 0.2
            y: parent.height * 0.1
            width: parent.width * 0.65
            height: parent.height * 0.55
            radius: width / 2
            opacity: 0.12
            rotation: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#7c3aed" }
                GradientStop { position: 0.5; color: "#4f46e5" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Aurora glow - right (blue/electric)
        Rectangle {
            x: parent.width * 0.4
            y: parent.height * 0.15
            width: parent.width * 0.55
            height: parent.height * 0.45
            radius: width / 2
            opacity: 0.1
            rotation: 20
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2563eb" }
                GradientStop { position: 0.5; color: "#1d4ed8" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Warm accent glow - bottom right (rose/pink)
        Rectangle {
            x: parent.width * 0.5
            y: parent.height * 0.5
            width: parent.width * 0.5
            height: parent.height * 0.4
            radius: width / 2
            opacity: 0.06
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#e11d48" }
                GradientStop { position: 0.5; color: "#be185d" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Star field Canvas
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Draw stars
                var seed = 42;
                function pseudoRandom() {
                    seed = (seed * 16807 + 0) % 2147483647;
                    return seed / 2147483647;
                }

                for (var i = 0; i < 80; i++) {
                    var sx = pseudoRandom() * width;
                    var sy = pseudoRandom() * height;
                    var sr = pseudoRandom() * 1.2 + 0.3;
                    var so = pseudoRandom() * 0.4 + 0.1;
                    ctx.beginPath();
                    ctx.fillStyle = "rgba(255, 255, 255, " + so + ")";
                    ctx.arc(sx, sy, sr, 0, Math.PI * 2);
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

    // ── Context Menu ──
    Rectangle {
        id: contextMenu
        visible: false
        width: Math.round(220 * root.sf)
        height: menuCol.height + Math.round(16 * root.sf)
        radius: root.radiusMd
        color: Qt.rgba(0.08, 0.08, 0.10, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.1)
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
                color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Text { text: "📋"; font.pixelSize: Math.round(13 * root.sf) }
                    Text { text: "Copy"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary }
                    Item { width: Math.round(40 * root.sf); height: 1 }
                    Text { text: "Ctrl+C"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                }
                MouseArea { id: copyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.showToast("Copied to clipboard", "success"); contextMenu.visible = false; } }
            }

            // ── Paste ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: pasteMa2.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Text { text: "📋"; font.pixelSize: Math.round(13 * root.sf) }
                    Text { text: "Paste"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary }
                    Item { width: Math.round(36 * root.sf); height: 1 }
                    Text { text: "Ctrl+V"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                }
                MouseArea { id: pasteMa2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { var clip = sysManager.pasteFromClipboard(); if (clip) root.showToast("Pasted: " + clip.substring(0, 30), "info"); contextMenu.visible = false; } }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

            // ── Open Works Folder ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: worksMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Text { text: "📂"; font.pixelSize: Math.round(13 * root.sf) }
                    Text { text: "Open Works"; font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary }
                }
                MouseArea { id: worksMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { desktop.openFilesApp(); contextMenu.visible = false; } }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

            // ── Wallpaper Section (expandable/collapsible) ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: wpHeaderMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)
                    Text { text: desktop.wpExpanded ? "▾" : "▸"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "🖼"; font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
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
                    color: wpItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) :
                           desktop.currentWallpaper === modelData.id ? Qt.rgba(1, 1, 1, 0.05) :
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
                            border.color: desktop.currentWallpaper === modelData.id ? root.accentBlue : Qt.rgba(1, 1, 1, 0.15)
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
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // Close option
            Rectangle {
                width: parent.width
                height: Math.round(30 * root.sf)
                radius: root.radiusSm
                color: closeMenuMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

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

    // ── Works Folder Desktop Icon ──
    Rectangle {
        id: worksIcon
        x: Math.round(24 * root.sf); y: Math.round(60 * root.sf)
        width: Math.round(72 * root.sf); height: Math.round(78 * root.sf)
        radius: root.radiusMd; z: 10
        color: worksIconMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        Column {
            anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
            Text {
                text: "📂"; font.pixelSize: Math.round(34 * root.sf)
                anchors.horizontalCenter: parent.horizontalCenter
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

    // ── Whale Logo Watermark ──
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(-20 * root.sf)
        spacing: Math.round(14 * root.sf)
        opacity: currentWallpaper === "default" ? 0.35 : 0.20

        Rectangle {
            width: Math.round(90 * root.sf); height: Math.round(90 * root.sf); radius: width / 2
            color: Qt.rgba(0.15, 0.3, 0.7, 0.2)
            border.color: Qt.rgba(0.4, 0.6, 1.0, 0.25)
            border.width: 1.5
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                anchors.centerIn: parent
                width: Math.round(56 * root.sf); height: Math.round(56 * root.sf)
                property real s: root.sf
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.save(); ctx.scale(s, s);
                    ctx.beginPath();
                    ctx.fillStyle = "#93c5fd";
                    ctx.moveTo(8, 36);
                    ctx.quadraticCurveTo(4, 22, 14, 16);
                    ctx.quadraticCurveTo(24, 8, 38, 12);
                    ctx.quadraticCurveTo(50, 14, 52, 26);
                    ctx.quadraticCurveTo(56, 34, 50, 40);
                    ctx.quadraticCurveTo(52, 46, 56, 42);
                    ctx.quadraticCurveTo(60, 38, 58, 50);
                    ctx.quadraticCurveTo(54, 54, 48, 46);
                    ctx.quadraticCurveTo(38, 50, 28, 48);
                    ctx.quadraticCurveTo(16, 46, 8, 36);
                    ctx.fill();
                    ctx.beginPath(); ctx.fillStyle = "#0f172a";
                    ctx.arc(22, 24, 2.5, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.fillStyle = "#ffffff";
                    ctx.arc(23, 23, 1, 0, Math.PI * 2); ctx.fill();
                    ctx.strokeStyle = "#93c5fd"; ctx.lineWidth = 1.5;
                    ctx.beginPath(); ctx.moveTo(32, 12); ctx.lineTo(32, 4); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(28, 4); ctx.quadraticCurveTo(32, -1, 36, 4); ctx.stroke();
                    ctx.restore();
                }
                onSChanged: requestPaint()
            }
        }

        Text {
            text: "T E N S O R A G E N T   O S"
            font.pixelSize: Math.round(13 * root.sf)
            font.weight: Font.Normal
            font.letterSpacing: Math.round(2 * root.sf)
            color: "#93c5fd"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── Top Bar ──
    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // ── Window Area ──
    Item {
        id: windowArea
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: dockArea.top
    }

    // ── App Windows ──
    Repeater {
        model: root.openWindows
        delegate: AppWindow {
            windowTitle: modelData.title
            windowIcon: modelData.icon
            appId: modelData.appId
            windowArea: windowArea
            initialX: parent.width / 2 - Math.round(350 * root.sf) + index * Math.round(30 * root.sf)
            initialY: Math.round(80 * root.sf) + index * Math.round(30 * root.sf)
        }
    }

    // ── Siri-like Glow Animation ──
    Item {
        id: siriGlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: appDock.top
        anchors.bottomMargin: Math.round(6 * root.sf)
        width: Math.min(parent.width - Math.round(80 * root.sf), Math.round(500 * root.sf))
        height: Math.round(28 * root.sf)
        visible: chatBarItem.chatExpanded
        opacity: (chatBarItem.isSending || chatBarItem.isStreaming) ? 1.0 : 0.35
        Behavior on opacity { NumberAnimation { duration: 500 } }

        property real phase: 0

        // Animation timer
        Timer {
            running: siriGlow.visible
            interval: 30; repeat: true
            onTriggered: { siriGlow.phase += 0.04; siriCanvas.requestPaint(); }
        }

        Canvas {
            id: siriCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var p = siriGlow.phase;

                // Draw multiple glowing orbs that move
                var orbs = [
                    { x: cx + Math.sin(p * 1.2) * width * 0.3, r: 0.35, g: 0.55, b: 1.0, size: 60 },
                    { x: cx + Math.sin(p * 0.8 + 1) * width * 0.25, r: 0.65, g: 0.30, b: 1.0, size: 55 },
                    { x: cx + Math.sin(p * 1.5 + 2) * width * 0.35, r: 0.20, g: 0.85, b: 0.70, size: 50 },
                    { x: cx + Math.sin(p * 1.0 + 3.5) * width * 0.28, r: 0.85, g: 0.40, b: 0.95, size: 45 },
                ];

                for (var i = 0; i < orbs.length; i++) {
                    var o = orbs[i];
                    var grad = ctx.createRadialGradient(o.x, cy, 0, o.x, cy, o.size);
                    grad.addColorStop(0, "rgba(" + Math.round(o.r * 255) + "," + Math.round(o.g * 255) + "," + Math.round(o.b * 255) + ",0.6)");
                    grad.addColorStop(0.4, "rgba(" + Math.round(o.r * 255) + "," + Math.round(o.g * 255) + "," + Math.round(o.b * 255) + ",0.2)");
                    grad.addColorStop(1, "rgba(0,0,0,0)");
                    ctx.fillStyle = grad;
                    ctx.fillRect(0, 0, width, height);
                }

                // Bright center line
                var lineGrad = ctx.createLinearGradient(0, 0, width, 0);
                var lp1 = 0.5 + Math.sin(p * 1.3) * 0.3;
                var lp2 = 0.5 + Math.sin(p * 0.9 + 1.5) * 0.3;
                lineGrad.addColorStop(0, "rgba(90,140,255,0)");
                lineGrad.addColorStop(Math.min(lp1, lp2), "rgba(90,140,255,0.8)");
                lineGrad.addColorStop((lp1 + lp2) / 2, "rgba(160,80,255,1)");
                lineGrad.addColorStop(Math.max(lp1, lp2), "rgba(50,220,180,0.8)");
                lineGrad.addColorStop(1, "rgba(90,140,255,0)");
                ctx.fillStyle = lineGrad;
                ctx.fillRect(0, cy - 1.5, width, 3);
            }
        }
    }

    // ── Dock ──
    AppDock {
        id: appDock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: chatBarItem.top
        anchors.bottomMargin: Math.round(10 * root.sf)
    }

    // ── Chat Bar (absolute positioned, expands upward) ──
    ChatBar {
        id: chatBarItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(16 * root.sf)
        width: Math.min(parent.width - Math.round(32 * root.sf), Math.round(620 * root.sf))
    }
}
