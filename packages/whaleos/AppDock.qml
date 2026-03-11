import QtQuick
import QtQuick.Layouts

Rectangle {
    id: dock
    width: dockRow.width + Math.round(28 * root.sf)
    height: Math.round(78 * root.sf)
    radius: root.radiusLg
    color: Qt.rgba(0.06, 0.06, 0.09, 0.88)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    // Inner highlight line at top for depth
    Rectangle {
        anchors.top: parent.top; anchors.topMargin: 1
        anchors.left: parent.left; anchors.leftMargin: Math.round(16 * root.sf)
        anchors.right: parent.right; anchors.rightMargin: Math.round(16 * root.sf)
        height: 1; radius: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Row {
        id: dockRow; anchors.centerIn: parent; spacing: Math.round(2 * root.sf)

        Repeater {
            model: [
                // System apps (QML-based)
                { appId: "nativeapps", label: "Apps" },
                { appId: "settings",   label: "Settings" },
                { appId: "skills",     label: "Skills" },
                { appId: "extensions", label: "Extensions" },
                { appId: "providers",  label: "Providers" },
                { appId: "mcp",        label: "MCP Apps" },
                { appId: "agents",     label: "Agents" },
                { appId: "terminal",   label: "Terminal" }
            ]

            delegate: Item {
                id: dockItem
                width: Math.round(64 * root.sf)
                height: Math.round(68 * root.sf)
                visible: true

                property bool isOpen: {
                    for (var i = 0; i < root.openWindows.length; i++) {
                        if (root.openWindows[i].appId === modelData.appId) return true;
                    }
                    return false;
                }

                // Hover lift effect
                transform: Translate {
                    y: dockItemMa.containsMouse ? Math.round(-3 * root.sf) : 0
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                // Dock item
                Rectangle {
                    anchors.fill: parent; radius: root.radiusMd
                    color: dockItemMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent; spacing: Math.round(4 * root.sf)

                        // Icon container with subtle bg
                        Rectangle {
                            width: Math.round(32 * root.sf); height: Math.round(32 * root.sf)
                            radius: Math.round(8 * root.sf)
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: dockItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Canvas {
                                anchors.centerIn: parent
                                width: Math.round(22 * root.sf); height: Math.round(22 * root.sf)
                                property string appId: modelData.appId
                                property bool hovered: dockItemMa.containsMouse
                                property real s: root.sf
                                onHoveredChanged: requestPaint()
                                onSChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                    ctx.save(); ctx.scale(s, s);
                                    var mainColor = hovered ? "#e0eaff" : "#a0b4cc";
                                    ctx.strokeStyle = mainColor;
                                    ctx.fillStyle = mainColor;
                                    ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round";

                                    // ── App icons (clean line-art, no gradient) ──
                                    if (appId === "nativeapps") {
                                        // Grid of 4 rounded squares
                                        ctx.lineWidth = 1.4;
                                        var s1 = 6.5, g = 1.5;
                                        // Top-left
                                        roundedRect(ctx, 3, 3, s1, s1, 2);
                                        // Top-right
                                        roundedRect(ctx, 3 + s1 + g, 3, s1, s1, 2);
                                        // Bottom-left
                                        roundedRect(ctx, 3, 3 + s1 + g, s1, s1, 2);
                                        // Bottom-right - filled for variety
                                        ctx.fillStyle = mainColor;
                                        roundedRectFill(ctx, 3 + s1 + g, 3 + s1 + g, s1, s1, 2);
                                    }
                                    else if (appId === "settings") {
                                        // Clean gear: outer ring with notches + center circle
                                        ctx.lineWidth = 1.4;
                                        var cx = 11, cy = 11;
                                        // Draw gear teeth
                                        ctx.beginPath();
                                        for (var i = 0; i < 6; i++) {
                                            var a = i * Math.PI / 3 - Math.PI / 6;
                                            var outerR = 9, innerR = 7, toothW = 0.18;
                                            ctx.lineTo(cx + Math.cos(a - toothW) * outerR, cy + Math.sin(a - toothW) * outerR);
                                            ctx.lineTo(cx + Math.cos(a + toothW) * outerR, cy + Math.sin(a + toothW) * outerR);
                                            ctx.lineTo(cx + Math.cos(a + toothW + 0.16) * innerR, cy + Math.sin(a + toothW + 0.16) * innerR);
                                            var nextA = (i + 1) * Math.PI / 3 - Math.PI / 6;
                                            ctx.lineTo(cx + Math.cos(nextA - toothW - 0.16) * innerR, cy + Math.sin(nextA - toothW - 0.16) * innerR);
                                        }
                                        ctx.closePath(); ctx.stroke();
                                        // Center circle
                                        ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.stroke();
                                    }
                                    else if (appId === "skills") {
                                        // Lightning bolt - sharp, clean
                                        ctx.lineWidth = 1.5;
                                        ctx.beginPath();
                                        ctx.moveTo(12.5, 2);
                                        ctx.lineTo(6, 11);
                                        ctx.lineTo(10.5, 11);
                                        ctx.lineTo(9.5, 20);
                                        ctx.lineTo(16, 11);
                                        ctx.lineTo(11.5, 11);
                                        ctx.closePath();
                                        ctx.stroke();
                                    }
                                    else if (appId === "extensions") {
                                        // Puzzle piece - clean outline
                                        ctx.lineWidth = 1.5;
                                        ctx.beginPath();
                                        ctx.moveTo(3, 8); ctx.lineTo(7, 8);
                                        ctx.arc(9, 7, 2, Math.PI, 0);
                                        ctx.lineTo(11, 8); ctx.lineTo(19, 8);
                                        ctx.lineTo(19, 12);
                                        ctx.arc(18, 14, 2, -Math.PI / 2, Math.PI / 2);
                                        ctx.lineTo(19, 16); ctx.lineTo(19, 20);
                                        ctx.lineTo(3, 20); ctx.lineTo(3, 8);
                                        ctx.stroke();
                                    }
                                    else if (appId === "providers") {
                                        // Cloud - clean outline
                                        ctx.lineWidth = 1.5;
                                        ctx.beginPath();
                                        ctx.arc(8, 13, 4.5, Math.PI, 1.5 * Math.PI);
                                        ctx.arc(14, 11, 3.5, 1.25 * Math.PI, 2 * Math.PI);
                                        ctx.arc(17, 15, 2.5, 1.5 * Math.PI, 0.5 * Math.PI);
                                        ctx.lineTo(5, 17.5);
                                        ctx.arc(5, 15, 2.5, 0.5 * Math.PI, Math.PI);
                                        ctx.closePath(); ctx.stroke();
                                    }
                                    else if (appId === "mcp") {
                                        // Hub/nodes - center circle with 3 satellite circles + lines
                                        ctx.lineWidth = 1.4;
                                        // Center
                                        ctx.beginPath(); ctx.arc(11, 11, 3, 0, Math.PI * 2); ctx.stroke();
                                        // Lines to satellites
                                        ctx.beginPath(); ctx.moveTo(11, 8); ctx.lineTo(11, 4); ctx.stroke();
                                        ctx.beginPath(); ctx.moveTo(8.5, 12.5); ctx.lineTo(5, 16); ctx.stroke();
                                        ctx.beginPath(); ctx.moveTo(13.5, 12.5); ctx.lineTo(17, 16); ctx.stroke();
                                        // Satellite circles (outlined, not filled)
                                        ctx.beginPath(); ctx.arc(11, 3, 2, 0, Math.PI * 2); ctx.stroke();
                                        ctx.beginPath(); ctx.arc(4, 17, 2, 0, Math.PI * 2); ctx.stroke();
                                        ctx.beginPath(); ctx.arc(18, 17, 2, 0, Math.PI * 2); ctx.stroke();
                                    }
                                    else if (appId === "agents") {
                                        // Robot face - clean outlined
                                        ctx.lineWidth = 1.4;
                                        // Head
                                        roundedRect(ctx, 4, 5, 14, 11, 3);
                                        // Eyes
                                        ctx.beginPath(); ctx.arc(8.5, 10, 1.5, 0, Math.PI * 2); ctx.stroke();
                                        ctx.beginPath(); ctx.arc(13.5, 10, 1.5, 0, Math.PI * 2); ctx.stroke();
                                        // Antenna
                                        ctx.beginPath(); ctx.moveTo(11, 5); ctx.lineTo(11, 2); ctx.stroke();
                                        ctx.beginPath(); ctx.arc(11, 1.5, 1.2, 0, Math.PI * 2); ctx.stroke();
                                        // Mouth line
                                        ctx.beginPath(); ctx.moveTo(8, 13); ctx.lineTo(14, 13); ctx.stroke();
                                    }
                                    else if (appId === "terminal") {
                                        // Terminal prompt - clean
                                        ctx.lineWidth = 1.4;
                                        roundedRect(ctx, 1, 3, 20, 17, 2.5);
                                        // Prompt chevron
                                        ctx.lineWidth = 1.6;
                                        ctx.beginPath(); ctx.moveTo(5, 10); ctx.lineTo(9, 13.5); ctx.lineTo(5, 17); ctx.stroke();
                                        // Cursor line
                                        ctx.beginPath(); ctx.moveTo(12, 17); ctx.lineTo(17, 17); ctx.stroke();
                                    }
                                    ctx.restore();
                                }

                                // Helper: draw rounded rect outline
                                function roundedRect(ctx, x, y, w, h, r) {
                                    ctx.beginPath();
                                    ctx.moveTo(x + r, y);
                                    ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
                                    ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                                    ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
                                    ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
                                    ctx.closePath(); ctx.stroke();
                                }

                                // Helper: draw rounded rect filled
                                function roundedRectFill(ctx, x, y, w, h, r) {
                                    ctx.beginPath();
                                    ctx.moveTo(x + r, y);
                                    ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
                                    ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                                    ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
                                    ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
                                    ctx.closePath(); ctx.fill();
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label || ""; font.pixelSize: Math.round(9 * root.sf)
                            font.weight: dockItemMa.containsMouse ? Font.Medium : Font.Normal
                            color: dockItemMa.containsMouse ? "#e0eaff" : root.textSecondary
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Active indicator dot
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(4 * root.sf); height: Math.round(4 * root.sf)
                            radius: width / 2
                            color: dockItem.isOpen ? "#60a5fa" : "transparent"
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    MouseArea {
                        id: dockItemMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openApp(modelData.appId, modelData.label, modelData.appId, modelData.cmd || "", modelData.searchName || "")
                    }
                }
            }
        }
    }

    function openApp(appId, title, icon, cmd, searchName) {
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].appId === appId) return;
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: appId, title: title, icon: icon, cmd: cmd || "", searchName: searchName || "" });
        root.openWindows = wins;
    }
}
