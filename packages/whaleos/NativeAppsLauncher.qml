import QtQuick
import QtQuick.Layouts

Rectangle {
    id: nativeAppsLauncher
    anchors.fill: parent
    color: "#1e1e2e"

    property var nativeApps: [
        { appId: "native-chromium",   label: "Chrome",     cmd: "chromium --no-sandbox", searchName: "Chromium",    icon: "appicons/chromium.png",   accent: "#60a5fa" },
        { appId: "native-mousepad",   label: "Editor",     cmd: "mousepad",              searchName: "Mousepad",   icon: "appicons/editor.png",     accent: "#4ade80" },
        { appId: "native-galculator", label: "Calculator", cmd: "galculator",            searchName: "galculator", icon: "appicons/calculator.png", accent: "#c084fc" }
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

                        Image {
                            width: 40; height: 40
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
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
