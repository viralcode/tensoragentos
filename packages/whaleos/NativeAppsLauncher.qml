import QtQuick
import QtQuick.Layouts

Rectangle {
    id: nativeAppsLauncher
    anchors.fill: parent
    color: "#1e1e2e"

    property var nativeApps: [
        { appId: "native-chromium",   label: "Chrome",     cmd: "chromium --no-sandbox", searchName: "Chromium",    iconType: "chrome",     accent: "#60a5fa" },
        { appId: "native-mousepad",   label: "Editor",     cmd: "mousepad",              searchName: "Mousepad",   iconType: "editor",     accent: "#4ade80" },
        { appId: "native-galculator", label: "Calculator", cmd: "galculator",            searchName: "galculator", iconType: "calculator", accent: "#c084fc" }
    ]

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            text: "Applications"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: "#e2e8f0"
        }

        Text {
            text: "Native Linux applications installed on this system"
            font.pixelSize: 13
            color: "#94a3b8"
        }

        GridLayout {
            width: parent.width
            columns: 3
            columnSpacing: 16
            rowSpacing: 16

            Repeater {
                model: nativeApps

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 120
                    height: 120
                    radius: 8
                    color: appMa.containsMouse ? "#2a2a3e" : "#252536"
                    border.color: appMa.containsMouse ? modelData.accent : "#333348"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Canvas {
                            width: 44; height: 44
                            anchors.horizontalCenter: parent.horizontalCenter
                            property string iconType: modelData.iconType
                            property string accent: modelData.accent
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var s = width / 44;

                                if (iconType === "chrome") {
                                    // Chrome logo
                                    var cx = 22 * s, cy = 22 * s, r = 18 * s, ir = 8 * s;
                                    // Red arc (top-right)
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, -Math.PI/6, -Math.PI*5/6, true);
                                    ctx.closePath();
                                    ctx.fillStyle = "#ea4335";
                                    ctx.fill();
                                    // Green arc (bottom-left)
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, -Math.PI*5/6, Math.PI/2, true);
                                    ctx.closePath();
                                    ctx.fillStyle = "#34a853";
                                    ctx.fill();
                                    // Yellow arc (bottom-right)
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, Math.PI/2, -Math.PI/6, true);
                                    ctx.closePath();
                                    ctx.fillStyle = "#fbbc05";
                                    ctx.fill();
                                    // White ring
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, ir + 2*s, 0, Math.PI*2);
                                    ctx.fillStyle = "#ffffff";
                                    ctx.fill();
                                    // Blue center
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, ir, 0, Math.PI*2);
                                    ctx.fillStyle = "#4285f4";
                                    ctx.fill();
                                } else if (iconType === "editor") {
                                    // Text editor icon
                                    var pad = 6 * s;
                                    // Page
                                    ctx.fillStyle = "#1e293b";
                                    ctx.strokeStyle = "#4ade80";
                                    ctx.lineWidth = 1.5 * s;
                                    var pw = 28 * s, ph = 34 * s;
                                    var px = (44*s - pw) / 2, py = (44*s - ph) / 2;
                                    ctx.beginPath();
                                    ctx.roundRect(px, py, pw, ph, 3*s);
                                    ctx.fill(); ctx.stroke();
                                    // Lines of text
                                    ctx.fillStyle = "#4ade80";
                                    var lineY = py + 8*s;
                                    var widths = [18, 14, 20, 10, 16];
                                    for (var i = 0; i < widths.length; i++) {
                                        ctx.fillRect(px + 5*s, lineY, widths[i]*s, 2*s);
                                        lineY += 5*s;
                                    }
                                } else if (iconType === "calculator") {
                                    // Calculator icon
                                    var bx = 8*s, by = 4*s, bw = 28*s, bh = 36*s;
                                    ctx.fillStyle = "#1e1b4b";
                                    ctx.strokeStyle = "#c084fc";
                                    ctx.lineWidth = 1.5*s;
                                    ctx.beginPath();
                                    ctx.roundRect(bx, by, bw, bh, 4*s);
                                    ctx.fill(); ctx.stroke();
                                    // Display
                                    ctx.fillStyle = "#312e81";
                                    ctx.fillRect(bx+4*s, by+4*s, bw-8*s, 8*s);
                                    ctx.fillStyle = "#a78bfa";
                                    ctx.font = (8*s) + "px sans-serif";
                                    ctx.textAlign = "right";
                                    ctx.fillText("42", bx+bw-6*s, by+10.5*s);
                                    // Buttons grid
                                    var colors = ["#7c3aed","#7c3aed","#7c3aed","#f59e0b",
                                                   "#6d28d9","#6d28d9","#6d28d9","#f59e0b",
                                                   "#6d28d9","#6d28d9","#6d28d9","#ef4444"];
                                    for (var row = 0; row < 3; row++) {
                                        for (var col = 0; col < 4; col++) {
                                            ctx.fillStyle = colors[row*4+col];
                                            ctx.beginPath();
                                            ctx.roundRect(bx+3*s + col*6.2*s, by+15*s + row*7*s, 5*s, 5.5*s, 1.5*s);
                                            ctx.fill();
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: appMa.containsMouse ? modelData.accent : "#e2e8f0"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: appMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var wins = root.openWindows.slice();
                            for (var i = 0; i < wins.length; i++) {
                                if (wins[i].appId === modelData.appId) return;
                            }
                            wins.push({
                                appId: modelData.appId,
                                title: modelData.label,
                                icon: modelData.appId,
                                cmd: modelData.cmd,
                                searchName: modelData.searchName
                            });
                            root.openWindows = wins;
                        }
                    }
                }
            }
        }
    }
}
