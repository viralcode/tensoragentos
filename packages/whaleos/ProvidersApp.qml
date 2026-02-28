import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: providersApp
    anchors.fill: parent
    color: "transparent"

    property var providers: [
        { type: "anthropic", name: "Anthropic", icon: "🟣", desc: "Claude 5, Claude Sonnet, Claude Haiku", configured: false, active: false },
        { type: "openai", name: "OpenAI", icon: "🟢", desc: "GPT-5, GPT-4o, o1-preview", configured: false, active: false },
        { type: "google", name: "Google", icon: "🔵", desc: "Gemini 3, Gemini 2.0 Flash", configured: false, active: false },
        { type: "deepseek", name: "DeepSeek", icon: "🔶", desc: "DeepSeek Chat, Reasoner", configured: false, active: false },
        { type: "qwen", name: "Qwen", icon: "🟠", desc: "Qwen 2.5, DashScope API", configured: false, active: false },
        { type: "groq", name: "Groq", icon: "⚡", desc: "Fast inference, Llama models", configured: false, active: false },
        { type: "together", name: "Together AI", icon: "🤝", desc: "Open-source models", configured: false, active: false },
        { type: "ollama", name: "Ollama", icon: "🦙", desc: "Local models — Llama, Mistral, Qwen", configured: false, active: false }
    ]

    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: provCol.height
        clip: true

        ColumnLayout {
            id: provCol
            width: parent.width
            spacing: 16

            Text {
                text: "AI Providers"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: root.textPrimary
            }

            Text {
                text: "Configure and manage AI model providers"
                font.pixelSize: 13
                color: root.textSecondary
            }

            // Provider grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: providers

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 200
                        height: providerInnerCol.height + 24
                        radius: root.radiusMd
                        color: root.bgElevated
                        border.color: modelData.active ? root.accentBlue : root.borderColor
                        border.width: modelData.active ? 2 : 1

                        ColumnLayout {
                            id: providerInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 10

                            // Header
                            RowLayout {
                                spacing: 8

                                Text { text: modelData.icon; font.pixelSize: 22 }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: root.textPrimary
                                    }
                                    Text {
                                        text: modelData.desc
                                        font.pixelSize: 10
                                        color: root.textMuted
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 180
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Status
                                Rectangle {
                                    width: 72; height: 24; radius: 12
                                    color: modelData.configured ?
                                        Qt.rgba(0.13, 0.77, 0.37, 0.15) :
                                        Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.configured ? "Ready" : "Setup"
                                        font.pixelSize: 10
                                        color: modelData.configured ? root.accentGreen : root.textMuted
                                    }
                                }
                            }

                            // API Key input
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: root.radiusSm
                                color: root.bgSurface
                                border.color: keyInput.activeFocus ? root.accentBlue : root.borderColor
                                border.width: 1

                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: root.textPrimary
                                    font.pixelSize: 12
                                    echoMode: TextInput.Password
                                    clip: true

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.type === "ollama" ? "http://localhost:11434" : "Enter API key..."
                                        color: root.textMuted
                                        font.pixelSize: 12
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }

                            // Actions
                            RowLayout {
                                spacing: 8

                                Rectangle {
                                    width: 60; height: 30; radius: root.radiusSm
                                    color: root.accentBlue

                                    Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: 11; color: "#ffffff"; font.weight: Font.Medium }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var config = {};
                                            config.apiKey = keyInput.text;
                                            config.enabled = true;
                                            API.saveProvider(modelData.type, config, function(s, d) {});
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 50; height: 30; radius: root.radiusSm
                                    color: Qt.rgba(1,1,1,0.06)
                                    border.color: root.borderColor; border.width: 1

                                    Text { anchors.centerIn: parent; text: "Test"; font.pixelSize: 11; color: root.textSecondary }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: API.testAI(modelData.type, function(s, d) {})
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Add provider
            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 480
                Layout.topMargin: 8
                height: 50
                radius: root.radiusMd
                color: "transparent"
                border.color: root.borderColor
                border.width: 1
                border.pixelAligned: true

                // Dashed border simulation
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: addMouse.containsMouse ? Qt.rgba(1,1,1,0.03) : "transparent"
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text { text: "+"; font.pixelSize: 18; color: root.textMuted }
                    Text { text: "Add Provider"; font.pixelSize: 13; color: root.textMuted }
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
