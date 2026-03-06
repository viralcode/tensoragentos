import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: chatBar
    height: chatExpanded ? (chatFullScreen ? parent.height : Math.min(Math.round(450 * root.sf), parent.height - Math.round(70 * root.sf))) : Math.round(60 * root.sf)
    radius: root.radiusLg
    color: "transparent"
    clip: true
    z: 10

    // PERF: No height animation — height change repaints the entire panel on every frame
    // on the software renderer (pixman). Use instant snap instead.
    // Visual smoothness comes from the content fading in (see chatContentOpacity below).

    property bool chatExpanded: false
    property bool chatFullScreen: false
    // Fade in content when expanding (cheap — only affects opacity, not layout)
    property real chatContentOpacity: chatExpanded ? 1.0 : 0.0
    Behavior on chatContentOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    property bool isSending: false
    property var messages: []
    property string selectedAgent: "main"
    property var agentList: [{ id: "main", name: "TensorAgent AI", description: "Default AI" }]
    property bool showAgentPicker: false
    // Streaming state
    property string streamingContent: ""
    property bool isStreaming: false
    property var streamingSteps: []
    property var activePlan: null
    property var commandSuggestions: ["/help", "/new", "/status", "/think", "/usage", "/compact"]
    property bool showSuggestions: false
    property var chatHistory: []
    property int historyIndex: -1

    // Real-time active model (polled from /api/providers)
    property string activeModel: ""
    property string activeProvider: ""

    // Multi-agent state
    property var liveAgentRuns: ({})
    property bool showFanOutModal: false
    property var fanOutChecked: ({})

    // Per-conversation work folder
    property string currentWorkFolder: ""

    // Generate a slug from the first message for a readable folder name
    function generateWorkFolder(firstMsg) {
        // Take first ~30 chars, lowercase, replace non-alphanum with underscore
        var slug = firstMsg.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").substring(0, 30);
        if (!slug) slug = "task";
        // Add timestamp for uniqueness
        var d = new Date();
        var ts = d.getFullYear() + "-" +
            ("0" + (d.getMonth() + 1)).slice(-2) + "-" +
            ("0" + d.getDate()).slice(-2) + "_" +
            ("0" + d.getHours()).slice(-2) +
            ("0" + d.getMinutes()).slice(-2);
        return slug + "_" + ts;
    }

    // Start a new conversation with a fresh work folder
    function startNewConversation() {
        currentWorkFolder = "";
        messages = [];
        streamingContent = "";
        streamingSteps = [];
        activePlan = null;
    }

    // Simple markdown to StyledText converter
    function mdToStyled(text) {
        if (!text) return "";
        var s = text;
        // Escape HTML
        s = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        // Code blocks: ```...``` -> monospace
        s = s.replace(/```[\s\S]*?```/g, function(m) {
            var code = m.replace(/```\w*\n?/g, "").replace(/```/g, "");
            return "<br><font color='#94a3b8' face='monospace'>" + code.replace(/\n/g, "<br>") + "</font><br>";
        });
        // Inline code
        s = s.replace(/`([^`]+)`/g, "<font color='#93c5fd' face='monospace'>$1</font>");
        // Bold
        s = s.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
        // Italic
        s = s.replace(/\*([^*]+)\*/g, "<i>$1</i>");
        // Bullet points
        s = s.replace(/\n- /g, "\n• ");
        s = s.replace(/\n(\d+)\. /g, "\n$1. ");
        // Line breaks
        s = s.replace(/\n/g, "<br>");
        // Clean branding
        s = s.replace(/OpenWhale/g, "TensorAgent AI");
        s = s.replace(/AInux OS/g, "TensorAgent OS");
        s = s.replace(/AInux/g, "TensorAgent OS");
        return s;
    }

    Component.onCompleted: { loadAgents(); loadHistory(); loadActiveModel(); }

    // Poll active model every 10s
    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: loadActiveModel()
    }

    function loadActiveModel() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/providers");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    var provs = resp.providers || [];
                    for (var i = 0; i < provs.length; i++) {
                        if (provs[i].enabled && provs[i].hasKey) {
                            activeProvider = provs[i].name || provs[i].type;
                            activeModel = provs[i].selectedModel || provs[i].models[0] || "";
                            return;
                        }
                    }
                    activeModel = "";
                    activeProvider = "";
                } catch(e) {}
            }
        };
        xhr.send();
    }

    function loadAgents() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/agents");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    agentList = resp.agents || resp || [];
                } catch(e) {}
            }
        };
        xhr.send();
    }

    function loadHistory() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/chat/history");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    var hist = d.messages || d || [];
                    if (hist.length > 0) messages = hist;
                } catch(e) {}
            }
        };
        xhr.send();
    }

    function getAgentName() {
        for (var i = 0; i < agentList.length; i++) {
            if (agentList[i].id === selectedAgent) return agentList[i].name;
        }
        return "TensorAgent AI";
    }

    function getWorkingStatus() {
        // Dynamic status like dashboard: Running tool, Generating, Thinking (round N)
        for (var i = streamingSteps.length - 1; i >= 0; i--) {
            if (streamingSteps[i].type === "tool" && streamingSteps[i].status === "running") {
                var label = streamingSteps[i].name || "tool";
                return "Running: " + label;
            }
        }
        if (streamingContent.length > 0) return "Generating...";
        for (var j = 0; j < streamingSteps.length; j++) {
            if (streamingSteps[j].type === "thinking" && !streamingSteps[j].done) {
                if (streamingSteps[j].iteration > 1) return "Thinking (round " + streamingSteps[j].iteration + ")...";
                return "Thinking...";
            }
        }
        if (streamingSteps.length > 0) return "Processing results...";
        return "Thinking...";
    }

    // ── Glass background (only when expanded) ──
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        visible: chatExpanded
        opacity: chatContentOpacity
        color: Qt.rgba(0.07, 0.07, 0.11, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
    }

    // ── Chat Header (expanded) ──
    Rectangle {
        id: chatHeader
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(52 * root.sf); visible: chatExpanded
        opacity: chatContentOpacity
        color: Qt.rgba(0.06, 0.06, 0.10, 0.98); radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(16 * root.sf); anchors.rightMargin: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)

            Canvas {
                width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                property real s: root.sf
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                    ctx.save(); ctx.scale(s, s);
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(9, 9, 7, 0, Math.PI * 2); ctx.stroke();
                    ctx.fillStyle = "#60a5fa";
                    ctx.beginPath(); ctx.arc(6, 7, 1.5, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.arc(12, 7, 1.5, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.arc(9, 11, 1.5, 0, Math.PI * 2); ctx.fill();
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 0.8;
                    ctx.beginPath(); ctx.moveTo(6, 7); ctx.lineTo(9, 11); ctx.lineTo(12, 7); ctx.stroke();
                    ctx.restore();
                }
                onSChanged: requestPaint()
            }

            Text {
                text: getAgentName()
                font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff"
            }

            // Active model badge
            Rectangle {
                visible: activeModel.length > 0
                width: modelBadgeText.width + Math.round(12 * root.sf); height: Math.round(18 * root.sf); radius: Math.round(9 * root.sf)
                color: Qt.rgba(0.35, 0.55, 1.0, 0.12)
                Text {
                    id: modelBadgeText; anchors.centerIn: parent
                    text: activeModel
                    font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Medium; color: "#60a5fa"
                }
            }

            Rectangle {
                width: agentSelectorRow.width + Math.round(12 * root.sf); height: Math.round(20 * root.sf); radius: Math.round(4 * root.sf)
                color: agentPickerMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.2) : Qt.rgba(0.35, 0.55, 1.0, 0.1)
                visible: true

                Row { id: agentSelectorRow; anchors.centerIn: parent; spacing: Math.round(3 * root.sf)
                    Text { text: "▾"; font.pixelSize: Math.round(8 * root.sf); color: "#60a5fa"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "switch"; font.pixelSize: Math.round(9 * root.sf); color: "#60a5fa"; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: agentPickerMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: showAgentPicker = !showAgentPicker
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: messages.length + " msgs"
                font.pixelSize: Math.round(10 * root.sf); color: root.textMuted
                visible: messages.length > 0
            }

            // Stop button (visible when streaming)
            Rectangle {
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(6 * root.sf)
                color: stopMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
                visible: isSending
                Text { anchors.centerIn: parent; text: "■"; font.pixelSize: Math.round(10 * root.sf); color: root.accentRed }
                MouseArea { id: stopMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { isSending = false; isStreaming = false; } }
            }

            Rectangle {
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(6 * root.sf)
                color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                visible: !isSending

                Canvas {
                    anchors.centerIn: parent; width: Math.round(12 * root.sf); height: Math.round(12 * root.sf)
                    property real s: root.sf
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.strokeStyle = "#c0cfe0"; ctx.lineWidth = 1.2; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.moveTo(1, 3); ctx.lineTo(11, 3); ctx.stroke();
                        ctx.strokeRect(3, 3, 6, 8);
                        ctx.beginPath(); ctx.moveTo(5, 5); ctx.lineTo(5, 9); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(7, 5); ctx.lineTo(7, 9); ctx.stroke();
                        ctx.restore();
                    }
                    onSChanged: requestPaint()
                }

                MouseArea {
                    id: clearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        messages = []; streamingSteps = []; activePlan = null; streamingContent = "";
                        // Clear server-side history too
                        var xhr = new XMLHttpRequest();
                        xhr.open("DELETE", root.apiBase + "/chat/history");
                        xhr.setRequestHeader("Content-Type", "application/json");
                        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
                        xhr.send();
                    }
                }
            }

            Rectangle {
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(6 * root.sf)
                color: fsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Canvas {
                    anchors.centerIn: parent; width: Math.round(12 * root.sf); height: Math.round(12 * root.sf)
                    property bool fs: chatFullScreen
                    property real s: root.sf
                    onFsChanged: requestPaint()
                    onSChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.strokeStyle = chatFullScreen ? "#60a5fa" : "#c0cfe0"; ctx.lineWidth = 1.2; ctx.lineCap = "round";
                        if (chatFullScreen) {
                            ctx.strokeRect(2, 2, 8, 8);
                            ctx.beginPath(); ctx.moveTo(4, 4); ctx.lineTo(8, 4); ctx.lineTo(8, 8); ctx.stroke();
                        } else {
                            ctx.beginPath(); ctx.moveTo(1, 4); ctx.lineTo(1, 1); ctx.lineTo(4, 1); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(8, 1); ctx.lineTo(11, 1); ctx.lineTo(11, 4); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(1, 8); ctx.lineTo(1, 11); ctx.lineTo(4, 11); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(8, 11); ctx.lineTo(11, 11); ctx.lineTo(11, 8); ctx.stroke();
                        }
                        ctx.restore();
                    }
                }

                MouseArea { id: fsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (chatFullScreen) { chatFullScreen = false; chatExpanded = false; } else { chatFullScreen = true; } } }
            }

            Rectangle {
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(6 * root.sf)
                color: collMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "▾"; font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary }
                MouseArea { id: collMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { chatExpanded = false; chatFullScreen = false; } }
            }
        }
    }

    // ── Agent Picker Dropdown ──
    Rectangle {
        id: agentPicker
        anchors.top: chatHeader.bottom; anchors.topMargin: Math.round(4 * root.sf)
        anchors.left: parent.left; anchors.leftMargin: Math.round(12 * root.sf)
        width: Math.round(220 * root.sf); height: apCol.height + Math.round(12 * root.sf)
        radius: root.radiusMd; z: 100
        color: Qt.rgba(0.08, 0.08, 0.14, 0.97)
        border.color: Qt.rgba(0.35, 0.55, 1.0, 0.2); border.width: 1
        visible: showAgentPicker && chatExpanded

        Column {
            id: apCol; anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: Math.round(6 * root.sf); spacing: 2

            Text { text: "Select Agent"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Bold; color: root.textMuted; leftPadding: Math.round(6 * root.sf); bottomPadding: Math.round(4 * root.sf) }

            Repeater {
                model: agentList

                Rectangle {
                    width: apCol.width; height: Math.round(32 * root.sf); radius: Math.round(4 * root.sf)
                    color: modelData.id === selectedAgent ? Qt.rgba(0.35, 0.55, 1.0, 0.15) :
                           apItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)

                        Rectangle {
                            width: Math.round(6 * root.sf); height: Math.round(6 * root.sf); radius: width / 2
                            color: modelData.enabled !== false ? root.accentGreen : root.textMuted
                        }

                        Column { Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.name || modelData.id; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: "#fff" }
                        }

                        Text {
                            visible: modelData.id === selectedAgent
                            text: "✓"; font.pixelSize: Math.round(11 * root.sf); color: root.accentBlue
                        }
                    }

                    MouseArea {
                        id: apItemMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { selectedAgent = modelData.id; showAgentPicker = false; }
                    }
                }
            }

            // Divider
            Rectangle { width: parent.width - Math.round(12 * root.sf); height: 1; color: Qt.rgba(1,1,1,0.06); anchors.horizontalCenter: parent.horizontalCenter }

            // Fan-Out (Multi-Agent) option
            Rectangle {
                width: apCol.width; height: Math.round(32 * root.sf); radius: Math.round(4 * root.sf)
                color: fanoutMa.containsMouse ? Qt.rgba(0.6, 0.3, 1.0, 0.12) : "transparent"

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)
                    Canvas {
                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = "#a78bfa"; ctx.lineWidth = 1.4; ctx.lineCap = "round";
                            // Fork icon: line down from top, splits into two branches
                            ctx.beginPath(); ctx.moveTo(7, 0); ctx.lineTo(7, 6); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(7, 6); ctx.lineTo(3, 12); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(7, 6); ctx.lineTo(11, 12); ctx.stroke();
                            // Dots at ends
                            ctx.fillStyle = "#a78bfa";
                            ctx.beginPath(); ctx.arc(7, 1, 1.5, 0, Math.PI * 2); ctx.fill();
                            ctx.beginPath(); ctx.arc(3, 12, 1.5, 0, Math.PI * 2); ctx.fill();
                            ctx.beginPath(); ctx.arc(11, 12, 1.5, 0, Math.PI * 2); ctx.fill();
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                    }
                    Text { text: "Fan-Out (Multi-Agent)"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: "#a78bfa"; Layout.fillWidth: true }
                }

                MouseArea {
                    id: fanoutMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { showAgentPicker = false; showFanOutModal = true; }
                }
            }
        }
    }

    // ── Multi-Agent Activity Panel ──
    Rectangle {
        id: multiAgentPanel
        anchors.top: chatHeader.bottom; anchors.topMargin: 1
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf)
        height: maPanel.height + Math.round(12 * root.sf)
        radius: Math.round(8 * root.sf)
        color: Qt.rgba(0.08, 0.10, 0.16, 0.9)
        border.color: Qt.rgba(0.4, 0.5, 1.0, 0.15); border.width: 1
        visible: chatExpanded && Object.keys(liveAgentRuns).length > 0

        Column {
            id: maPanel; anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: Math.round(6 * root.sf); spacing: Math.round(4 * root.sf)

            Row {
                spacing: Math.round(6 * root.sf)
                Text { text: "▸"; font.pixelSize: Math.round(11 * root.sf); color: root.accentBlue }
                Text { text: "Agent Activity"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Bold; color: "#e4e4e7" }
                Rectangle {
                    width: maBadge.width + Math.round(8 * root.sf); height: Math.round(16 * root.sf); radius: 8
                    color: Qt.rgba(0.35, 0.55, 1.0, 0.2)
                    Text { id: maBadge; anchors.centerIn: parent; text: Object.keys(liveAgentRuns).length.toString(); font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: "#60a5fa" }
                }
            }

            Repeater {
                model: Object.keys(liveAgentRuns)

                Rectangle {
                    property var run: liveAgentRuns[modelData]
                    width: maPanel.width; height: maRunRow.height + Math.round(10 * root.sf); radius: Math.round(6 * root.sf)
                    color: Qt.rgba(0.06, 0.06, 0.10, 0.8)
                    border.color: run.status === "running" ? Qt.rgba(0.35, 0.55, 1.0, 0.2) : Qt.rgba(1,1,1,0.06); border.width: 1

                    Row {
                        id: maRunRow; anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)

                        Rectangle {
                            width: Math.round(6 * root.sf); height: Math.round(6 * root.sf); radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: run.status === "running" ? "#3b82f6" : run.status === "completed" ? "#34d399" : run.status === "error" ? "#ef4444" : root.textMuted
                        }
                        Column {
                            spacing: 1; width: parent.width - Math.round(80 * root.sf)
                            Text { text: run.agentId || "Agent"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Bold; color: "#e4e4e7" }
                            Text { text: (run.task || "...").substring(0, 60); font.pixelSize: Math.round(9 * root.sf); color: root.textMuted; elide: Text.ElideRight; width: parent.width }
                        }
                        Text {
                            text: run.status || "pending"
                            font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter
                            color: run.status === "running" ? "#3b82f6" : run.status === "completed" ? "#34d399" : run.status === "error" ? "#ef4444" : root.textMuted
                        }
                    }
                }
            }
        }
    }

    // ── Messages Area ──
    Item {
        anchors.top: multiAgentPanel.visible ? multiAgentPanel.bottom : chatHeader.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: inputArea.top
        anchors.margins: 1; visible: chatExpanded; clip: true

        // Empty state
        Column {
            anchors.centerIn: parent; spacing: Math.round(12 * root.sf)
            visible: messages.length === 0 && !isSending

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(48 * root.sf); height: Math.round(48 * root.sf)
                source: "assets/whale_logo.png"
                fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                opacity: 0.5
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "How can I help you today?"
                font.pixelSize: Math.round(15 * root.sf); font.weight: Font.DemiBold
                color: Qt.rgba(1, 1, 1, 0.4)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ask me anything - code, files, system tasks"
                font.pixelSize: Math.round(11 * root.sf); color: Qt.rgba(1, 1, 1, 0.2)
            }
        }

        ListView {
            id: messageList
            anchors.fill: parent; anchors.leftMargin: Math.round(20 * root.sf); anchors.rightMargin: Math.round(20 * root.sf)
            anchors.topMargin: Math.round(16 * root.sf); anchors.bottomMargin: Math.round(12 * root.sf)
            model: messages; spacing: Math.round(20 * root.sf); clip: true

            delegate: Item {
                width: messageList.width
                height: delegateCol.childrenRect.height

                Column {
                    id: delegateCol
                    width: parent.width
                    spacing: Math.round(4 * root.sf)

                    // Tool calls display (above the message if present)
                    Column {
                        id: toolCol
                        width: parent.width - (modelData.role !== "user" ? Math.round(36 * root.sf) : 0) - parent.width * 0.05
                        x: modelData.role !== "user" ? Math.round(36 * root.sf) : 0
                        visible: modelData.toolCalls && modelData.toolCalls.length > 0
                        spacing: Math.round(6 * root.sf)

                        Repeater {
                            model: (modelData.toolCalls || [])
                            Rectangle {
                                width: toolCol.width; height: toolRow.height + Math.round(8 * root.sf)
                                radius: Math.round(6 * root.sf)
                                color: Qt.rgba(0.1, 0.14, 0.1, 0.6)
                                border.color: Qt.rgba(0.2, 0.7, 0.4, 0.15); border.width: 1

                                Row {
                                    id: toolRow; anchors.left: parent.left; anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)

                                    Text { text: "⚡"; font.pixelSize: Math.round(9 * root.sf) }
                                    Text {
                                        text: modelData.name || "tool"
                                        font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Medium; color: "#34d399"
                                    }
                                    Text {
                                        text: modelData.status === "success" ? "✓" : (modelData.status === "error" ? "✗" : "⋯")
                                        font.pixelSize: Math.round(10 * root.sf)
                                        color: modelData.status === "success" ? "#34d399" : (modelData.status === "error" ? root.accentRed : root.textMuted)
                                    }
                                }
                            }
                        }
                    }

                    // Message row wrapper
                    Item {
                        width: parent.width
                        height: msgRow.height

                        Row {
                            id: msgRow
                            x: modelData.role === "user" ? (parent.width - msgRow.implicitWidth) : 0
                            spacing: Math.round(12 * root.sf)
                            layoutDirection: modelData.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

                            // Avatar for assistant
                            Rectangle {
                                visible: modelData.role !== "user"
                                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf)
                                radius: Math.round(8 * root.sf)
                                color: Qt.rgba(0.2, 0.83, 0.6, 0.1)

                                Image {
                                    anchors.centerIn: parent
                                    width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                                    source: "assets/whale_logo.png"
                                    fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                                }
                            }

                            Rectangle {
                                id: msgBubble
                                width: modelData.role === "user"
                                    ? Math.min(messageList.width * 0.68, userMsgMetrics.width + Math.round(36 * root.sf))
                                    : messageList.width - Math.round(48 * root.sf)
                                height: msgContentCol.height + Math.round(24 * root.sf)
                                radius: Math.round(14 * root.sf)

                                color: modelData.role === "user"
                                    ? Qt.rgba(0.24, 0.45, 0.95, 0.18)
                                    : "transparent"
                                border.color: modelData.role === "user"
                                    ? Qt.rgba(0.35, 0.55, 1.0, 0.15)
                                    : "transparent"
                                border.width: modelData.role === "user" ? 1 : 0

                                TextMetrics {
                                    id: userMsgMetrics
                                    text: modelData.content || ""
                                    font.pixelSize: Math.round(13 * root.sf)
                                }

                                Column {
                                    id: msgContentCol
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: modelData.role === "user" ? Math.round(14 * root.sf) : Math.round(12 * root.sf)
                                    spacing: Math.round(6 * root.sf)

                                    Row {
                                        spacing: Math.round(6 * root.sf)
                                        Text {
                                            text: modelData.role === "user" ? "" : (modelData.agent || getAgentName())
                                            font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold
                                            color: "#a3e635"
                                            visible: modelData.role !== "user"
                                        }
                                        Text {
                                            visible: modelData.model && modelData.role !== "user"
                                            text: modelData.model || ""
                                            font.pixelSize: Math.round(9 * root.sf); color: root.textMuted
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: modelData.role === "user" ? (modelData.content || "") : mdToStyled(modelData.content || "")
                                        font.pixelSize: Math.round(13.5 * root.sf)
                                        color: modelData.role === "user" ? "#e0e7ff" : "#e4e4e7"
                                        wrapMode: Text.Wrap; lineHeight: 1.6
                                        textFormat: modelData.role === "user" ? Text.PlainText : Text.StyledText
                                    }
                                }
                            }
                        }
                    }
                } // end delegateCol
            }

            // ── Live streaming footer ──
            footer: Item {
                width: messageList.width
                height: streamCol.height + Math.round(10 * root.sf)
                visible: isSending

                Column {
                    id: streamCol
                    anchors.left: parent.left; anchors.right: parent.right
                    spacing: Math.round(6 * root.sf)

                    // Plan display
                    Rectangle {
                        visible: activePlan !== null
                        width: parent.width * 0.88; height: planCol.height + Math.round(16 * root.sf)
                        radius: Math.round(10 * root.sf)
                        color: Qt.rgba(0.1, 0.1, 0.2, 0.7)
                        border.color: Qt.rgba(0.35, 0.55, 1.0, 0.25); border.width: 1

                        Column {
                            id: planCol; anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Math.round(10 * root.sf); spacing: Math.round(6 * root.sf)

                            Text {
                                text: "≣ " + (activePlan ? activePlan.title || "Plan" : "")
                                font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Bold; color: "#60a5fa"
                            }

                            Repeater {
                                model: activePlan ? activePlan.steps || [] : []
                                Row {
                                    spacing: Math.round(6 * root.sf)
                                    Text {
                                        text: modelData.status === "completed" ? "✓" : (modelData.status === "in_progress" ? "⋯" : (modelData.status === "skipped" ? "—" : "○"))
                                        font.pixelSize: Math.round(10 * root.sf)
                                        color: modelData.status === "completed" ? "#34d399" : (modelData.status === "in_progress" ? "#60a5fa" : root.textMuted)
                                    }
                                    Text {
                                        text: modelData.description || modelData.title || ""
                                        font.pixelSize: Math.round(10 * root.sf)
                                        color: modelData.status === "completed" ? "#34d399" : (modelData.status === "in_progress" ? "#e4e4e7" : root.textMuted)
                                    }
                                }
                            }
                        }
                    }

                    // Live tool steps
                    Repeater {
                        model: streamingSteps

                        Rectangle {
                            width: parent.width * 0.88; height: stepRow.height + Math.round(12 * root.sf)
                            radius: Math.round(8 * root.sf)
                            color: modelData.type === "error" ? Qt.rgba(0.3, 0.1, 0.1, 0.6) :
                                   modelData.type === "tool" ? Qt.rgba(0.1, 0.15, 0.1, 0.6) :
                                   Qt.rgba(0.1, 0.1, 0.15, 0.6)
                            border.color: modelData.type === "error" ? Qt.rgba(0.9, 0.2, 0.2, 0.2) :
                                          modelData.type === "tool" ? Qt.rgba(0.2, 0.8, 0.4, 0.2) :
                                          Qt.rgba(0.4, 0.5, 1.0, 0.15)
                            border.width: 1

                            Row {
                                id: stepRow; anchors.left: parent.left; anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)

                                Text {
                                    text: modelData.type === "thinking" ? "⊙" :
                                          modelData.type === "tool" ? "⚡" :
                                          modelData.type === "error" ? "✗" : "•"
                                    font.pixelSize: Math.round(11 * root.sf)
                                }

                                Text {
                                    text: {
                                        if (modelData.type === "thinking") {
                                            var iter = modelData.iteration || 1;
                                            return modelData.done ? "Thought complete" : "Thinking" + (iter > 1 ? " (round " + iter + ")" : "") + "...";
                                        } else if (modelData.type === "tool") {
                                            return (modelData.name || "tool") + (modelData.status === "running" ? " ⋯" : (modelData.status === "success" ? " ✓" : " ✗"));
                                        } else if (modelData.type === "error") {
                                            return modelData.message || "Error";
                                        }
                                        return "";
                                    }
                                    font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Medium
                                    color: modelData.type === "error" ? root.accentRed :
                                           modelData.type === "tool" ? "#34d399" : "#93c5fd"
                                    width: parent.width - Math.round(40 * root.sf)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Streaming content preview
                    Row {
                        visible: streamingContent.length > 0
                        spacing: Math.round(8 * root.sf)

                        Rectangle {
                            width: Math.round(28 * root.sf); height: Math.round(28 * root.sf)
                            radius: Math.round(8 * root.sf)
                            color: Qt.rgba(0.2, 0.83, 0.6, 0.1)
                            Image {
                                anchors.centerIn: parent
                                width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                                source: "assets/whale_logo.png"
                                fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                            }
                        }

                        Rectangle {
                            width: streamCol.width - Math.round(44 * root.sf); height: streamTextCol.height + Math.round(14 * root.sf)
                            radius: Math.round(12 * root.sf)
                            color: "transparent"

                            Column {
                                id: streamTextCol; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.margins: Math.round(4 * root.sf); spacing: Math.round(4 * root.sf)

                                Text {
                                    text: getAgentName()
                                    font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#a3e635"
                                }
                                Text {
                                    width: parent.width
                                    text: mdToStyled(streamingContent)
                                    font.pixelSize: Math.round(13 * root.sf); color: "#e4e4e7"
                                    wrapMode: Text.Wrap; lineHeight: 1.5
                                    textFormat: Text.StyledText
                                }
                            }

                        // Typing cursor
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(12 * root.sf)
                            anchors.right: streamTextCol.right; anchors.rightMargin: Math.round(10 * root.sf)
                            width: Math.round(2 * root.sf); height: Math.round(14 * root.sf)
                            color: "#60a5fa"
                            SequentialAnimation on opacity {
                                running: isSending; loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                    }
                    } // close streaming Row

                    // Working status bar — styled as message bubble
                    Row {
                        visible: isSending && streamingContent.length === 0
                        spacing: Math.round(12 * root.sf)

                        // Whale avatar
                        Rectangle {
                            width: Math.round(28 * root.sf); height: Math.round(28 * root.sf)
                            radius: Math.round(8 * root.sf)
                            color: Qt.rgba(0.2, 0.83, 0.6, 0.1)
                            Image {
                                anchors.centerIn: parent
                                width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                                source: "assets/whale_logo.png"
                                fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                            }
                        }

                        // Message-style bubble with thinking
                        Rectangle {
                            width: streamCol.width - Math.round(48 * root.sf)
                            height: thinkingBubbleCol.height + Math.round(20 * root.sf)
                            radius: Math.round(14 * root.sf)
                            color: Qt.rgba(0.08, 0.10, 0.14, 0.6)
                            border.color: Qt.rgba(0.35, 0.55, 1.0, 0.1); border.width: 1

                            Column {
                                id: thinkingBubbleCol; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.margins: Math.round(10 * root.sf); spacing: Math.round(8 * root.sf)

                                Row {
                                    spacing: Math.round(6 * root.sf)
                                    Text {
                                        text: getAgentName()
                                        font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#a3e635"
                                    }
                                    Text {
                                        visible: activeModel.length > 0
                                        text: activeModel
                                        font.pixelSize: Math.round(9 * root.sf); color: root.textMuted
                                    }
                                }

                                Row {
                                    id: streamRow2; spacing: Math.round(5 * root.sf)
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: Math.round(5 * root.sf); height: Math.round(5 * root.sf); radius: width / 2; color: "#34d399"
                                            anchors.verticalCenter: parent.verticalCenter
                                            SequentialAnimation on opacity {
                                                running: isSending; loops: Animation.Infinite
                                                PauseAnimation { duration: index * 200 }
                                                NumberAnimation { to: 0.2; duration: 400 }
                                                NumberAnimation { to: 1.0; duration: 400 }
                                                PauseAnimation { duration: (2 - index) * 200 }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: getWorkingStatus()
                                    font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                                    topPadding: Math.round(2 * root.sf)
                                }
                            }
                        }
                    }
                }
            }

            onCountChanged: Qt.callLater(function() { messageList.positionViewAtEnd(); })
        }
    }

    // ── Slash Command Suggestions ──
    Rectangle {
        id: suggestionsBox
        anchors.bottom: inputArea.top; anchors.bottomMargin: Math.round(4 * root.sf)
        anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf)
        width: sugCol.width + Math.round(16 * root.sf); height: sugCol.height + Math.round(12 * root.sf)
        radius: root.radiusMd; z: 50
        color: Qt.rgba(0.08, 0.08, 0.14, 0.97)
        border.color: Qt.rgba(0.35, 0.55, 1.0, 0.15); border.width: 1
        visible: showSuggestions && chatExpanded

        Column {
            id: sugCol; anchors.centerIn: parent; spacing: 2; padding: 0

            Repeater {
                model: {
                    if (!showSuggestions) return [];
                    var input = chatInput.text.toLowerCase();
                    var filtered = [];
                    for (var i = 0; i < commandSuggestions.length; i++) {
                        if (commandSuggestions[i].indexOf(input) === 0) filtered.push(commandSuggestions[i]);
                    }
                    return filtered;
                }

                Rectangle {
                    width: Math.round(140 * root.sf); height: Math.round(26 * root.sf); radius: Math.round(4 * root.sf)
                    color: sugItemMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.15) : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter; leftPadding: Math.round(8 * root.sf)
                        text: modelData; font.pixelSize: Math.round(12 * root.sf); font.family: "monospace"; color: "#60a5fa"
                    }

                    MouseArea {
                        id: sugItemMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { chatInput.text = modelData + " "; showSuggestions = false; chatInput.forceActiveFocus(); }
                    }
                }
            }
        }
    }

    // ── Input Area ──
    Rectangle {
        id: inputArea
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: Math.round(12 * root.sf); anchors.rightMargin: Math.round(12 * root.sf)
        anchors.bottomMargin: Math.round(8 * root.sf)
        height: Math.round(48 * root.sf); radius: Math.round(14 * root.sf)
        color: Qt.rgba(0.06, 0.06, 0.10, 0.95)
        border.color: chatInput.activeFocus ? Qt.rgba(0.35, 0.55, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.18)
        border.width: 1

        // PERF: Removed border.color Behavior — triggers repaint on every focus change

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(16 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(10 * root.sf)

            // AI icon — clickable expand button when collapsed
            Rectangle {
                visible: !chatExpanded
                width: Math.round(28 * root.sf); height: Math.round(28 * root.sf); radius: Math.round(8 * root.sf)
                color: expandIconMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.2) : Qt.rgba(0.35, 0.55, 1.0, 0.08)

                Canvas {
                    anchors.centerIn: parent
                    width: Math.round(16 * root.sf); height: Math.round(16 * root.sf)
                    property real s: root.sf
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 1.2;
                        ctx.beginPath(); ctx.arc(8, 8, 6, 0, Math.PI * 2); ctx.stroke();
                        ctx.fillStyle = "#60a5fa";
                        ctx.beginPath(); ctx.arc(5.5, 7, 1.2, 0, Math.PI * 2); ctx.fill();
                        ctx.beginPath(); ctx.arc(10.5, 7, 1.2, 0, Math.PI * 2); ctx.fill();
                        ctx.beginPath(); ctx.arc(8, 10, 1.2, 0, Math.PI * 2); ctx.fill();
                        ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 0.6;
                        ctx.beginPath(); ctx.moveTo(5.5, 7); ctx.lineTo(8, 10); ctx.lineTo(10.5, 7); ctx.stroke();
                        ctx.restore();
                    }
                    onSChanged: requestPaint()
                }

                MouseArea {
                    id: expandIconMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { chatExpanded = true; chatInput.forceActiveFocus(); }
                }
            }

            // Message count badge when collapsed (shows there are messages)
            Rectangle {
                visible: !chatExpanded && messages.length > 0
                width: collapsedBadge.width + Math.round(10 * root.sf); height: Math.round(20 * root.sf); radius: 10
                color: Qt.rgba(0.35, 0.55, 1.0, 0.15)

                Text {
                    id: collapsedBadge; anchors.centerIn: parent
                    text: messages.length + " msgs"
                    font.pixelSize: Math.round(9 * root.sf); font.weight: Font.DemiBold; color: "#60a5fa"
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { chatExpanded = true; chatInput.forceActiveFocus(); }
                }
            }

            TextInput {
                id: chatInput
                Layout.fillWidth: true
                verticalAlignment: TextInput.AlignVCenter
                color: "#e4e4e7"; font.pixelSize: Math.round(14 * root.sf); clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ask TensorAgent AI anything..."
                    color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: Math.round(13 * root.sf)
                    visible: !parent.text && !parent.activeFocus
                }

                // Only expand on explicit click, not on focus change
                // (Wayland focus-follows-pointer causes hover to trigger focus)

                // Also expand on mouse click (in case focus doesn't change)
                MouseArea {
                    anchors.fill: parent; visible: !chatExpanded
                    cursorShape: Qt.IBeamCursor
                    onClicked: { chatExpanded = true; chatInput.forceActiveFocus(); }
                }

                onTextChanged: {
                    showSuggestions = text.length > 0 && text.charAt(0) === '/';
                }

                Keys.onReturnPressed: sendMessage()
                Keys.onUpPressed: {
                    if (chatHistory.length > 0) {
                        if (historyIndex === -1) historyIndex = chatHistory.length - 1;
                        else if (historyIndex > 0) historyIndex--;
                        chatInput.text = chatHistory[historyIndex];
                    }
                }
                Keys.onDownPressed: {
                    if (historyIndex >= 0) {
                        historyIndex++;
                        if (historyIndex >= chatHistory.length) { historyIndex = -1; chatInput.text = ""; }
                        else chatInput.text = chatHistory[historyIndex];
                    }
                }
                Keys.onEscapePressed: {
                    if (showSuggestions) showSuggestions = false;
                    else if (showAgentPicker) showAgentPicker = false;
                    else if (chatFullScreen) { chatFullScreen = false; }
                    else { chatExpanded = false; chatInput.focus = false; }
                }
            }

            Rectangle {
                visible: true
                width: agentPillText.width + Math.round(18 * root.sf); height: Math.round(26 * root.sf); radius: Math.round(13 * root.sf)
                color: Qt.rgba(0.2, 0.83, 0.6, 0.1)
                border.color: Qt.rgba(0.2, 0.83, 0.6, 0.2); border.width: 1

                Text {
                    id: agentPillText; anchors.centerIn: parent
                    text: getAgentName(); font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: "#34d399"
                }
            }

            Rectangle {
                width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: Math.round(12 * root.sf)

                color: chatInput.text.trim() ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.06)
                // PERF: Removed color Behavior on send button

                Canvas {
                    anchors.centerIn: parent; width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                    property real s: root.sf
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.fillStyle = chatInput.text.trim() ? "#fff" : "#666";
                        ctx.beginPath(); ctx.moveTo(7, 1); ctx.lineTo(12, 7); ctx.lineTo(8, 7);
                        ctx.lineTo(8, 13); ctx.lineTo(6, 13); ctx.lineTo(6, 7); ctx.lineTo(2, 7);
                        ctx.closePath(); ctx.fill();
                        ctx.restore();
                    }
                    onSChanged: requestPaint()
                }

                // PERF: Removed SequentialAnimation on border.color — was repainting every 1200ms
                // even while idle. Static glow is visually equivalent and costs nothing.

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: sendMessage()
                }
            }
        }
    }

    // ── Send Message via SSE Stream ──
    function sendMessage() {
        var msg = chatInput.text.trim();
        if (!msg || isSending) return;

        // Handle /new, /reset, /clear locally — reset work folder for fresh conversation
        var lowerMsg = msg.toLowerCase();
        if (lowerMsg === "/new" || lowerMsg === "/reset" || lowerMsg === "/clear") {
            startNewConversation();
        }

        chatExpanded = true;
        showSuggestions = false;
        showAgentPicker = false;

        var hist = chatHistory.slice();
        hist.push(msg);
        if (hist.length > 50) hist = hist.slice(-50);
        chatHistory = hist;
        historyIndex = -1;

        // Create per-conversation workspace folder on first message
        if (!currentWorkFolder) {
            currentWorkFolder = generateWorkFolder(msg);
        }
        var workDir = "/home/" + root.currentUser + "/Works/" + currentWorkFolder;
        sysManager.createDir(workDir);

        var msgs = messages.slice();
        msgs.push({ role: "user", content: msg, createdAt: new Date().toISOString() });
        messages = msgs;
        chatInput.text = "";
        isSending = true;
        isStreaming = true;
        streamingContent = "";
        streamingSteps = [];
        activePlan = null;

        // Use SSE streaming endpoint
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/chat/stream");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);

        var lastIndex = 0;

        xhr.onreadystatechange = function() {
            // readyState 3 = LOADING (progressive data)
            if (xhr.readyState === 3 || xhr.readyState === 4) {
                var text = "";
                try { text = xhr.responseText; } catch(e) { return; }
                var newData = text.substring(lastIndex);
                lastIndex = text.length;

                if (newData) {
                    var lines = newData.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (!line.startsWith("data: ")) continue;
                        try {
                            var parsed = JSON.parse(line.substring(6));
                            handleStreamEvent(parsed.event, parsed.data);
                        } catch(e) { /* skip malformed */ }
                    }
                }
            }

            if (xhr.readyState === 4) {
                isSending = false;
                isStreaming = false;

                // If we got streaming content but no done event, add it as a message
                if (streamingContent && !messages[messages.length - 1] || messages[messages.length - 1].role === "user") {
                    var msgs2 = messages.slice();
                    msgs2.push({ role: "assistant", content: streamingContent, agent: getAgentName() });
                    messages = msgs2;
                    streamingContent = "";
                }
                streamingSteps = [];
                activePlan = null;
            }
        };

        xhr.send(JSON.stringify({ message: msg, agent: selectedAgent, workDir: workDir }));
    }

    function handleStreamEvent(event, data) {
        if (!data) return;
        switch (event) {
            case "thinking": {
                var steps = streamingSteps.slice();
                var found = false;
                for (var i = 0; i < steps.length; i++) {
                    if (steps[i].type === "thinking") { steps[i].iteration = data.iteration; found = true; break; }
                }
                if (!found) steps.push({ type: "thinking", iteration: data.iteration || 1, done: false });
                streamingSteps = steps;
                break;
            }
            case "content": {
                streamingContent = data.text || "";
                // Mark thinking as done
                var steps2 = streamingSteps.slice();
                for (var j = 0; j < steps2.length; j++) {
                    if (steps2[j].type === "thinking") steps2[j].done = true;
                }
                streamingSteps = steps2;
                break;
            }
            case "tool_start": {
                var steps3 = streamingSteps.slice();
                steps3.push({ type: "tool", id: data.id, name: data.name, arguments: data.arguments, status: "running" });
                streamingSteps = steps3;
                break;
            }
            case "tool_end": {
                var steps4 = streamingSteps.slice();
                for (var k = 0; k < steps4.length; k++) {
                    if (steps4[k].id === data.id) {
                        steps4[k].status = data.status || "success";
                        steps4[k].result = data.result;
                        break;
                    }
                }
                streamingSteps = steps4;
                break;
            }
            case "plan_created": {
                var plan = { title: data.title, steps: [], completed: false };
                if (data.steps) {
                    for (var p = 0; p < data.steps.length; p++) {
                        plan.steps.push({ id: data.steps[p].id, description: data.steps[p].description || data.steps[p].title,
                                          status: data.steps[p].status || "pending", toolCalls: [] });
                    }
                }
                activePlan = plan;
                break;
            }
            case "plan_step_update": {
                if (activePlan) {
                    var newPlan = JSON.parse(JSON.stringify(activePlan));
                    for (var q = 0; q < newPlan.steps.length; q++) {
                        if (newPlan.steps[q].id === data.stepId) {
                            newPlan.steps[q].status = data.status;
                            if (data.notes) newPlan.steps[q].notes = data.notes;
                            break;
                        }
                    }
                    activePlan = newPlan;
                }
                break;
            }
            case "plan_completed": {
                if (activePlan) {
                    var cp = JSON.parse(JSON.stringify(activePlan));
                    cp.completed = true;
                    for (var r = 0; r < cp.steps.length; r++) {
                        if (cp.steps[r].status !== "skipped") cp.steps[r].status = "completed";
                    }
                    activePlan = cp;
                }
                break;
            }
            case "done": {
                if (data.message) {
                    var msgs3 = messages.slice();
                    msgs3.push({
                        role: "assistant",
                        content: data.message.content || streamingContent,
                        toolCalls: data.message.toolCalls,
                        model: data.message.model,
                        agent: getAgentName(),
                        createdAt: data.message.createdAt || new Date().toISOString()
                    });
                    messages = msgs3;
                    streamingContent = "";
                }
                isSending = false;
                isStreaming = false;
                break;
            }
            case "error": {
                var steps5 = streamingSteps.slice();
                steps5.push({ type: "error", message: data.message || "Unknown error" });
                streamingSteps = steps5;
                break;
            }
            case "stopped": {
                isSending = false;
                isStreaming = false;
                break;
            }
            case "agent_start": {
                var runs = JSON.parse(JSON.stringify(liveAgentRuns));
                runs[data.runId] = { runId: data.runId, agentId: data.agentId, task: data.task, status: "running", steps: [] };
                liveAgentRuns = runs;
                break;
            }
            case "agent_update": {
                var runs2 = JSON.parse(JSON.stringify(liveAgentRuns));
                if (runs2[data.runId]) {
                    runs2[data.runId].status = data.status || runs2[data.runId].status;
                    if (data.step) { runs2[data.runId].steps = (runs2[data.runId].steps || []).concat([data.step]); }
                }
                liveAgentRuns = runs2;
                break;
            }
            case "agent_done": {
                var runs3 = JSON.parse(JSON.stringify(liveAgentRuns));
                if (runs3[data.runId]) {
                    runs3[data.runId].status = data.status || "completed";
                    if (data.result) runs3[data.runId].result = data.result;
                }
                liveAgentRuns = runs3;
                break;
            }
        }
        // Auto-scroll
        Qt.callLater(function() { messageList.positionViewAtEnd(); });
    }

    // ── Fan-Out Multi-Agent Modal ──
    Rectangle {
        id: fanOutOverlay
        anchors.fill: parent; z: 200
        visible: showFanOutModal
        color: Qt.rgba(0, 0, 0, 0.6)

        MouseArea { anchors.fill: parent; onClicked: showFanOutModal = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(Math.round(400 * root.sf), parent.width - Math.round(40 * root.sf))
            height: fanOutCol.height + Math.round(32 * root.sf)
            radius: root.radiusLg
            color: Qt.rgba(0.06, 0.06, 0.10, 0.98)
            border.color: Qt.rgba(0.4, 0.5, 1.0, 0.2); border.width: 1

            MouseArea { anchors.fill: parent } // prevent close on card click

            Column {
                id: fanOutCol; anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: Math.round(16 * root.sf); spacing: Math.round(12 * root.sf)

                // Header
                RowLayout {
                    width: parent.width
                    Text { text: "Multi-Agent Task"; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.Bold; color: "#fff"; Layout.fillWidth: true }
                    Rectangle {
                        width: Math.round(24 * root.sf); height: Math.round(24 * root.sf); radius: 12; color: closeFoMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                        MouseArea { id: closeFoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: showFanOutModal = false }
                    }
                }

                Text {
                    text: "Spawn agents to work on a task in parallel."
                    font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; width: parent.width; wrapMode: Text.Wrap
                }

                // Task input
                Text { text: "Task Description"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: root.textSecondary }
                Rectangle {
                    width: parent.width; height: Math.round(60 * root.sf); radius: root.radiusMd
                    color: Qt.rgba(0.08, 0.08, 0.14, 0.9); border.color: fanOutTaskInput.activeFocus ? Qt.rgba(0.35, 0.55, 1.0, 0.3) : Qt.rgba(1,1,1,0.1); border.width: 1
                    TextInput {
                        id: fanOutTaskInput; anchors.fill: parent; anchors.margins: Math.round(10 * root.sf)
                        color: "#e4e4e7"; font.pixelSize: Math.round(12 * root.sf); wrapMode: TextInput.Wrap
                        Text { visible: !parent.text; text: "Describe the task..."; color: Qt.rgba(1,1,1,0.25); font.pixelSize: Math.round(12 * root.sf) }
                    }
                }

                // Agent checklist
                Text { text: "Select Agents"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: root.textSecondary }

                Column {
                    width: parent.width; spacing: Math.round(4 * root.sf)
                    Repeater {
                        model: agentList
                        Rectangle {
                            width: parent.width; height: Math.round(32 * root.sf); radius: Math.round(6 * root.sf)
                            color: foAgentMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)
                                Rectangle {
                                    width: Math.round(16 * root.sf); height: Math.round(16 * root.sf); radius: Math.round(3 * root.sf)
                                    border.color: fanOutChecked[modelData.id] ? "#3b82f6" : Qt.rgba(1,1,1,0.2); border.width: 1
                                    color: fanOutChecked[modelData.id] ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : "transparent"
                                    Text { anchors.centerIn: parent; text: fanOutChecked[modelData.id] ? "✓" : ""; font.pixelSize: Math.round(10 * root.sf); color: "#3b82f6" }
                                }
                                Text { text: modelData.name || modelData.id; font.pixelSize: Math.round(11 * root.sf); color: "#e4e4e7"; Layout.fillWidth: true }
                            }

                            MouseArea {
                                id: foAgentMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var c = JSON.parse(JSON.stringify(fanOutChecked));
                                    c[modelData.id] = !c[modelData.id];
                                    fanOutChecked = c;
                                }
                            }
                        }
                    }
                }

                // Run button
                Rectangle {
                    width: parent.width; height: Math.round(36 * root.sf); radius: Math.round(10 * root.sf)
                    color: runFoMa.containsMouse ? "#2563eb" : "#3b82f6"

                    Text { anchors.centerIn: parent; text: "⚡ Run Multi-Agent Task"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Bold; color: "#fff" }

                    MouseArea {
                        id: runFoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var task = fanOutTaskInput.text.trim();
                            if (!task) { root.showToast("Enter a task description", "error"); return; }
                            var agents = [];
                            var keys = Object.keys(fanOutChecked);
                            for (var i = 0; i < keys.length; i++) {
                                if (fanOutChecked[keys[i]]) agents.push(keys[i]);
                            }
                            if (agents.length === 0) { root.showToast("Select at least one agent", "error"); return; }

                            var xhr = new XMLHttpRequest();
                            xhr.open("POST", root.apiBase + "/agents/fan-out");
                            xhr.setRequestHeader("Content-Type", "application/json");
                            xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
                            xhr.onreadystatechange = function() {
                                if (xhr.readyState === 4) {
                                    if (xhr.status === 200) {
                                        root.showToast("Multi-agent task dispatched!", "success");
                                    } else {
                                        root.showToast("Fan-out failed (HTTP " + xhr.status + ")", "error");
                                    }
                                }
                            };
                            xhr.send(JSON.stringify({ task: task, agents: agents }));
                            showFanOutModal = false;
                            fanOutTaskInput.text = "";
                            fanOutChecked = ({});
                        }
                    }
                }
            }
        }
    }
}
