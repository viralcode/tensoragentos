import QtQuick
import QtQuick.Layouts

Rectangle {
    id: dock
    width: dockRow.width + Math.round(28 * root.sf)
    height: Math.round(78 * root.sf)
    radius: root.radiusLg
    color: Qt.rgba(1, 1, 1, 0.88)
    border.color: Qt.rgba(0, 0, 0, 0.08)
    border.width: 1

    // Subtle top highlight
    Rectangle {
        anchors.top: parent.top; anchors.topMargin: 1
        anchors.left: parent.left; anchors.leftMargin: Math.round(16 * root.sf)
        anchors.right: parent.right; anchors.rightMargin: Math.round(16 * root.sf)
        height: 1; radius: 1
        color: Qt.rgba(0, 0, 0, 0.04)
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

                // Hover lift effect — gentle & optimized for smooth rendering
                transform: Translate {
                    y: dockItemMa.containsMouse ? Math.round(-3 * root.sf) : 0
                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }

                // Dock item
                Rectangle {
                    anchors.fill: parent; radius: root.radiusMd
                    color: dockItemMa.containsMouse ? Qt.rgba(0, 0, 0, 0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent; spacing: Math.round(4 * root.sf)

                        // Icon container with subtle bg
                        Rectangle {
                            width: Math.round(32 * root.sf); height: Math.round(32 * root.sf)
                            radius: Math.round(8 * root.sf)
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: dockItemMa.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                font.family: root.iconFont
                                font.weight: Font.Black
                                font.pixelSize: Math.round(18 * root.sf)
                                color: dockItemMa.containsMouse ? "#2563eb" : "#64748b"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                text: {
                                    if (modelData.appId === "nativeapps") return "\uf009"; // th
                                    if (modelData.appId === "settings") return "\uf013";   // gear
                                    if (modelData.appId === "skills") return "\uf0e7";     // bolt
                                    if (modelData.appId === "extensions") return "\uf12e"; // puzzle-piece
                                    if (modelData.appId === "providers") return "\uf0c2";  // cloud
                                    if (modelData.appId === "mcp") return "\uf0e8";        // sitemap
                                    if (modelData.appId === "agents") return "\uf544";     // robot
                                    if (modelData.appId === "terminal") return "\uf120";   // terminal
                                    return "";
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label || ""; font.pixelSize: Math.round(9 * root.sf)
                            font.weight: dockItemMa.containsMouse ? Font.Medium : Font.Normal
                            color: dockItemMa.containsMouse ? "#2563eb" : root.textSecondary
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Active indicator — neon gradient dot
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(4 * root.sf); height: Math.round(4 * root.sf)
                            radius: width / 2
                            color: dockItem.isOpen ? "#2563eb" : "transparent"
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
            if (root.openWindows[i].appId === appId) {
                if (typeof root.focusWindow === "function") {
                    root.focusWindow(appId);
                }
                return;
            }
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: appId, title: title, icon: icon, cmd: cmd || "", searchName: searchName || "" });
        root.openWindows = wins;
    }
}
