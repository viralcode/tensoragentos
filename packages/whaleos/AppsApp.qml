import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: appsApp
    anchors.fill: parent
    color: "transparent"

    property var extensions: []

    Component.onCompleted: loadExtensions()

    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: appsCol.height
        clip: true

        ColumnLayout {
            id: appsCol
            width: parent.width
            spacing: 16

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Apps"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: root.textPrimary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 100; height: 32; radius: root.radiusSm
                    color: Qt.rgba(1,1,1,0.06)
                    border.color: root.borderColor; border.width: 1

                    Text { anchors.centerIn: parent; text: "+ New App"; font.pixelSize: 12; color: root.textSecondary }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }
            }

            Text {
                text: "Extensions and automations installed on this system"
                font.pixelSize: 13
                color: root.textSecondary
            }

            // Extensions grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: extensions

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 200
                        height: extCol.height + 24
                        radius: root.radiusMd
                        color: root.bgElevated
                        border.color: root.borderColor
                        border.width: 1

                        ColumnLayout {
                            id: extCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                spacing: 8

                                Text { text: "📦"; font.pixelSize: 18 }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: modelData.name || "Extension"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: root.textPrimary
                                    }
                                    Text {
                                        text: modelData.schedule || "Manual"
                                        font.pixelSize: 10
                                        color: root.textMuted
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Status
                                Rectangle {
                                    width: 56; height: 22; radius: 11
                                    color: modelData.enabled ?
                                        Qt.rgba(0.13, 0.77, 0.37, 0.15) :
                                        Qt.rgba(1, 1, 1, 0.06)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.enabled ? "On" : "Off"
                                        font.pixelSize: 10
                                        color: modelData.enabled ? root.accentGreen : root.textMuted
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description || "No description"
                                font.pixelSize: 12
                                color: root.textSecondary
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            // Actions
                            RowLayout {
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "Run", color: root.accentBlue },
                                        { label: "Toggle", color: Qt.rgba(1,1,1,0.06) },
                                        { label: "Delete", color: Qt.rgba(1,1,1,0.06) },
                                        { label: "Edit", color: Qt.rgba(1,1,1,0.06) }
                                    ]

                                    delegate: Rectangle {
                                        width: 52; height: 26; radius: root.radiusSm
                                        color: modelData.color
                                        border.color: modelData.label !== "Run" ? root.borderColor : "transparent"
                                        border.width: modelData.label !== "Run" ? 1 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label === "Edit" ? "Edit ⏳" : modelData.label
                                            font.pixelSize: 10
                                            color: modelData.label === "Run" ? "#ffffff" :
                                                   modelData.label === "Delete" ? root.accentRed :
                                                   modelData.label === "Edit" ? root.textMuted : root.textSecondary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: modelData.label === "Edit" ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                var extName = extensions[index] ? extensions[index].name : "";
                                                if (modelData.label === "Run") runExt(extName);
                                                else if (modelData.label === "Toggle") toggleExt(extName);
                                                else if (modelData.label === "Delete") deleteExt(extName);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 40
                spacing: 8
                visible: extensions.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "📦"
                    font.pixelSize: 40
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No apps installed yet"
                    font.pixelSize: 14
                    color: root.textSecondary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Ask Whale AI to create extensions for you"
                    font.pixelSize: 12
                    color: root.textMuted
                }
            }
        }
    }

    function loadExtensions() {
        API.getExtensions(function(status, data) {
            if (status === 200 && Array.isArray(data)) {
                extensions = data;
            }
        });
    }

    function runExt(name) {
        API.runExtension(name, function(status, data) { loadExtensions(); });
    }

    function toggleExt(name) {
        API.toggleExtension(name, function(status, data) { loadExtensions(); });
    }

    function deleteExt(name) {
        API.deleteExtension(name, function(status, data) { loadExtensions(); });
    }
}
