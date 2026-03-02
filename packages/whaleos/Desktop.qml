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
        { id: "nebula",         name: "🌌 Nebula",         file: "assets/wallpapers/nebula.png" },
        { id: "cyber-grid",     name: "🔮 Cyber Grid",     file: "assets/wallpapers/cyber-grid.png" },
        { id: "aurora",         name: "🌈 Aurora",          file: "assets/wallpapers/aurora.png" },
        { id: "ocean-depth",    name: "🌊 Ocean Depth",    file: "assets/wallpapers/ocean-depth.png" },
        { id: "abstract-waves", name: "🔥 Abstract Waves", file: "assets/wallpapers/abstract-waves.png" },
        { id: "crystal",        name: "💎 Crystal",         file: "assets/wallpapers/crystal.png" },
        { id: "ocean",          name: "🐋 Ocean",           file: "assets/wallpapers/ocean.png" },
        { id: "topology",       name: "🧬 Topology",       file: "assets/wallpapers/topology.png" },
        { id: "abstract",       name: "🎨 Abstract",       file: "assets/wallpapers/abstract.png" },
        { id: "alien",          name: "👽 Alien",           file: "assets/wallpapers/alien.png" },
        { id: "cosmic",         name: "🪐 Cosmic",         file: "assets/wallpapers/cosmic.png" },
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
                color: pasteMa2.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
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
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

            // ── Open Works Folder ──
            Rectangle {
                width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                color: worksMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                        property real s: root.sf
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(s,s);
                            ctx.fillStyle = "#64b5f6";
                            ctx.beginPath(); ctx.moveTo(1,5); ctx.lineTo(6,5); ctx.lineTo(7,3); ctx.lineTo(1,3); ctx.closePath(); ctx.fill();
                            ctx.beginPath(); ctx.moveTo(1,5); ctx.lineTo(13,5); ctx.lineTo(13,13); ctx.lineTo(1,13); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = "#42a5f5";
                            ctx.beginPath(); ctx.moveTo(1,7); ctx.lineTo(13,7); ctx.lineTo(13,13); ctx.lineTo(1,13); ctx.closePath(); ctx.fill();
                            ctx.restore(); }
                        onSChanged: requestPaint()
                    }
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
            Canvas {
                width: Math.round(36 * root.sf); height: Math.round(36 * root.sf)
                anchors.horizontalCenter: parent.horizontalCenter
                property real s: root.sf
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                    ctx.save(); ctx.scale(s, s);
                    // Folder shape
                    ctx.fillStyle = "#64b5f6";
                    ctx.beginPath();
                    ctx.moveTo(2, 10); ctx.lineTo(2, 30); ctx.lineTo(34, 30);
                    ctx.lineTo(34, 12); ctx.lineTo(18, 12); ctx.lineTo(15, 8);
                    ctx.lineTo(2, 8); ctx.closePath(); ctx.fill();
                    // Folder tab
                    ctx.fillStyle = "#90caf9";
                    ctx.beginPath();
                    ctx.moveTo(2, 8); ctx.lineTo(15, 8); ctx.lineTo(18, 12);
                    ctx.lineTo(2, 12); ctx.closePath(); ctx.fill();
                    // Folder front
                    ctx.fillStyle = "#42a5f5";
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

            Image {
                anchors.centerIn: parent
                width: Math.round(56 * root.sf); height: Math.round(56 * root.sf)
                source: "assets/whale_logo.png"
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
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
        z: 20
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

    // ── Siri-like Orb Animation ──
    Item {
        id: siriGlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: appDock.top
        anchors.bottomMargin: Math.round(2 * root.sf)
        width: Math.round(120 * root.sf)
        height: Math.round(120 * root.sf)
        visible: chatBarItem.chatExpanded
        opacity: (chatBarItem.isSending || chatBarItem.isStreaming) ? 1.0 : 0.50
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        property real phase: 0
        property bool active: chatBarItem.isSending || chatBarItem.isStreaming

        // Animation timer — faster when AI is processing
        Timer {
            running: siriGlow.visible
            interval: 16; repeat: true
            onTriggered: {
                siriGlow.phase += siriGlow.active ? 0.035 : 0.012;
                orbCanvas.requestPaint();
            }
        }

        // Pulsating scale
        property real pulseScale: 1.0
        SequentialAnimation on pulseScale {
            running: siriGlow.visible; loops: Animation.Infinite
            NumberAnimation { to: 1.08; duration: 2200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.94; duration: 2200; easing.type: Easing.InOutSine }
        }

        transform: Scale {
            origin.x: siriGlow.width / 2; origin.y: siriGlow.height / 2
            xScale: siriGlow.pulseScale; yScale: siriGlow.pulseScale
        }

        Canvas {
            id: orbCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var w = width, h = height;
                ctx.clearRect(0, 0, w, h);

                var cx = w / 2, cy = h / 2;
                var p = siriGlow.phase;
                var isActive = siriGlow.active;
                var baseR = w * 0.22;

                // ── Layer 1: Outer ambient glow halo ──
                var outerR = baseR * 2.2;
                var outerGrad = ctx.createRadialGradient(cx, cy, baseR * 0.5, cx, cy, outerR);
                outerGrad.addColorStop(0, "rgba(100,120,255,0.12)");
                outerGrad.addColorStop(0.4, "rgba(130,80,220,0.06)");
                outerGrad.addColorStop(0.7, "rgba(50,200,160,0.03)");
                outerGrad.addColorStop(1, "rgba(0,0,0,0)");
                ctx.fillStyle = outerGrad;
                ctx.fillRect(0, 0, w, h);

                // ── Layer 2: Swirling color bands (aurora) ──
                var numBands = 5;
                for (var b = 0; b < numBands; b++) {
                    var angle = p * (0.6 + b * 0.15) + b * 1.257;
                    var bandR = baseR * (0.9 + 0.25 * Math.sin(p * 0.7 + b * 0.8));

                    // Offset position for swirl
                    var ox = cx + Math.cos(angle) * baseR * 0.25;
                    var oy = cy + Math.sin(angle) * baseR * 0.2;

                    var bandGrad = ctx.createRadialGradient(ox, oy, 0, ox, oy, bandR);

                    // Color cycling per band
                    var hue1 = (b * 72 + p * 20) % 360;
                    var hue2 = (hue1 + 60) % 360;

                    // Convert HSL-like to RGB components
                    var colors = [
                        [90, 140, 255],   // blue
                        [160, 80, 245],   // purple
                        [50, 210, 170],   // teal
                        [220, 100, 255],  // magenta
                        [80, 180, 255],   // cyan
                    ];
                    var c = colors[b % colors.length];

                    var intensity = isActive ? 0.55 : 0.35;
                    var midIntensity = isActive ? 0.25 : 0.12;

                    bandGrad.addColorStop(0, "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + intensity + ")");
                    bandGrad.addColorStop(0.5, "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + midIntensity + ")");
                    bandGrad.addColorStop(1, "rgba(0,0,0,0)");

                    ctx.globalCompositeOperation = "screen";
                    ctx.fillStyle = bandGrad;
                    ctx.beginPath();
                    ctx.arc(ox, oy, bandR, 0, Math.PI * 2);
                    ctx.fill();
                }

                ctx.globalCompositeOperation = "source-over";

                // ── Layer 3: Core orb — bright center ──
                var coreR = baseR * 0.7;
                var coreGrad = ctx.createRadialGradient(cx, cy - coreR * 0.15, 0, cx, cy, coreR);
                var coreAlpha = isActive ? 0.85 : 0.5;
                coreGrad.addColorStop(0, "rgba(220,230,255," + coreAlpha + ")");
                coreGrad.addColorStop(0.3, "rgba(140,160,255," + (coreAlpha * 0.6) + ")");
                coreGrad.addColorStop(0.7, "rgba(100,80,200," + (coreAlpha * 0.2) + ")");
                coreGrad.addColorStop(1, "rgba(0,0,0,0)");
                ctx.fillStyle = coreGrad;
                ctx.beginPath();
                ctx.arc(cx, cy, coreR, 0, Math.PI * 2);
                ctx.fill();

                // ── Layer 4: Specular highlight (top-left gleam) ──
                var specX = cx - coreR * 0.3;
                var specY = cy - coreR * 0.35;
                var specR = coreR * 0.4;
                var specGrad = ctx.createRadialGradient(specX, specY, 0, specX, specY, specR);
                specGrad.addColorStop(0, "rgba(255,255,255," + (isActive ? 0.5 : 0.25) + ")");
                specGrad.addColorStop(0.5, "rgba(200,220,255," + (isActive ? 0.15 : 0.06) + ")");
                specGrad.addColorStop(1, "rgba(0,0,0,0)");
                ctx.fillStyle = specGrad;
                ctx.beginPath();
                ctx.arc(specX, specY, specR, 0, Math.PI * 2);
                ctx.fill();

                // ── Layer 5: Sparkle particles ──
                ctx.globalCompositeOperation = "screen";
                for (var s = 0; s < 8; s++) {
                    var sparkAngle = p * (0.3 + s * 0.12) + s * 0.785;
                    var sparkDist = baseR * (0.5 + 0.4 * Math.sin(p * 0.5 + s * 1.1));
                    var sx = cx + Math.cos(sparkAngle) * sparkDist;
                    var sy = cy + Math.sin(sparkAngle) * sparkDist;
                    var sparkAlpha = 0.3 + 0.5 * Math.abs(Math.sin(p * 1.5 + s * 0.9));
                    if (!isActive) sparkAlpha *= 0.4;
                    var sparkSize = 2 + Math.sin(p * 2 + s) * 1;

                    ctx.fillStyle = "rgba(220,240,255," + sparkAlpha + ")";
                    ctx.beginPath();
                    ctx.arc(sx, sy, sparkSize, 0, Math.PI * 2);
                    ctx.fill();
                }
                ctx.globalCompositeOperation = "source-over";
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
        anchors.bottomMargin: chatBarItem.chatFullScreen ? 0 : Math.round(16 * root.sf)
        width: chatBarItem.chatFullScreen ? parent.width : Math.min(parent.width - Math.round(32 * root.sf), Math.round(620 * root.sf))
    }
}
