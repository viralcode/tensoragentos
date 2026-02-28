import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: chatBar
    height: chatExpanded ? Math.min(380, parent.height - 80) : 48
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

                Canvas {
                    width: 16; height: 16
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0,0,16,16);
                        ctx.fillStyle = "#60a5fa";
                        ctx.beginPath(); ctx.moveTo(2,2); ctx.lineTo(14,2); ctx.lineTo(14,10);
                        ctx.lineTo(6,10); ctx.lineTo(4,13); ctx.lineTo(4,10); ctx.lineTo(2,10);
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = "#ffffff";
                        ctx.fillRect(5,5,2,2); ctx.fillRect(9,5,2,2);
                    }
                }
                Text {
                    text: "TensorAgent AI"
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

                    Canvas {
                        anchors.centerIn: parent; width: 12; height: 12
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0,0,12,12);
                            ctx.strokeStyle = "#94a3b8"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
                            ctx.beginPath(); ctx.moveTo(4,1); ctx.lineTo(8,1); ctx.stroke();
                            ctx.strokeRect(2,2,8,9);
                            ctx.beginPath(); ctx.moveTo(5,4); ctx.lineTo(5,9); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(7,4); ctx.lineTo(7,9); ctx.stroke();
                        }
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
                        text: modelData.role === "user" ? "You" : "TensorAgent AI"
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

            // Chat icon (collapsed only)
            Canvas {
                width: 16; height: 16
                visible: !chatExpanded
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0,0,16,16);
                    ctx.fillStyle = "#60a5fa";
                    ctx.beginPath(); ctx.moveTo(2,2); ctx.lineTo(14,2); ctx.lineTo(14,10);
                    ctx.lineTo(6,10); ctx.lineTo(4,13); ctx.lineTo(4,10); ctx.lineTo(2,10);
                    ctx.closePath(); ctx.fill();
                    ctx.fillStyle = "#ffffff";
                    ctx.fillRect(5,5,2,2); ctx.fillRect(9,5,2,2);
                }
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
                    text: "Ask TensorAgent AI anything..."
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
