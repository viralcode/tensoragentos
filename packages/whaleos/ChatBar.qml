import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: chatBar
    height: chatExpanded ? 380 : 48
    radius: root.radiusLg
    color: Qt.rgba(0.1, 0.1, 0.1, 0.8)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    clip: true

    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    property bool chatExpanded: false
    property bool isSending: false
    property var messages: []

    // ── Chat Messages Area (visible when expanded) ──
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: inputRow.top
        anchors.margins: 1
        visible: chatExpanded
        clip: true

        // Header
        Rectangle {
            id: chatHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38
            color: Qt.rgba(0.08, 0.08, 0.08, 0.9)
            radius: root.radiusLg

            // Bottom corners shouldn't be rounded
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8

                Text {
                    text: "🐋"
                    font.pixelSize: 14
                }
                Text {
                    text: "Whale AI"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: root.textPrimary
                }

                Item { Layout.fillWidth: true }

                // Clear chat
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: clearMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "🗑"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { chatBar.messages = []; }
                    }
                }

                // Collapse
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: collapseMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "▾"
                        font.pixelSize: 14
                        color: root.textSecondary
                    }

                    MouseArea {
                        id: collapseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chatExpanded = false
                    }
                }
            }
        }

        // Messages list
        ListView {
            id: messageList
            anchors.top: chatHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            model: chatBar.messages
            spacing: 8
            clip: true

            delegate: Rectangle {
                width: messageList.width
                height: msgContent.height + 16
                radius: root.radiusMd
                color: modelData.role === "user" ? Qt.rgba(0.23, 0.51, 0.96, 0.12) : Qt.rgba(1, 1, 1, 0.04)

                ColumnLayout {
                    id: msgContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 2

                    Text {
                        text: modelData.role === "user" ? "You" : "Whale AI"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: modelData.role === "user" ? root.accentBlue : root.accentGreen
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.content
                        font.pixelSize: 13
                        color: root.textPrimary
                        wrapMode: Text.WordWrap
                        lineHeight: 1.4
                    }
                }
            }

            onCountChanged: {
                Qt.callLater(function() { messageList.positionViewAtEnd(); });
            }
        }
    }

    // ── Input Row ──
    Rectangle {
        id: inputRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        height: 40
        radius: root.radiusMd
        color: root.bgSurface
        border.color: chatInput.activeFocus ? root.accentBlue : root.borderColor
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 6
            spacing: 8

            // Whale icon (collapsed only)
            Text {
                text: "🐋"
                font.pixelSize: 14
                visible: !chatExpanded
            }

            TextInput {
                id: chatInput
                Layout.fillWidth: true
                verticalAlignment: TextInput.AlignVCenter
                color: root.textPrimary
                font.pixelSize: 13
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ask Whale AI anything..."
                    color: root.textMuted
                    font.pixelSize: 13
                    visible: !parent.text && !parent.activeFocus
                }

                onActiveFocusChanged: {
                    if (activeFocus && !chatExpanded) chatExpanded = true;
                }

                Keys.onReturnPressed: sendMessage()
            }

            // Send button
            Rectangle {
                width: 30
                height: 30
                radius: 8
                color: chatInput.text.trim() ?
                    (sendMouse.pressed ? Qt.darker(root.accentBlue, 1.2) : root.accentBlue) :
                    Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: isSending ? "·" : "↑"
                    font.pixelSize: isSending ? 18 : 14
                    font.weight: Font.Bold
                    color: chatInput.text.trim() ? "#ffffff" : root.textMuted
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sendMessage()
                }
            }
        }
    }

    function sendMessage() {
        var msg = chatInput.text.trim();
        if (!msg || isSending) return;

        chatExpanded = true;
        var msgs = messages.slice();
        msgs.push({ role: "user", content: msg });
        messages = msgs;
        chatInput.text = "";
        isSending = true;

        API.chat(msg, function(status, data) {
            isSending = false;
            var msgs2 = messages.slice();
            if (status === 200 && data.response) {
                msgs2.push({ role: "assistant", content: data.response });
            } else if (status === 200 && data.message) {
                msgs2.push({ role: "assistant", content: data.message });
            } else {
                msgs2.push({ role: "assistant", content: "Error: " + (data.error || "Unknown error") });
            }
            messages = msgs2;
        });
    }
}
