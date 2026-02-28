import QtQuick
import QtQuick.Layouts

Rectangle {
    id: dock
    width: dockRow.width + 24
    height: 68
    radius: root.radiusLg
    color: Qt.rgba(0.1, 0.1, 0.12, 0.8)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    // Frosted glass effect
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(0.14, 0.14, 0.18, 0.5)
    }

    Row {
        id: dockRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: [
                { appId: "settings",  label: "Settings" },
                { appId: "skills",    label: "Skills" },
                { appId: "apps",      label: "Apps" },
                { appId: "providers", label: "Providers" },
                { appId: "terminal",  label: "Terminal" }
            ]

            delegate: Rectangle {
                width: 64
                height: 56
                radius: root.radiusMd
                color: dockItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                Behavior on color { ColorAnimation { duration: 150 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    // Canvas-drawn icon (no emoji needed)
                    Canvas {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22; height: 22
                        property string appId: modelData.appId
                        property bool hovered: dockItemMouse.containsMouse

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var c = hovered ? "#93c5fd" : "#a1a1aa";
                            ctx.strokeStyle = c;
                            ctx.fillStyle = c;
                            ctx.lineWidth = 1.5;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";

                            if (appId === "settings") {
                                // Gear icon
                                var cx = 11, cy = 11, or_ = 9, ir = 5.5;
                                ctx.beginPath();
                                for (var i = 0; i < 8; i++) {
                                    var a1 = (i * Math.PI / 4) - 0.2;
                                    var a2 = (i * Math.PI / 4) + 0.2;
                                    ctx.lineTo(cx + or_ * Math.cos(a1), cy + or_ * Math.sin(a1));
                                    ctx.lineTo(cx + or_ * Math.cos(a2), cy + or_ * Math.sin(a2));
                                    var a3 = ((i + 0.5) * Math.PI / 4) - 0.15;
                                    var a4 = ((i + 0.5) * Math.PI / 4) + 0.15;
                                    ctx.lineTo(cx + (ir+1) * Math.cos(a3), cy + (ir+1) * Math.sin(a3));
                                    ctx.lineTo(cx + (ir+1) * Math.cos(a4), cy + (ir+1) * Math.sin(a4));
                                }
                                ctx.closePath();
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(cx, cy, 3.5, 0, Math.PI * 2);
                                ctx.stroke();

                            } else if (appId === "skills") {
                                // Lightning bolt / zap
                                ctx.beginPath();
                                ctx.moveTo(13, 1);
                                ctx.lineTo(5, 12);
                                ctx.lineTo(11, 12);
                                ctx.lineTo(9, 21);
                                ctx.lineTo(17, 10);
                                ctx.lineTo(11, 10);
                                ctx.lineTo(13, 1);
                                ctx.closePath();
                                ctx.fill();

                            } else if (appId === "apps") {
                                // Grid of 4 squares
                                ctx.fillRect(2, 2, 8, 8);
                                ctx.fillRect(12, 2, 8, 8);
                                ctx.fillRect(2, 12, 8, 8);
                                ctx.fillRect(12, 12, 8, 8);

                            } else if (appId === "providers") {
                                // Cloud icon
                                ctx.beginPath();
                                ctx.arc(8, 12, 5, Math.PI, 1.5 * Math.PI);
                                ctx.arc(14, 10, 4, 1.25 * Math.PI, 2 * Math.PI);
                                ctx.arc(17, 14, 3, 1.5 * Math.PI, 0.5 * Math.PI);
                                ctx.lineTo(5, 17);
                                ctx.arc(5, 14, 3, 0.5 * Math.PI, Math.PI);
                                ctx.closePath();
                                ctx.fill();

                            } else if (appId === "terminal") {
                                // Terminal prompt >_
                                ctx.strokeRect(1, 2, 20, 18);
                                ctx.beginPath();
                                ctx.moveTo(5, 9);
                                ctx.lineTo(10, 13);
                                ctx.lineTo(5, 17);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(12, 17);
                                ctx.lineTo(17, 17);
                                ctx.stroke();
                            }
                        }

                        // Repaint on hover change
                        Connections {
                            target: dockItemMouse
                            function onContainsMouseChanged() {
                                whaleCanvas.requestPaint();
                            }
                        }
                        Component.onCompleted: requestPaint()
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize: 10
                        color: dockItemMouse.containsMouse ? "#93c5fd" : root.textSecondary
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: dockItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
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
