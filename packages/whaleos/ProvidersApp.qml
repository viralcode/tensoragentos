import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property var providerData: []
    property bool loading: true

    Component.onCompleted: loadProviders()

    function loadProviders() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/providers");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                loading = false;
                if (xhr.status === 200) {
                    try { var data = JSON.parse(xhr.responseText); providerData = data.providers || []; } catch(e) {}
                }
                if (providerData.length === 0) {
                    providerData = [
                        { type: "anthropic", name: "Anthropic", enabled: false, hasKey: false, models: ["claude-sonnet-4-20250514","claude-3-5-sonnet-20241022","claude-3-opus-20240229","claude-3-5-haiku-20241022"] },
                        { type: "openai", name: "OpenAI", enabled: false, hasKey: false, models: ["gpt-4o","gpt-4o-mini","gpt-4-turbo","gpt-4"] },
                        { type: "google", name: "Google", enabled: false, hasKey: false, models: ["gemini-2.0-flash","gemini-1.5-pro","gemini-1.5-flash"] },
                        { type: "deepseek", name: "DeepSeek", enabled: false, hasKey: false, models: ["deepseek-chat","deepseek-reasoner"] },
                        { type: "groq", name: "Groq", enabled: false, hasKey: false, models: ["llama-3.3-70b-versatile","mixtral-8x7b-32768"] },
                        { type: "ollama", name: "Ollama (Local)", enabled: false, hasKey: false, models: ["llama3.2","mistral","codellama"] }
                    ];
                }
            }
        };
        xhr.send();
    }

    function saveProvider(providerType, apiKey, selectedModel) {
        if (!apiKey) { root.showToast("Enter an API key for " + providerType, "error"); return; }
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/providers/" + providerType + "/config");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast(providerType.charAt(0).toUpperCase() + providerType.slice(1) + " provider saved successfully!", "success");
                    loadProviders();
                } else {
                    root.showToast("Failed to save " + providerType + " (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        xhr.send(JSON.stringify({ apiKey: apiKey, selectedModel: selectedModel, enabled: true }));
    }

    function testProvider(providerType, apiKey) {
        if (!apiKey) { root.showToast("Enter an API key to test", "error"); return; }
        root.showToast("Testing " + providerType + "...", "info");
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/setup/test-ai");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        if (d.ok) { root.showToast(providerType.charAt(0).toUpperCase() + providerType.slice(1) + " connection successful!", "success"); }
                        else { root.showToast("Test failed: " + (d.error || "Unknown error"), "error"); }
                    } catch(e) { root.showToast("Test failed: Invalid response", "error"); }
                } else {
                    root.showToast("Test failed (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        xhr.send(JSON.stringify({ provider: providerType, apiKey: apiKey }));
    }

    Flickable {
        anchors.fill: parent; anchors.margins: Math.round(24 * root.sf)
        contentHeight: mainCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainCol; width: parent.width; spacing: Math.round(18 * root.sf)

            Text { text: "AI Providers"; font.pixelSize: Math.round(22 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
            Text { text: "Configure API keys for AI model providers"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            Repeater {
                model: providerData

                Rectangle {
                    id: provCard; width: mainCol.width; height: provCol.height + 28
                    radius: root.radiusMd; color: root.bgCard
                    border.color: modelData.hasKey ? Qt.rgba(0.13,0.77,0.37,0.3) : root.borderColor; border.width: 1
                    clip: false

                    property string selectedModel: modelData.models && modelData.models.length > 0 ? modelData.models[0] : ""
                    property bool dropOpen: false

                    Column {
                        id: provCol; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Math.round(16 * root.sf); spacing: Math.round(10 * root.sf)

                        RowLayout {
                            width: parent.width; spacing: Math.round(10 * root.sf)
                            Rectangle {
                                width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: Qt.rgba(1,1,1,0.06)
                                Image { anchors.fill: parent; anchors.margins: Math.round(5 * root.sf); source: "icons/" + modelData.type + ".png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                            }
                            Column {
                                Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                                Text { text: modelData.name; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: root.textPrimary }
                                Text { text: modelData.hasKey ? "Connected" : "Not configured"; font.pixelSize: Math.round(11 * root.sf); color: modelData.hasKey ? root.accentGreen : root.textMuted }
                            }
                            Rectangle { width: Math.round(10 * root.sf); height: Math.round(10 * root.sf); radius: 5; color: modelData.hasKey ? root.accentGreen : root.textMuted }
                        }

                        // Model dropdown selector
                        Rectangle {
                            id: modelDropdown; width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0,0,0,0.3); border.color: provCard.dropOpen ? root.accentBlue : Qt.rgba(1,1,1,0.12); border.width: 1
                            visible: modelData.models && modelData.models.length > 0

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: Math.round(10 * root.sf); anchors.rightMargin: 10
                                Text { text: "AI Model:"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                Text { text: provCard.selectedModel; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#ffffff"; font.family: "monospace"; Layout.fillWidth: true }
                                Text { text: provCard.dropOpen ? "\u25B2" : "\u25BC"; font.pixelSize: Math.round(9 * root.sf); color: root.textMuted }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: provCard.dropOpen = !provCard.dropOpen }
                        }

                        // Dropdown overlay
                        Rectangle {
                            visible: provCard.dropOpen; z: 200
                            width: parent.width; height: dropdownCol.height + 8
                            radius: root.radiusSm; color: "#1a1a2e"
                            border.color: Qt.rgba(0.39,0.51,0.97,0.3); border.width: 1

                            Column {
                                id: dropdownCol; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.margins: Math.round(4 * root.sf); spacing: Math.round(1 * root.sf)

                                Repeater {
                                    model: modelData.models || []
                                    Rectangle {
                                        width: dropdownCol.width; height: Math.round(28 * root.sf); radius: 4
                                        color: dOptMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : (provCard.selectedModel === modelData ? Qt.rgba(0.39,0.51,0.97,0.12) : "transparent")

                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: Math.round(10 * root.sf); anchors.rightMargin: 10
                                            Text { text: modelData; font.pixelSize: Math.round(11 * root.sf); color: "#ffffff"; font.family: "monospace"; Layout.fillWidth: true }
                                            Text { text: "\u2713"; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.Bold; color: root.accentBlue; visible: provCard.selectedModel === modelData }
                                        }
                                        MouseArea {
                                            id: dOptMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { provCard.selectedModel = modelData; provCard.dropOpen = false; }
                                        }
                                    }
                                }
                            }
                        }

                        // API key + Save + Test
                        RowLayout {
                            width: parent.width; spacing: Math.round(6 * root.sf)
                            Rectangle {
                                Layout.fillWidth: true; height: Math.round(32 * root.sf); radius: root.radiusSm
                                color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput {
                                    id: keyInput; anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                                    color: "#ffffff"; font.pixelSize: Math.round(12 * root.sf); clip: true
                                    echoMode: TextInput.Password; verticalAlignment: TextInput.AlignVCenter
                                    Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: modelData.hasKey ? "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022" : "Enter API key..."; color: Qt.rgba(1,1,1,0.3); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text }
                                }
                            }
                            Rectangle {
                                width: Math.round(52 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#ffffff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveProvider(modelData.type, keyInput.text, provCard.selectedModel) }
                            }
                            Rectangle {
                                width: Math.round(44 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                                color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                                Text { anchors.centerIn: parent; text: "Test"; font.pixelSize: Math.round(11 * root.sf); color: "#e0e0e0" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: testProvider(modelData.type, keyInput.text) }
                            }
                        }
                    }
                }
            }
        }
    }
}
