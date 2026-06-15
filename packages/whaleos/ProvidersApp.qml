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
        xhr.setRequestHeader("Cookie", "owSessionId=" + root.sessionId);
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
        xhr.setRequestHeader("Cookie", "owSessionId=" + root.sessionId);
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
        xhr.setRequestHeader("Cookie", "owSessionId=" + root.sessionId);
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

    // Activate a specific provider model as the chat's active model
    function activateProvider(providerType, selectedModel) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/providers/" + providerType + "/config");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Cookie", "owSessionId=" + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast(providerType.charAt(0).toUpperCase() + providerType.slice(1) + " " + selectedModel + " activated!", "success");
                    loadProviders();
                } else {
                    root.showToast("Failed to activate (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        xhr.send(JSON.stringify({ selectedModel: selectedModel, enabled: true }));
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
                            var diskGB = models[i].size ? (models[i].size / (1024*1024*1024)).toFixed(1) : "?";
                            var paramSize = models[i].details && models[i].details.parameter_size ? models[i].details.parameter_size : "";
                            var ramGB = estimateRam(paramSize, diskGB);
                            names.push({
                                name: models[i].name,
                                size: diskGB + " GB",
                                ram: ramGB,
                                paramSize: paramSize,
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

    // Estimate RAM needed — roughly 1.2x the disk size for q4 quantized models
    function estimateRam(paramSize, diskGB) {
        // If we have parameter size like "7B", "3B", "0.5B"
        if (paramSize) {
            var match = paramSize.match(/([\d.]+)/);
            if (match) {
                var params = parseFloat(match[1]);
                if (params <= 1) return "~1 GB RAM";
                if (params <= 3) return "~2.5 GB RAM";
                if (params <= 4) return "~3.5 GB RAM";
                if (params <= 8) return "~5 GB RAM";
                if (params <= 14) return "~9 GB RAM";
                if (params <= 34) return "~20 GB RAM";
                if (params <= 70) return "~40 GB RAM";
                return "~" + Math.round(params * 0.6) + " GB RAM";
            }
        }
        // Fallback: estimate from disk size (RAM ≈ 1.2x disk)
        var d = parseFloat(diskGB);
        if (!isNaN(d) && d > 0) return "~" + (d * 1.2).toFixed(1) + " GB RAM";
        return "";
    }

    property real ollamaPullProgress: 0
    property string ollamaPullStatus: ""

    function pullOllamaModel(modelName) {
        if (!modelName) { root.showToast("Enter a model name to pull", "error"); return; }
        ollamaPulling = true;
        ollamaPullProgress = 0;
        ollamaPullStatus = "Downloading " + modelName + "...";
        root.showToast("Pulling " + modelName + "... Download will run in background.", "info");

        // Use Ollama HTTP API directly (non-blocking, async)
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:11434/api/pull");
        xhr.setRequestHeader("Content-Type", "application/json");

        // Track progress via periodic reads of partial response
        var lastLen = 0;
        xhr.onreadystatechange = function() {
            // Parse streaming NDJSON for progress
            if (xhr.readyState >= 3 && xhr.responseText.length > lastLen) {
                var newData = xhr.responseText.substring(lastLen);
                lastLen = xhr.responseText.length;
                var lines = newData.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].trim()) continue;
                    try {
                        var ev = JSON.parse(lines[i]);
                        if (ev.total && ev.completed) {
                            ollamaPullProgress = ev.completed / ev.total;
                            ollamaPullStatus = modelName + ": " + Math.round(ollamaPullProgress * 100) + "%";
                        } else if (ev.status) {
                            ollamaPullStatus = ev.status;
                        }
                    } catch(e) {}
                }
            }
            if (xhr.readyState === 4) {
                ollamaPulling = false;
                ollamaPullProgress = 0;
                ollamaPullStatus = "";
                if (xhr.status === 200) {
                    root.showToast(modelName + " downloaded successfully!", "success");
                    checkOllama();
                } else {
                    root.showToast("Pull failed (HTTP " + xhr.status + ")", "error");
                    checkOllama();
                }
            }
        };
        xhr.send(JSON.stringify({ name: modelName }));
    }

    // Property to track pending delete operation
    property string pendingDeleteModel: ""

    // ── Async signal handler for ollama delete ──
    Connections {
        target: sysManager
        function onCommandOutput(cmdId, data) {
            // Capture output from delete command if needed
        }
        function onCommandFinished(cmdId, exitCode, cwd) {
            if (pendingDeleteModel.length > 0) {
                if (exitCode === 0) {
                    root.showToast(pendingDeleteModel + " removed", "success");
                } else {
                    root.showToast("Failed to remove " + pendingDeleteModel, "error");
                }
                pendingDeleteModel = "";
                checkOllama();
            }
        }
    }

    function deleteOllamaModel(modelName) {
        // ASYNC: non-blocking model deletion
        pendingDeleteModel = modelName;
        sysManager.runCommandAsync("ollama rm " + modelName + " 2>&1", "/home/ainux");
    }

    function connectOllamaToOpenWhale(modelName) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/providers/ollama/config");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Cookie", "owSessionId=" + root.sessionId);
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

            // ═══════════════════════════════════════════════════
            // ── Ollama Local Provider ──

            // ═══════════════════════════════════════════════════
            // ── Ollama Local Provider ──
            // ═══════════════════════════════════════════════════
            Rectangle {
                width: parent.width; height: ollamaCol.height + Math.round(40 * root.sf)
                radius: Math.round(14 * root.sf)
                color: root.bgCard
                border.color: ollamaOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.25) : root.borderColor
                border.width: 1

                // Subtle gradient accent at top
                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: Math.round(3 * root.sf); radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: ollamaOnline ? "#22c55e" : "#64748b" }
                        GradientStop { position: 0.5; color: ollamaOnline ? "#16a34a" : "#475569" }
                        GradientStop { position: 1.0; color: ollamaOnline ? "#15803d" : "#334155" }
                    }
                }

                Column {
                    id: ollamaCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Math.round(20 * root.sf)
                    anchors.topMargin: Math.round(24 * root.sf)
                    spacing: Math.round(16 * root.sf)

                    // ── Header Row ──
                    RowLayout {
                        width: parent.width; spacing: Math.round(14 * root.sf)

                        // Ollama icon
                        Rectangle {
                            width: Math.round(44 * root.sf); height: Math.round(44 * root.sf); radius: Math.round(12 * root.sf)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: ollamaOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.2) : Qt.rgba(1, 1, 1, 0.08) }
                                GradientStop { position: 1.0; color: ollamaOnline ? Qt.rgba(0.08, 0.5, 0.24, 0.15) : Qt.rgba(1, 1, 1, 0.03) }
                            }

                            Canvas {
                                id: ollamaIconCanvas
                                anchors.fill: parent
                                // Watch ollamaOnline via property to repaint when state changes
                                property bool online: ollamaOnline
                                onOnlineChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.fillStyle = online ? "#22c55e" : "#94a3b8";
                                    ctx.font = "bold " + Math.round(17 * root.sf) + "px sans-serif";
                                    ctx.textAlign = "center";
                                    ctx.textBaseline = "middle";
                                    ctx.fillText("Ol", width / 2, height / 2 + 1);
                                }
                                Component.onCompleted: requestPaint()
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: Math.round(4 * root.sf)
                            Text {
                                text: "Ollama"
                                font.pixelSize: Math.round(16 * root.sf); font.weight: Font.Bold; color: root.textPrimary
                            }
                            Text {
                                text: "Run LLMs locally — no API key needed"
                                font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                            }
                        }

                        // Status pill
                        Rectangle {
                            width: statusPillText.width + Math.round(20 * root.sf)
                            height: Math.round(26 * root.sf); radius: Math.round(13 * root.sf)
                            color: ollamaChecking ? Qt.rgba(0.96, 0.62, 0.04, 0.12) :
                                   ollamaOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.12) :
                                   Qt.rgba(0.94, 0.27, 0.27, 0.12)
                            border.color: ollamaChecking ? Qt.rgba(0.96, 0.62, 0.04, 0.25) :
                                          ollamaOnline ? Qt.rgba(0.13, 0.77, 0.37, 0.25) :
                                          Qt.rgba(0.94, 0.27, 0.27, 0.25)
                            border.width: 1

                            Row {
                                anchors.centerIn: parent; spacing: Math.round(6 * root.sf)

                                Rectangle {
                                    width: Math.round(7 * root.sf); height: Math.round(7 * root.sf); radius: Math.round(4 * root.sf)
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: ollamaChecking ? "#f59e0b" : (ollamaOnline ? "#22c55e" : "#ef4444")

                                    SequentialAnimation on opacity {
                                        running: ollamaChecking; loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 500 }
                                        NumberAnimation { to: 1.0; duration: 500 }
                                    }
                                }

                                Text {
                                    id: statusPillText; anchors.verticalCenter: parent.verticalCenter
                                    text: ollamaChecking ? "Checking" : (ollamaOnline ? "Online" : "Offline")
                                    font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold
                                    color: ollamaChecking ? "#f59e0b" : (ollamaOnline ? "#22c55e" : "#ef4444")
                                }
                            }
                        }

                        // Refresh button
                        Rectangle {
                            width: Math.round(34 * root.sf); height: Math.round(34 * root.sf); radius: Math.round(10 * root.sf)
                            color: refreshMa.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                            border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                            Text {
                                anchors.centerIn: parent; text: "↻"
                                font.pixelSize: Math.round(16 * root.sf); color: root.textSecondary
                            }
                            MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: checkOllama() }
                        }
                    }

                    // ── Model count info ──
                    Text {
                        visible: ollamaOnline
                        text: ollamaModels.length + " model" + (ollamaModels.length !== 1 ? "s" : "") + " installed"
                        font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium
                        color: "#22c55e"
                    }

                    // ── Offline hint ──
                    Rectangle {
                        visible: !ollamaOnline && !ollamaChecking
                        width: parent.width; height: offlineCol.height + Math.round(20 * root.sf)
                        radius: Math.round(8 * root.sf)
                        color: Qt.rgba(0.94, 0.27, 0.27, 0.06)
                        border.color: Qt.rgba(0.94, 0.27, 0.27, 0.12); border.width: 1

                        Column {
                            id: offlineCol; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Ollama service is not running"
                                font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium; color: "#fca5a5"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Run: sudo systemctl start ollama"
                                font.pixelSize: Math.round(11 * root.sf); font.family: "monospace"; color: root.textMuted
                            }
                        }
                    }

                    // ── Installed Models List ──
                    Rectangle {
                        width: parent.width; height: modelsListCol.height + Math.round(20 * root.sf)
                        radius: Math.round(10 * root.sf)
                        color: Qt.rgba(0, 0, 0, 0.2); border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                        visible: ollamaOnline

                        Column {
                            id: modelsListCol; anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf)
                            spacing: Math.round(6 * root.sf)

                            // Header
                            RowLayout {
                                width: parent.width; spacing: Math.round(10 * root.sf)
                                Text {
                                    text: "Installed Models"
                                    font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: root.textSecondary
                                    Layout.fillWidth: true
                                }
                                Text { text: "SIZE"; font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: root.textMuted; Layout.rightMargin: Math.round(90 * root.sf) }
                            }

                            // Divider
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

                            // No models
                            Column {
                                visible: ollamaModels.length === 0; width: parent.width
                                spacing: Math.round(6 * root.sf)
                                topPadding: Math.round(12 * root.sf); bottomPadding: Math.round(12 * root.sf)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No models installed yet"
                                    font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium; color: root.textSecondary
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Pull a model below to get started"
                                    font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                                }
                            }

                            // Model rows
                            Repeater {
                                model: ollamaModels
                                Rectangle {
                                    width: modelsListCol.width; height: Math.round(42 * root.sf); radius: Math.round(8 * root.sf)
                                    color: modelRowMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(10 * root.sf); anchors.rightMargin: Math.round(10 * root.sf)
                                        spacing: Math.round(10 * root.sf)

                                        // Model dot
                                        Rectangle {
                                            width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: 4
                                            color: "#22c55e"
                                        }

                                        // Model name
                                        Text {
                                            text: modelData.name
                                            font.pixelSize: Math.round(13 * root.sf)
                                            font.weight: Font.Medium; font.family: "monospace"; color: "#ffffff"
                                            Layout.fillWidth: true
                                        }

                                        // Size + RAM
                                        Column {
                                            Layout.preferredWidth: Math.round(100 * root.sf)
                                            spacing: 1
                                            Text {
                                                text: modelData.size
                                                font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                                                anchors.right: parent.right
                                            }
                                            Text {
                                                text: modelData.ram || ""
                                                font.pixelSize: Math.round(9 * root.sf)
                                                color: {
                                                    var ram = modelData.ram || "";
                                                    var m = ram.match(/[\d.]+/);
                                                    if (m) {
                                                        var gb = parseFloat(m[0]);
                                                        if (gb <= 3) return "#22c55e";   // green — fits easy
                                                        if (gb <= 5) return "#f59e0b";   // amber — tight
                                                        return "#ef4444";                 // red — may not fit
                                                    }
                                                    return root.textMuted;
                                                }
                                                anchors.right: parent.right
                                                visible: text !== ""
                                            }
                                        }

                                        // Use button
                                        Rectangle {
                                            width: Math.round(54 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(8 * root.sf)
                                            color: useMa.containsMouse ? Qt.darker(root.accentBlue, 1.15) : root.accentBlue

                                            Text {
                                                anchors.centerIn: parent; text: "Use"
                                                font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff"
                                            }
                                            MouseArea {
                                                id: useMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: connectOllamaToOpenWhale(modelData.name)
                                            }
                                        }

                                        // Delete button
                                        Rectangle {
                                            width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(8 * root.sf)
                                            color: delMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.15) : Qt.rgba(1,1,1,0.04)
                                            border.color: delMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.2) : "transparent"; border.width: 1

                                            Text {
                                                anchors.centerIn: parent; text: "✕"
                                                font.pixelSize: Math.round(11 * root.sf); color: "#ef4444"
                                            }
                                            MouseArea {
                                                id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: deleteOllamaModel(modelData.name)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: modelRowMa; anchors.fill: parent; hoverEnabled: true
                                        propagateComposedEvents: true
                                        onClicked: function(mouse) { mouse.accepted = false; }
                                        onPressed: function(mouse) { mouse.accepted = false; }
                                        onReleased: function(mouse) { mouse.accepted = false; }
                                    }
                                }
                            }
                        }
                    }

                    // ── Pull New Model ──
                    Rectangle {
                        width: parent.width; height: Math.round(44 * root.sf); radius: Math.round(10 * root.sf)
                        color: Qt.rgba(0, 0, 0, 0.2); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                        visible: ollamaOnline

                        RowLayout {
                            anchors.fill: parent; anchors.margins: Math.round(6 * root.sf); spacing: Math.round(8 * root.sf)

                            Rectangle {
                                Layout.fillWidth: true; height: Math.round(32 * root.sf); radius: Math.round(8 * root.sf)
                                color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                                TextInput {
                                    id: pullInput; anchors.fill: parent; anchors.leftMargin: Math.round(12 * root.sf); anchors.rightMargin: Math.round(12 * root.sf)
                                    color: "#fff"; font.pixelSize: Math.round(13 * root.sf); font.family: "monospace"
                                    clip: true; verticalAlignment: TextInput.AlignVCenter
                                    Keys.onReturnPressed: pullOllamaModel(pullInput.text.trim())

                                    Text {
                                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                        text: "Model name (e.g. llama3.2, mistral)"
                                        color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf)
                                        visible: !parent.text
                                    }
                                }
                            }

                            Rectangle {
                                width: pullBtnRow.width + Math.round(20 * root.sf); height: Math.round(32 * root.sf)
                                radius: Math.round(8 * root.sf)
                                color: ollamaPulling ? Qt.rgba(1,1,1,0.06) : (pullBtnMa.containsMouse ? "#16a34a" : "#22c55e")
                                enabled: !ollamaPulling

                                Row {
                                    id: pullBtnRow; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
                                    Text {
                                        text: ollamaPulling ? "Pulling..." : "↓ Pull"
                                        font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold
                                        color: ollamaPulling ? root.textMuted : "#fff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: pullBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { pullOllamaModel(pullInput.text.trim()); pullInput.text = ""; }
                                }
                            }
                        }
                    }

                    // ── Download Progress Bar ──
                    Rectangle {
                        width: parent.width; height: Math.round(40 * root.sf)
                        radius: Math.round(8 * root.sf)
                        color: Qt.rgba(0.13, 0.77, 0.37, 0.08)
                        border.color: Qt.rgba(0.13, 0.77, 0.37, 0.2)
                        visible: ollamaPulling

                        Column {
                            anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                            spacing: Math.round(4 * root.sf)

                            Text {
                                text: ollamaPullStatus
                                font.pixelSize: Math.round(10 * root.sf); color: "#22c55e"
                                width: parent.width; elide: Text.ElideRight
                            }
                            Rectangle {
                                width: parent.width; height: Math.round(6 * root.sf)
                                radius: Math.round(3 * root.sf); color: Qt.rgba(1,1,1,0.08)
                                Rectangle {
                                    width: parent.width * ollamaPullProgress
                                    height: parent.height; radius: parent.radius
                                    color: "#22c55e"
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    // ── Quick-pull popular models ──
                    Column {
                        width: parent.width; spacing: Math.round(8 * root.sf)
                        visible: ollamaOnline

                        Text {
                            text: "Popular Models"
                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: root.textMuted
                        }

                        Flow {
                            width: parent.width; spacing: Math.round(8 * root.sf)

                            Repeater {
                                model: [
                                    { name: "qwen2.5:0.5b", desc: "Alibaba 0.5B", ram: "~1 GB" },
                                    { name: "gemma2:2b", desc: "Google 2B", ram: "~2.5 GB" },
                                    { name: "llama3.2", desc: "Meta 3B", ram: "~2.5 GB" },
                                    { name: "phi3", desc: "Microsoft 3.8B", ram: "~3.5 GB" },
                                    { name: "mistral", desc: "7B", ram: "~5 GB" },
                                    { name: "codellama", desc: "Code 7B", ram: "~5 GB" },
                                    { name: "qwen2.5", desc: "Alibaba 7B", ram: "~5 GB" }
                                ]

                                Rectangle {
                                    width: quickCol.width + Math.round(24 * root.sf); height: Math.round(38 * root.sf)
                                    radius: Math.round(10 * root.sf)
                                    color: quickMa.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                                    border.color: quickMa.containsMouse ? Qt.rgba(0.13, 0.77, 0.37, 0.3) : Qt.rgba(1,1,1,0.08)
                                    border.width: 1

                                    Row {
                                        id: quickCol; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)

                                        Text {
                                            text: modelData.name
                                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold
                                            font.family: "monospace"; color: "#e2e8f0"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.desc
                                            font.pixelSize: Math.round(9 * root.sf); color: root.textMuted
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.ram || ""
                                            font.pixelSize: Math.round(8 * root.sf)
                                            color: {
                                                var m = (modelData.ram || "").match(/[\d.]+/);
                                                if (m) { var g = parseFloat(m[0]); return g <= 3 ? "#22c55e" : g <= 5 ? "#f59e0b" : "#ef4444"; }
                                                return root.textMuted;
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: quickMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: pullOllamaModel(modelData.name)
                                    }
                                }
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
                model: providerData.filter(function(p) { return p.type !== "ollama"; })

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
                                width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10
                                color: Qt.rgba(1,1,1,0.06)

                                property string pType: modelData.type
                                property color brandColor: pType === "anthropic" ? "#d97706" :
                                                           pType === "openai" ? "#10a37f" :
                                                           pType === "google" ? "#4285f4" :
                                                           pType === "deepseek" ? "#3b82f6" :
                                                           pType === "groq" ? "#f4722b" : "#64748b"

                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        var w = width, h = height;
                                        ctx.clearRect(0, 0, w, h);

                                        var t = parent.pType;
                                        var c = parent.brandColor;

                                        // Draw brand letter
                                        ctx.fillStyle = c;
                                        ctx.font = "bold " + Math.round(18 * root.sf) + "px sans-serif";
                                        ctx.textAlign = "center";
                                        ctx.textBaseline = "middle";

                                        var letter = t === "anthropic" ? "A" :
                                                     t === "openai" ? "⬡" :
                                                     t === "google" ? "G" :
                                                     t === "deepseek" ? "D" :
                                                     t === "groq" ? "G" : "?";
                                        ctx.fillText(letter, w/2, h/2 + 1);
                                    }
                                    Component.onCompleted: requestPaint()
                                }
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

                        // Activate button — switch chat to use this model
                        Rectangle {
                            width: parent.width; height: Math.round(32 * root.sf); radius: root.radiusSm
                            color: {
                                if (activateMa.containsMouse) return Qt.darker("#22c55e", 1.15);
                                return modelData.hasKey ? "#22c55e" : Qt.rgba(1,1,1,0.08);
                            }

                            RowLayout {
                                anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
                                Text { text: "⚡"; font.pixelSize: Math.round(12 * root.sf) }
                                Text {
                                    text: "Use " + provCard.selectedModel
                                    font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold
                                    color: modelData.hasKey ? "#ffffff" : root.textMuted
                                }
                            }
                            MouseArea {
                                id: activateMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!modelData.hasKey && !keyInput.text) {
                                        root.showToast("Enter an API key first for " + modelData.name, "error");
                                    } else {
                                        // If user typed a key, save it first
                                        if (keyInput.text) {
                                            saveProvider(modelData.type, keyInput.text, provCard.selectedModel);
                                        }
                                        activateProvider(modelData.type, provCard.selectedModel);
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
