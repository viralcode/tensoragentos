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
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, 44, 44);

                                if (iconType === "chrome") {
                                    var cx = 22, cy = 22, r = 18, ir = 8;
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, -Math.PI/6, -Math.PI*5/6, true);
                                    ctx.closePath();
                                    ctx.fillStyle = "#ea4335";
                                    ctx.fill();
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, -Math.PI*5/6, Math.PI/2, true);
                                    ctx.closePath();
                                    ctx.fillStyle = "#34a853";
                                    ctx.fill();
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, Math.PI/2, -Math.PI/6, true);
                                    ctx.closePath();
                                    ctx.fillStyle = "#fbbc05";
                                    ctx.fill();
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, 10, 0, Math.PI*2);
                                    ctx.fillStyle = "#ffffff";
                                    ctx.fill();
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, ir, 0, Math.PI*2);
                                    ctx.fillStyle = "#4285f4";
                                    ctx.fill();

                                } else if (iconType === "editor") {
                                    // Page background
                                    ctx.fillStyle = "#1e293b";
                                    ctx.fillRect(8, 5, 28, 34);
                                    ctx.strokeStyle = "#4ade80";
                                    ctx.lineWidth = 1.5;
                                    ctx.strokeRect(8, 5, 28, 34);
                                    // Text lines
                                    ctx.fillStyle = "#4ade80";
                                    ctx.fillRect(13, 13, 18, 2);
                                    ctx.fillRect(13, 18, 14, 2);
                                    ctx.fillRect(13, 23, 20, 2);
                                    ctx.fillRect(13, 28, 10, 2);
                                    ctx.fillRect(13, 33, 16, 2);

                                } else if (iconType === "calculator") {
                                    // Body
                                    ctx.fillStyle = "#1e1b4b";
                                    ctx.fillRect(8, 4, 28, 36);
                                    ctx.strokeStyle = "#c084fc";
                                    ctx.lineWidth = 1.5;
                                    ctx.strokeRect(8, 4, 28, 36);
                                    // Display
                                    ctx.fillStyle = "#312e81";
                                    ctx.fillRect(12, 8, 20, 8);
                                    ctx.fillStyle = "#a78bfa";
                                    ctx.font = "bold 8px sans-serif";
                                    ctx.textAlign = "right";
                                    ctx.fillText("42", 30, 14.5);
                                    // Buttons
                                    var bColors = ["#7c3aed","#7c3aed","#7c3aed","#f59e0b",
                                                   "#6d28d9","#6d28d9","#6d28d9","#f59e0b",
                                                   "#6d28d9","#6d28d9","#6d28d9","#ef4444"];
                                    for (var row = 0; row < 3; row++) {
                                        for (var col = 0; col < 4; col++) {
                                            ctx.fillStyle = bColors[row*4+col];
                                            ctx.fillRect(11 + col*6, 19 + row*7, 5, 5);
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
