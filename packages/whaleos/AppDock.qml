import QtQuick
import QtQuick.Layouts

Rectangle {
    id: dock
    width: dockRow.width + Math.round(28 * root.sf)
    height: Math.round(74 * root.sf)
    radius: root.radiusLg
    color: Qt.rgba(0.08, 0.08, 0.11, 0.85)
    border.color: Qt.rgba(1, 1, 1, 0.1)
    border.width: 1

    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: Qt.rgba(0.14, 0.14, 0.18, 0.5)
    }

    Row {
        id: dockRow; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)

        Repeater {
            model: [
                { appId: "settings",   label: "Settings" },
                { appId: "skills",     label: "Skills" },
                { appId: "apps",       label: "Extensions" },
                { appId: "providers",  label: "Providers" },
                { appId: "mcp",        label: "MCP Apps" },
                { appId: "agents",     label: "Agents" },
                { appId: "terminal",   label: "Terminal" }
            ]

            delegate: Rectangle {
                width: Math.round(64 * root.sf); height: Math.round(60 * root.sf); radius: root.radiusMd
                color: dockItemMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Column {
                    anchors.centerIn: parent; spacing: Math.round(4 * root.sf)

                    Canvas {
                        id: dockIcon
                        width: Math.round(22 * root.sf); height: Math.round(22 * root.sf)
                        anchors.horizontalCenter: parent.horizontalCenter

                        property string appId: modelData.appId
                        property bool hovered: dockItemMouse.containsMouse
                        property real s: root.sf

                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save();
                            ctx.scale(s, s);
                            ctx.strokeStyle = hovered ? "#93c5fd" : "#94a3b8";
                            ctx.fillStyle = hovered ? "#93c5fd" : "#94a3b8";
                            ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round";

                            if (appId === "settings") {
                                ctx.beginPath();
                                for (var i = 0; i < 8; i++) {
                                    var a = i * Math.PI / 4;
                                    var r1 = 9, r2 = 7;
                                    ctx.lineTo(11+Math.cos(a)*r1, 11+Math.sin(a)*r1);
                                    ctx.lineTo(11+Math.cos(a+Math.PI/8)*r2, 11+Math.sin(a+Math.PI/8)*r2);
                                }
                                ctx.closePath(); ctx.stroke();
                                ctx.beginPath(); ctx.arc(11, 11, 3.5, 0, Math.PI*2); ctx.stroke();
                            } else if (appId === "skills") {
                                ctx.beginPath();
                                ctx.moveTo(13,1); ctx.lineTo(5,12); ctx.lineTo(11,12);
                                ctx.lineTo(9,21); ctx.lineTo(17,10); ctx.lineTo(11,10);
                                ctx.lineTo(13,1); ctx.closePath(); ctx.fill();
                            } else if (appId === "apps") {
                                ctx.lineWidth = 1.6;
                                ctx.beginPath();
                                ctx.moveTo(3,8); ctx.lineTo(7,8);
                                ctx.arc(9,7,2, Math.PI, 0);
                                ctx.lineTo(11,8); ctx.lineTo(19,8); ctx.lineTo(19,12);
                                ctx.arc(18,14,2, -Math.PI/2, Math.PI/2);
                                ctx.lineTo(19,16); ctx.lineTo(19,20); ctx.lineTo(3,20); ctx.lineTo(3,8);
                                ctx.stroke();
                            } else if (appId === "providers") {
                                ctx.beginPath();
                                ctx.arc(8,13,4.5,Math.PI,1.5*Math.PI);
                                ctx.arc(14,11,3.5,1.25*Math.PI,2*Math.PI);
                                ctx.arc(17,15,2.5,1.5*Math.PI,0.5*Math.PI);
                                ctx.lineTo(5,17.5); ctx.arc(5,15,2.5,0.5*Math.PI,Math.PI);
                                ctx.closePath(); ctx.fill();
                            } else if (appId === "mcp") {
                                ctx.lineWidth = 1.4;
                                ctx.beginPath(); ctx.arc(11,11,3,0,Math.PI*2); ctx.stroke();
                                ctx.beginPath(); ctx.arc(11,3,2,0,Math.PI*2); ctx.fill();
                                ctx.beginPath(); ctx.moveTo(11,5); ctx.lineTo(11,8); ctx.stroke();
                                ctx.beginPath(); ctx.arc(4,16,2,0,Math.PI*2); ctx.fill();
                                ctx.beginPath(); ctx.moveTo(5.5,14.5); ctx.lineTo(9,13); ctx.stroke();
                                ctx.beginPath(); ctx.arc(18,16,2,0,Math.PI*2); ctx.fill();
                                ctx.beginPath(); ctx.moveTo(16.5,14.5); ctx.lineTo(13,13); ctx.stroke();
                            } else if (appId === "agents") {
                                ctx.lineWidth = 1.5;
                                ctx.strokeRect(5,5,12,10);
                                ctx.beginPath(); ctx.arc(9,10,1.5,0,Math.PI*2); ctx.fill();
                                ctx.beginPath(); ctx.arc(15,10,1.5,0,Math.PI*2); ctx.fill();
                                ctx.beginPath(); ctx.moveTo(11,5); ctx.lineTo(11,2); ctx.stroke();
                                ctx.beginPath(); ctx.arc(11,1.5,1.5,0,Math.PI*2); ctx.fill();
                                ctx.strokeRect(6,15,10,5);
                            } else if (appId === "terminal") {
                                ctx.strokeRect(1,3,20,17);
                                ctx.beginPath(); ctx.moveTo(5,10); ctx.lineTo(10,14); ctx.lineTo(5,18); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(12,18); ctx.lineTo(17,18); ctx.stroke();
                            }
                            ctx.restore();
                        }

                        onHoveredChanged: requestPaint()
                        onSChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label; font.pixelSize: Math.round(10 * root.sf)
                        color: dockItemMouse.containsMouse ? "#93c5fd" : root.textSecondary
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: dockItemMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openApp(modelData.appId, modelData.label, modelData.appId)
                }
            }
        }
    }

    function openApp(appId, title, icon) {
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].appId === appId) return;
        }
        var wins = root.openWindows.slice();
        wins.push({ appId: appId, title: title, icon: icon });
        root.openWindows = wins;
    }
}
