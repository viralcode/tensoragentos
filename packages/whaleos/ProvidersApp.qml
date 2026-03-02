import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property var providerData: []
    property bool loading: true

    // Ollama state
    property bool ollamaOnline: false
    property var ollamaModels: []
    property bool ollamaChecking: true
    property string ollamaPullModel: ""
    property bool ollamaPulling: false

    Component.onCompleted: { loadProviders(); checkOllama(); }

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
                        { type: "groq", name: "Groq", enabled: false, hasKey: false, models: ["llama-3.3-70b-versatile","mixtral-8x7b-32768"] }
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
                    root.showToast(providerType.charAt(0).toUpperCase() + providerType.slice(1) + " provider saved!", "success");
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

    // ── Ollama Functions ──
    function checkOllama() {
        ollamaChecking = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:11434/api/tags");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                ollamaChecking = false;
                if (xhr.status === 200) {
                    ollamaOnline = true;
                    try {
                        var data = JSON.parse(xhr.responseText);
                        var models = data.models || [];
                        var names = [];
                        for (var i = 0; i < models.length; i++) {
                            names.push({
                                name: models[i].name,
                                size: models[i].size ? (models[i].size / (1024*1024*1024)).toFixed(1) + " GB" : "",
                                modified: models[i].modified_at || ""
                            });
                        }
                        ollamaModels = names;
                    } catch(e) { ollamaModels = []; }
                } else {
                    ollamaOnline = false;
                    ollamaModels = [];
                }
            }
        };
        xhr.send();
    }

    function pullOllamaModel(modelName) {
        if (!modelName) { root.showToast("Enter a model name to pull", "error"); return; }
        ollamaPulling = true;
        root.showToast("Pulling " + modelName + "... This may take several minutes.", "info");

        // Use sysManager to run ollama pull (non-blocking notification)
        var result = sysManager.runCommand("ollama pull " + modelName + " 2>&1 | tail -5", "/home/ainux");
        ollamaPulling = false;

        try {
            var data = JSON.parse(result);
            if (data.exitCode === 0) {
                root.showToast(modelName + " downloaded successfully!", "success");
                checkOllama(); // Refresh model list
            } else {
                root.showToast("Pull failed: " + (data.stderr || data.stdout || "Unknown error"), "error");
            }
        } catch(e) {
            root.showToast("Pull completed. Refreshing...", "info");
            checkOllama();
        }
    }

    function deleteOllamaModel(modelName) {
        var result = sysManager.runCommand("ollama rm " + modelName + " 2>&1", "/home/ainux");
        try {
            var data = JSON.parse(result);
            if (data.exitCode === 0) {
                root.showToast(modelName + " removed", "success");
                checkOllama();
            } else {
                root.showToast("Failed to remove: " + (data.stderr || ""), "error");
            }
        } catch(e) {
            checkOllama();
        }
    }

    function connectOllamaToOpenWhale(modelName) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/providers/ollama/config");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast("Ollama " + modelName + " connected as active model!", "success");
                    loadProviders();
                } else {
                    root.showToast("Failed to connect Ollama (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        xhr.send(JSON.stringify({ apiKey: "ollama", selectedModel: modelName, enabled: true, host: "http://127.0.0.1:11434" }));
    }

    Flickable {
        anchors.fill: parent; anchors.margins: Math.round(24 * root.sf)
        contentHeight: mainCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainCol; width: parent.width; spacing: Math.round(18 * root.sf)

            Text { text: "AI Providers"; font.pixelSize: Math.round(22 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
            Text { text: "Configure cloud and local AI model providers"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            // ═══════════════════════════════════════════════════
            // ── Ollama Local Provider (Special Card) ──
            // ═══════════════════════════════════════════════════
            Rectangle {
                width: parent.width; height: ollamaCol.height + 28
                radius: root.radiusMd
                color: ollamaOnline ? Qt.rgba(0.05, 0.12, 0.08, 0.8) : root.bgCard
                border.color: ollamaOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.4) : root.borderColor
                border.width: 1

                Column {
                    id: ollamaCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Math.round(16 * root.sf); spacing: Math.round(12 * root.sf)

                    // Header
                    RowLayout {
                        width: parent.width; spacing: Math.round(12 * root.sf)

                        // Ollama icon
                        Rectangle {
                            width: Math.round(40 * root.sf); height: Math.round(40 * root.sf); radius: 10
                            color: ollamaOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.15) : Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent; text: "O"
                                font.pixelSize: Math.round(18 * root.sf); font.weight: Font.Black
                                color: ollamaOnline ? "#22c55e" : root.textMuted
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: Math.round(3 * root.sf)
                            Text {
                                text: "Ollama — Local LLM"
                                font.pixelSize: Math.round(15 * root.sf); font.weight: Font.DemiBold; color: root.textPrimary
                            }
                            Text {
                                text: ollamaChecking ? "Checking..." :
                                      ollamaOnline ? ollamaModels.length + " model" + (ollamaModels.length !== 1 ? "s" : "") + " installed — No API key needed" :
                                      "Offline — run: sudo systemctl start ollama"
                                font.pixelSize: Math.round(11 * root.sf)
                                color: ollamaOnline ? "#22c55e" : "#f59e0b"
                            }
                        }

                        // Status indicator
                        Rectangle {
                            width: Math.round(12 * root.sf); height: Math.round(12 * root.sf); radius: 6
                            color: ollamaChecking ? "#f59e0b" : (ollamaOnline ? "#22c55e" : "#ef4444")

                            SequentialAnimation on opacity {
                                running: ollamaChecking; loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }

                        // Refresh button
                        Rectangle {
                            width: Math.round(32 * root.sf); height: Math.round(32 * root.sf); radius: Math.round(8 * root.sf)
                            color: refreshMa.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                            Text { anchors.centerIn: parent; text: "R"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Bold; color: root.textSecondary }
                            MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: checkOllama() }
                        }
                    }

                    // ── Installed Models List ──
                    Rectangle {
                        width: parent.width; height: modelsListCol.height + 16; radius: Math.round(8 * root.sf)
                        color: Qt.rgba(0, 0, 0, 0.25); border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                        visible: ollamaOnline

                        Column {
                            id: modelsListCol; anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Math.round(8 * root.sf); spacing: Math.round(4 * root.sf)

                            // Header
                            RowLayout {
                                width: parent.width; spacing: Math.round(8 * root.sf)
                                Text { text: "Installed Models"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary; Layout.fillWidth: true }
                                Text { text: "SIZE"; font.pixelSize: Math.round(9 * root.sf); color: root.textMuted }
                                Rectangle { width: Math.round(70 * root.sf); height: 1; color: "transparent" }
                            }

                            // No models
                            Text {
                                visible: ollamaModels.length === 0
                                text: "No models installed yet. Pull one below!"
                                font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                                topPadding: Math.round(8 * root.sf); bottomPadding: Math.round(8 * root.sf)
                            }

                            // Model rows
                            Repeater {
                                model: ollamaModels
                                Rectangle {
                                    width: modelsListCol.width; height: Math.round(36 * root.sf); radius: Math.round(6 * root.sf)
                                    color: modelRowMa.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf)
                                        spacing: Math.round(8 * root.sf)

                                        // Model icon
                                        Rectangle {
                                            width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: 4
                                            color: "#22c55e"
                                        }

                                        // Model name
                                        Text {
                                            text: modelData.name; font.pixelSize: Math.round(12 * root.sf)
                                            font.weight: Font.Medium; font.family: "monospace"; color: "#ffffff"
                                            Layout.fillWidth: true
                                        }

                                        // Size
                                        Text {
                                            text: modelData.size; font.pixelSize: Math.round(10 * root.sf)
                                            color: root.textMuted
                                        }

                                        // Use button
                                        Rectangle {
                                            width: Math.round(48 * root.sf); height: Math.round(26 * root.sf); radius: Math.round(6 * root.sf)
                                            color: useMa.containsMouse ? Qt.darker(root.accentBlue, 1.2) : root.accentBlue
                                            Text { anchors.centerIn: parent; text: "Use"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                            MouseArea {
                                                id: useMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: connectOllamaToOpenWhale(modelData.name)
                                            }
                                        }

                                        // Delete button
                                        Rectangle {
                                            width: Math.round(26 * root.sf); height: Math.round(26 * root.sf); radius: Math.round(6 * root.sf)
                                            color: delMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.2) : Qt.rgba(1,1,1,0.04)
                                            Text { anchors.centerIn: parent; text: "X"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Bold; color: "#ef4444" }
                                            MouseArea {
                                                id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: deleteOllamaModel(modelData.name)
                                            }
                                        }
                                    }

                                    MouseArea { id: modelRowMa; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true; onClicked: mouse.accepted = false; onPressed: mouse.accepted = false; onReleased: mouse.accepted = false }
                                }
                            }
                        }
                    }

                    // ── Pull New Model ──
                    Rectangle {
                        width: parent.width; height: Math.round(38 * root.sf); radius: Math.round(8 * root.sf)
                        color: Qt.rgba(0, 0, 0, 0.2); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                        visible: ollamaOnline

                        RowLayout {
                            anchors.fill: parent; anchors.margins: Math.round(4 * root.sf); spacing: Math.round(6 * root.sf)

                            Rectangle {
                                Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: Math.round(6 * root.sf)
                                color: Qt.rgba(0, 0, 0, 0.3)

                                TextInput {
                                    id: pullInput; anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                                    color: "#fff"; font.pixelSize: Math.round(12 * root.sf); font.family: "monospace"
                                    clip: true; verticalAlignment: TextInput.AlignVCenter
                                    Keys.onReturnPressed: pullOllamaModel(pullInput.text.trim())
                                    Text {
                                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                        text: "e.g. llama3.2, mistral, codellama, phi3, gemma2..."
                                        color: Qt.rgba(1,1,1,0.25); font.pixelSize: Math.round(11 * root.sf)
                                        visible: !parent.text
                                    }
                                }
                            }

                            Rectangle {
                                width: pullBtnRow.width + Math.round(16 * root.sf); height: Math.round(30 * root.sf); radius: Math.round(6 * root.sf)
                                color: ollamaPulling ? Qt.rgba(1,1,1,0.06) : (pullBtnMa.containsMouse ? "#16a34a" : "#22c55e")
                                enabled: !ollamaPulling

                                Row {
                                    id: pullBtnRow; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                                    Text { text: ollamaPulling ? "..." : "+"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: ollamaPulling ? root.textMuted : "#fff"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: ollamaPulling ? "Pulling" : "Pull"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: ollamaPulling ? root.textMuted : "#fff"; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: pullBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { pullOllamaModel(pullInput.text.trim()); pullInput.text = ""; }
                                }
                            }
                        }
                    }

                    // Quick-pull popular models
                    Flow {
                        width: parent.width; spacing: Math.round(6 * root.sf)
                        visible: ollamaOnline && ollamaModels.length < 3

                        Text { text: "Popular:"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; anchors.verticalCenter: parent.children.length > 1 ? parent.children[1].verticalCenter : undefined }

                        Repeater {
                            model: ["llama3.2", "mistral", "codellama", "phi3", "gemma2", "qwen2.5"]
                            Rectangle {
                                width: quickLabel.width + 16; height: Math.round(24 * root.sf); radius: 12
                                color: quickMa.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                                border.color: Qt.rgba(1,1,1,0.1); border.width: 1

                                Text { id: quickLabel; anchors.centerIn: parent; text: modelData; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary; font.family: "monospace" }
                                MouseArea { id: quickMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pullOllamaModel(modelData) }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════
            // ── Cloud Providers ──
            // ═══════════════════════════════════════════════════
            Text { text: "Cloud Providers"; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary; topPadding: Math.round(4 * root.sf) }

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
