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
        anchors.margins: Math.round(24 * root.sf)
        contentHeight: appsCol.height
        clip: true

        ColumnLayout {
            id: appsCol
            width: parent.width
            spacing: Math.round(18 * root.sf)

            // Extensions grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 16

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
                        property string extName: modelData.name || ""

                        ColumnLayout {
                            id: extCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Math.round(14 * root.sf)
                            spacing: Math.round(8 * root.sf)

                            RowLayout {
                                spacing: Math.round(8 * root.sf)

                                Text { text: ""; font.pixelSize: Math.round(18 * root.sf); font.family: root.iconFont; font.weight: Font.Black; color: root.textSecondary }

                                ColumnLayout {
                                    spacing: Math.round(2 * root.sf)
                                    Text {
                                        text: modelData.name || "Extension"
                                        font.pixelSize: Math.round(13 * root.sf)
                                        font.weight: Font.Medium
                                        color: root.textPrimary
                                    }
                                    Text {
                                        text: modelData.schedule || "Manual"
                                        font.pixelSize: Math.round(10 * root.sf)
                                        color: root.textMuted
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Status
                                Rectangle {
                                    width: Math.round(56 * root.sf); height: Math.round(22 * root.sf); radius: 11
                                    color: modelData.enabled ?
                                        Qt.rgba(0.13, 0.77, 0.37, 0.15) :
                                        Qt.rgba(1, 1, 1, 0.06)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.enabled ? "On" : "Off"
                                        font.pixelSize: Math.round(10 * root.sf)
                                        color: modelData.enabled ? root.accentGreen : root.textMuted
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description || "No description"
                                font.pixelSize: Math.round(12 * root.sf)
                                color: root.textSecondary
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            // Actions
                            RowLayout {
                                spacing: Math.round(6 * root.sf)

                                Repeater {
                                    model: [
                                        { label: "Run", color: root.accentBlue },
                                        { label: "Toggle", color: Qt.rgba(1,1,1,0.06) },
                                        { label: "Delete", color: Qt.rgba(1,1,1,0.06) },
                                        { label: "Edit", color: Qt.rgba(1,1,1,0.06) }
                                    ]

                                    delegate: Rectangle {
                                        width: Math.round(52 * root.sf); height: Math.round(26 * root.sf); radius: root.radiusSm
                                        color: modelData.color
                                        border.color: modelData.label !== "Run" ? root.borderColor : "transparent"
                                        border.width: modelData.label !== "Run" ? 1 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label === "Edit" ? "Edit ..." : modelData.label
                                            font.pixelSize: Math.round(10 * root.sf)
                                            color: modelData.label === "Run" ? "#ffffff" :
                                                   modelData.label === "Delete" ? root.accentRed :
                                                   modelData.label === "Edit" ? root.textMuted : root.textSecondary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: modelData.label === "Edit" ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                var name = extName;
                                                if (modelData.label === "Run") runExt(name);
                                                else if (modelData.label === "Toggle") toggleExt(name);
                                                else if (modelData.label === "Delete") deleteExt(name);
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
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: Math.round(8 * root.sf)
                visible: extensions.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: ""
                    font.pixelSize: Math.round(40 * root.sf); font.family: root.iconFont; font.weight: Font.Black; color: root.textSecondary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No extensions installed yet"
                    font.pixelSize: Math.round(14 * root.sf)
                    color: root.textSecondary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Ask TensorAgent AI to create extensions for you"
                    font.pixelSize: Math.round(12 * root.sf)
                    color: root.textMuted
                }
            }
        }
    }

    function loadExtensions() {
        API.getExtensions(function(status, data) {
            console.log("Extensions API status:", status, "data:", JSON.stringify(data));
            if (data && Array.isArray(data.extensions)) {
                extensions = data.extensions;
            } else if (Array.isArray(data)) {
                extensions = data;
            } else {
                console.log("Extensions: unexpected format");
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
