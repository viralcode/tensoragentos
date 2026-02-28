import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: settingsApp
    anchors.fill: parent
    color: "transparent"

    property string activeTab: "profile"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 180
            color: Qt.rgba(0, 0, 0, 0.2)

            // Right border
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 1
                color: root.borderColor
            }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 2

                Repeater {
                    model: [
                        { id: "profile",  icon: "👤", label: "Profile" },
                        { id: "users",    icon: "👥", label: "Users" },
                        { id: "ai",       icon: "🧠", label: "AI Engine" },
                        { id: "channels", icon: "📱", label: "Channels" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 36
                        radius: root.radiusSm
                        color: activeTab === modelData.id ? Qt.rgba(1, 1, 1, 0.08) :
                               tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 8

                            Text {
                                text: modelData.icon
                                font.pixelSize: 13
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: 13
                                color: activeTab === modelData.id ? root.textPrimary : root.textSecondary
                                font.weight: activeTab === modelData.id ? Font.Medium : Font.Normal
                            }
                        }

                        // Active indicator
                        Rectangle {
                            visible: activeTab === modelData.id
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 18
                            radius: 2
                            color: root.accentBlue
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activeTab = modelData.id
                        }
                    }
                }
            }
        }

        // ── Content Area ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Flickable {
                anchors.fill: parent
                anchors.margins: 20
                contentHeight: contentCol.height
                clip: true

                ColumnLayout {
                    id: contentCol
                    width: parent.width
                    spacing: 16

                    // ── Profile Tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: activeTab === "profile"

                        Text {
                            text: "Profile"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        // Avatar
                        Rectangle {
                            width: 72
                            height: 72
                            radius: 36
                            color: root.bgElevated
                            border.color: root.borderColor
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.currentUser.charAt(0).toUpperCase()
                                font.pixelSize: 28
                                font.weight: Font.Medium
                                color: root.textPrimary
                            }
                        }

                        // Username
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Username"; font.pixelSize: 12; color: root.textSecondary }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.maximumWidth: 320
                                height: 40
                                radius: root.radiusSm
                                color: root.bgElevated
                                border.color: root.borderColor
                                border.width: 1

                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: root.currentUser
                                    color: root.textPrimary
                                    font.pixelSize: 13
                                    readOnly: true
                                }
                            }
                        }

                        // Password
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Change Password"; font.pixelSize: 12; color: root.textSecondary }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.maximumWidth: 320
                                height: 40
                                radius: root.radiusSm
                                color: root.bgElevated
                                border.color: root.borderColor
                                border.width: 1

                                TextInput {
                                    id: newPassField
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: root.textPrimary
                                    font.pixelSize: 13
                                    echoMode: TextInput.Password
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "New password"
                                        color: root.textMuted
                                        font.pixelSize: 13
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 120
                                height: 36
                                radius: root.radiusSm
                                color: root.accentBlue

                                Text {
                                    anchors.centerIn: parent
                                    text: "Update"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: "#ffffff"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { /* TODO: change password API */ }
                                }
                            }
                        }
                    }

                    // ── Users Tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: activeTab === "users"

                        Text {
                            text: "User Management"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        Text {
                            text: "Manage who can access this system"
                            font.pixelSize: 13
                            color: root.textSecondary
                        }

                        // Current user card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 400
                            height: 56
                            radius: root.radiusMd
                            color: root.bgElevated
                            border.color: root.borderColor
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: root.accentBlue

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.currentUser.charAt(0).toUpperCase()
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: root.currentUser; font.pixelSize: 13; color: root.textPrimary; font.weight: Font.Medium }
                                    Text { text: "Administrator"; font.pixelSize: 11; color: root.textSecondary }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 60; height: 24; radius: 12
                                    color: Qt.rgba(0.13, 0.77, 0.37, 0.15)
                                    Text { anchors.centerIn: parent; text: "Active"; font.pixelSize: 10; color: root.accentGreen }
                                }
                            }
                        }
                    }

                    // ── AI Engine Tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: activeTab === "ai"

                        Text {
                            text: "AI Engine"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        Text {
                            text: "Configure AI providers and models"
                            font.pixelSize: 13
                            color: root.textSecondary
                        }

                        // Provider cards
                        Repeater {
                            model: [
                                { name: "Anthropic", icon: "🟣", models: "Claude 5, Claude Sonnet, Claude Haiku", key: "ANTHROPIC_API_KEY" },
                                { name: "OpenAI", icon: "🟢", models: "GPT-5, GPT-4o, o1", key: "OPENAI_API_KEY" },
                                { name: "Google", icon: "🔵", models: "Gemini 3, Gemini 2.0 Flash", key: "GOOGLE_API_KEY" },
                                { name: "DeepSeek", icon: "🔶", models: "DeepSeek Chat, Reasoner", key: "DEEPSEEK_API_KEY" },
                                { name: "Ollama", icon: "🦙", models: "Llama 3.2, Mistral, Qwen", key: "OLLAMA_URL" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.maximumWidth: 480
                                height: providerCol.height + 24
                                radius: root.radiusMd
                                color: root.bgElevated
                                border.color: root.borderColor
                                border.width: 1

                                ColumnLayout {
                                    id: providerCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 8

                                    RowLayout {
                                        spacing: 8
                                        Text { text: modelData.icon; font.pixelSize: 18 }
                                        Text { text: modelData.name; font.pixelSize: 14; font.weight: Font.Medium; color: root.textPrimary }
                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        text: modelData.models
                                        font.pixelSize: 11
                                        color: root.textMuted
                                    }

                                    // API Key input
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: root.radiusSm
                                        color: root.bgSurface
                                        border.color: root.borderColor
                                        border.width: 1

                                        TextInput {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: root.textPrimary
                                            font.pixelSize: 12
                                            echoMode: TextInput.Password
                                            clip: true

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.key === "OLLAMA_URL" ? "http://localhost:11434" : "Enter API key..."
                                                color: root.textMuted
                                                font.pixelSize: 12
                                                visible: !parent.text && !parent.activeFocus
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Channels Tab ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: activeTab === "channels"

                        Text {
                            text: "Channels"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        Text {
                            text: "Connect messaging platforms"
                            font.pixelSize: 13
                            color: root.textSecondary
                        }

                        Repeater {
                            model: [
                                { name: "WhatsApp", icon: "💬", desc: "Connect via QR code" },
                                { name: "Telegram", icon: "✈️", desc: "Connect with bot token" },
                                { name: "Discord", icon: "🎮", desc: "Connect with bot token" },
                                { name: "iMessage", icon: "💬", desc: "macOS bridge" },
                                { name: "Twitter/X", icon: "🐦", desc: "Connect via bird CLI" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.maximumWidth: 400
                                height: 56
                                radius: root.radiusMd
                                color: root.bgElevated
                                border.color: root.borderColor
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text { text: modelData.icon; font.pixelSize: 18 }

                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: modelData.name; font.pixelSize: 13; color: root.textPrimary; font.weight: Font.Medium }
                                        Text { text: modelData.desc; font.pixelSize: 11; color: root.textSecondary }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        width: 70; height: 28; radius: root.radiusSm
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        border.color: root.borderColor
                                        border.width: 1

                                        Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 11; color: root.textSecondary }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
