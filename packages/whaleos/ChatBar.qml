import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: chatBar
    height: chatExpanded ? (chatFullScreen ? parent.height - 20 : Math.min(450, parent.height - 70)) : 48
    radius: root.radiusLg
    color: "transparent"
    clip: true

    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property bool chatExpanded: false
    property bool chatFullScreen: false
    property bool isSending: false
    property var messages: []
    property string selectedAgent: "main"
    property var agentList: [{ id: "main", name: "TensorAgent AI", description: "Default AI" }]
    property bool showAgentPicker: false
    property string streamingText: ""
    property bool isStreaming: false
    property var commandSuggestions: ["/help", "/new", "/status", "/think", "/usage", "/compact"]
    property bool showSuggestions: false
    property var chatHistory: []
    property int historyIndex: -1

    // Strip emoji and unsupported unicode from text
    function cleanText(text) {
        if (!text) return "";
        // Remove emoji/symbol unicode ranges that QML can't render
        var cleaned = "";
        for (var i = 0; i < text.length; i++) {
            var code = text.charCodeAt(i);
            // Skip surrogate pairs (emoji), and common symbol blocks
            if (code >= 0xD800 && code <= 0xDFFF) continue;
            if (code >= 0x2600 && code <= 0x27BF) continue; // misc symbols
            if (code >= 0xFE00 && code <= 0xFE0F) continue; // variation selectors
            if (code >= 0x1F000) continue; // supplementary
            cleaned += text.charAt(i);
        }
        // Clean up markdown bold markers
        cleaned = cleaned.replace(/\*\*/g, "");
        // Rebrand names
        cleaned = cleaned.replace(/OpenWhale/g, "TensorAgent AI");
        cleaned = cleaned.replace(/AInux OS/g, "TensorAgent OS");
        cleaned = cleaned.replace(/AInux/g, "TensorAgent OS");
        return cleaned.trim();
    }

    Component.onCompleted: loadAgents()

    function loadAgents() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/agents");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try { agentList = JSON.parse(xhr.responseText); } catch(e) {}
            }
        };
        xhr.send();
    }

    function getAgentName() {
        for (var i = 0; i < agentList.length; i++) {
            if (agentList[i].id === selectedAgent) return agentList[i].name;
        }
        return "AI";
    }

    // ══════════════════════════════════════
    // ── Glass background ──
    // ══════════════════════════════════════
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: Qt.rgba(0.06, 0.06, 0.10, 0.88)
        border.color: Qt.rgba(0.35, 0.45, 0.85, 0.15); border.width: 1

        // Top glow line
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 20; anchors.rightMargin: 20
            height: 1; radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: Qt.rgba(0.35, 0.55, 1.0, 0.25) }
                GradientStop { position: 0.7; color: Qt.rgba(0.55, 0.35, 1.0, 0.25) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // ══════════════════════════════════════
    // ── Chat Header (expanded) ──
    // ══════════════════════════════════════
    Rectangle {
        id: chatHeader
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 42; visible: chatExpanded
        color: Qt.rgba(0.05, 0.05, 0.08, 0.95); radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.04) }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8; spacing: 8

            // AI Brain icon
            Canvas {
                width: 18; height: 18
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, 18, 18);
                    // Circuit brain
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(9, 9, 7, 0, Math.PI * 2); ctx.stroke();
                    ctx.fillStyle = "#60a5fa";
                    ctx.beginPath(); ctx.arc(6, 7, 1.5, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.arc(12, 7, 1.5, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.arc(9, 11, 1.5, 0, Math.PI * 2); ctx.fill();
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 0.8;
                    ctx.beginPath(); ctx.moveTo(6, 7); ctx.lineTo(9, 11); ctx.lineTo(12, 7); ctx.stroke();
                }
            }

            // Agent label (clickable)
            Text {
                text: getAgentName()
                font.pixelSize: 13; font.weight: Font.DemiBold; color: "#fff"
            }

            // Agent selector badge
            Rectangle {
                width: agentSelectorRow.width + 12; height: 20; radius: 4
                color: agentPickerMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.2) : Qt.rgba(0.35, 0.55, 1.0, 0.1)
                visible: agentList.length > 1

                Row { id: agentSelectorRow; anchors.centerIn: parent; spacing: 3
                    Text { text: "▾"; font.pixelSize: 8; color: "#60a5fa"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "switch"; font.pixelSize: 9; color: "#60a5fa"; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: agentPickerMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: showAgentPicker = !showAgentPicker
                }
            }

            Item { Layout.fillWidth: true }

            // Message count
            Text {
                text: messages.length + " msgs"
                font.pixelSize: 10; color: root.textMuted
                visible: messages.length > 0
            }

            // Clear chat
            Rectangle {
                width: 28; height: 28; radius: 6
                color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Canvas {
                    anchors.centerIn: parent; width: 12; height: 12
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, 12, 12);
                        ctx.strokeStyle = "#94a3b8"; ctx.lineWidth = 1.2; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.moveTo(1, 3); ctx.lineTo(11, 3); ctx.stroke();
                        ctx.strokeRect(3, 3, 6, 8);
                        ctx.beginPath(); ctx.moveTo(5, 5); ctx.lineTo(5, 9); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(7, 5); ctx.lineTo(7, 9); ctx.stroke();
                    }
                }

                MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { messages = []; } }
            }

            // Fullscreen toggle
            Rectangle {
                width: 28; height: 28; radius: 6
                color: fsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Canvas {
                    anchors.centerIn: parent; width: 12; height: 12
                    property bool fs: chatFullScreen
                    onFsChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, 12, 12);
                        ctx.strokeStyle = chatFullScreen ? "#60a5fa" : "#94a3b8"; ctx.lineWidth = 1.2; ctx.lineCap = "round";
                        if (chatFullScreen) {
                            // Contract icon
                            ctx.strokeRect(2, 2, 8, 8);
                            ctx.beginPath(); ctx.moveTo(4, 4); ctx.lineTo(8, 4); ctx.lineTo(8, 8); ctx.stroke();
                        } else {
                            // Expand icon
                            ctx.beginPath(); ctx.moveTo(1, 4); ctx.lineTo(1, 1); ctx.lineTo(4, 1); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(8, 1); ctx.lineTo(11, 1); ctx.lineTo(11, 4); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(1, 8); ctx.lineTo(1, 11); ctx.lineTo(4, 11); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(8, 11); ctx.lineTo(11, 11); ctx.lineTo(11, 8); ctx.stroke();
                        }
                    }
                }

                MouseArea { id: fsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chatFullScreen = !chatFullScreen }
            }

            // Collapse
            Rectangle {
                width: 28; height: 28; radius: 6
                color: collMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "▾"; font.pixelSize: 12; color: root.textSecondary }
                MouseArea { id: collMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { chatExpanded = false; chatFullScreen = false; } }
            }
        }
    }

    // ══════════════════════════════════════
    // ── Agent Picker Dropdown ──
    // ══════════════════════════════════════
    Rectangle {
        id: agentPicker
        anchors.top: chatHeader.bottom; anchors.topMargin: 4
        anchors.left: parent.left; anchors.leftMargin: 12
        width: 220; height: apCol.height + 12
        radius: root.radiusMd; z: 100
        color: Qt.rgba(0.08, 0.08, 0.14, 0.97)
        border.color: Qt.rgba(0.35, 0.55, 1.0, 0.2); border.width: 1
        visible: showAgentPicker && chatExpanded

        Column {
            id: apCol; anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 6; spacing: 2

            Text { text: "Select Agent"; font.pixelSize: 10; font.weight: Font.Bold; color: root.textMuted; leftPadding: 6; bottomPadding: 4 }

            Repeater {
                model: agentList

                Rectangle {
                    width: apCol.width; height: 32; radius: 4
                    color: modelData.id === selectedAgent ? Qt.rgba(0.35, 0.55, 1.0, 0.15) :
                           apItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6

                        // Dot indicator
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: modelData.enabled !== false ? root.accentGreen : root.textMuted
                        }

                        Column { Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.name || modelData.id; font.pixelSize: 11; font.weight: Font.Medium; color: "#fff" }
                        }

                        // Selected checkmark
                        Text {
                            visible: modelData.id === selectedAgent
                            text: "✓"; font.pixelSize: 11; color: root.accentBlue
                        }
                    }

                    MouseArea {
                        id: apItemMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { selectedAgent = modelData.id; showAgentPicker = false; }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════
    // ── Messages Area ──
    // ══════════════════════════════════════
    Item {
        anchors.top: chatHeader.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: inputArea.top
        anchors.margins: 1; visible: chatExpanded; clip: true

        ListView {
            id: messageList
            anchors.fill: parent; anchors.margins: 8
            model: messages; spacing: 10; clip: true

            delegate: Item {
                width: messageList.width
                height: msgBubble.height + 6

                Rectangle {
                    id: msgBubble
                    width: modelData.role === "user" ? Math.min(parent.width * 0.75, msgContentCol.implicitHeight > 30 ? parent.width * 0.75 : userMsgMetrics.width + 40)
                                                     : parent.width * 0.88
                    height: msgContentCol.height + 20
                    radius: modelData.role === "user" ? 14 : 14
                    anchors.right: modelData.role === "user" ? parent.right : undefined
                    anchors.left: modelData.role !== "user" ? parent.left : undefined

                    color: modelData.role === "user" ?
                        Qt.rgba(0.23, 0.44, 0.96, 0.15) :
                        Qt.rgba(0.08, 0.10, 0.16, 0.85)
                    border.color: modelData.role === "user" ?
                        Qt.rgba(0.35, 0.55, 1.0, 0.2) :
                        Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    // Hidden metrics for user short messages
                    TextMetrics {
                        id: userMsgMetrics
                        text: modelData.content || ""
                        font.pixelSize: 13
                    }

                    Column {
                        id: msgContentCol
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: 10; spacing: 3

                        Text {
                            text: modelData.role === "user" ? "You" : (modelData.agent || getAgentName())
                            font.pixelSize: 10; font.weight: Font.Bold
                            color: modelData.role === "user" ? "#60a5fa" : "#34d399"
                        }

                        Text {
                            width: parent.width
                            text: modelData.content || ""
                            font.pixelSize: 13; color: "#e4e4e7"
                            wrapMode: Text.Wrap; lineHeight: 1.45
                            textFormat: Text.PlainText
                        }
                    }
                }
            }

            // Streaming indicator
            footer: Item {
                width: messageList.width; height: isStreaming ? 40 : 0; visible: isStreaming

                Rectangle {
                    width: streamRow.width + 20; height: 32; radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: Qt.rgba(0.2, 0.83, 0.6, 0.15); border.width: 1

                    Row {
                        id: streamRow; anchors.centerIn: parent; spacing: 6

                        // Thinking dots animation
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 5; height: 5; radius: 2.5; color: "#34d399"
                                SequentialAnimation on opacity {
                                    running: isStreaming; loops: Animation.Infinite
                                    PauseAnimation { duration: index * 200 }
                                    NumberAnimation { to: 0.2; duration: 400 }
                                    NumberAnimation { to: 1.0; duration: 400 }
                                    PauseAnimation { duration: (2 - index) * 200 }
                                }
                            }
                        }

                        Text {
                            text: getAgentName() + " is thinking..."
                            font.pixelSize: 11; color: root.textMuted
                        }
                    }
                }
            }

            onCountChanged: Qt.callLater(function() { messageList.positionViewAtEnd(); })
        }
    }

    // ══════════════════════════════════════
    // ── Slash Command Suggestions ──
    // ══════════════════════════════════════
    Rectangle {
        id: suggestionsBox
        anchors.bottom: inputArea.top; anchors.bottomMargin: 4
        anchors.left: parent.left; anchors.leftMargin: 8
        width: sugCol.width + 16; height: sugCol.height + 12
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
                    width: 140; height: 26; radius: 4
                    color: sugItemMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.15) : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter; leftPadding: 8
                        text: modelData; font.pixelSize: 12; font.family: "monospace"; color: "#60a5fa"
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

    // ══════════════════════════════════════
    // ── Input Area ──
    // ══════════════════════════════════════
    Rectangle {
        id: inputArea
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 5; height: 40; radius: 10
        color: Qt.rgba(0.08, 0.08, 0.12, 0.9)
        border.color: chatInput.activeFocus ? Qt.rgba(0.35, 0.55, 1.0, 0.3) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 6; spacing: 8

            // AI icon (collapsed)
            Canvas {
                width: 16; height: 16; visible: !chatExpanded
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, 16, 16);
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 1.2;
                    ctx.beginPath(); ctx.arc(8, 8, 6, 0, Math.PI * 2); ctx.stroke();
                    ctx.fillStyle = "#60a5fa";
                    ctx.beginPath(); ctx.arc(5.5, 7, 1.2, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.arc(10.5, 7, 1.2, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.arc(8, 10, 1.2, 0, Math.PI * 2); ctx.fill();
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 0.6;
                    ctx.beginPath(); ctx.moveTo(5.5, 7); ctx.lineTo(8, 10); ctx.lineTo(10.5, 7); ctx.stroke();
                }
            }

            TextInput {
                id: chatInput
                Layout.fillWidth: true
                verticalAlignment: TextInput.AlignVCenter
                color: "#e4e4e7"; font.pixelSize: 13; clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ask TensorAgent AI anything..."
                    color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 13
                    visible: !parent.text && !parent.activeFocus
                }

                onActiveFocusChanged: {
                    if (activeFocus && !chatExpanded) chatExpanded = true;
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
                    else chatExpanded = false;
                }
            }

            // Agent indicator pill (when expanded)
            Rectangle {
                visible: chatExpanded
                width: agentPillText.width + 14; height: 22; radius: 11
                color: Qt.rgba(0.2, 0.83, 0.6, 0.1)
                border.color: Qt.rgba(0.2, 0.83, 0.6, 0.2); border.width: 1

                Text {
                    id: agentPillText; anchors.centerIn: parent
                    text: getAgentName(); font.pixelSize: 9; font.weight: Font.Bold; color: "#34d399"
                }
            }

            // Send button
            Rectangle {
                width: 32; height: 32; radius: 10

                gradient: Gradient {
                    GradientStop { position: 0.0; color: chatInput.text.trim() ? "#4f6ef7" : Qt.rgba(1, 1, 1, 0.06) }
                    GradientStop { position: 1.0; color: chatInput.text.trim() ? "#7c3aed" : Qt.rgba(1, 1, 1, 0.03) }
                }

                Canvas {
                    anchors.centerIn: parent; width: 14; height: 14
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, 14, 14);
                        ctx.fillStyle = chatInput.text.trim() ? "#fff" : "#666";
                        ctx.beginPath(); ctx.moveTo(7, 1); ctx.lineTo(12, 7); ctx.lineTo(8, 7);
                        ctx.lineTo(8, 13); ctx.lineTo(6, 13); ctx.lineTo(6, 7); ctx.lineTo(2, 7);
                        ctx.closePath(); ctx.fill();
                    }
                }

                // Pulse glow when text
                Rectangle {
                    visible: chatInput.text.trim() !== ""
                    anchors.fill: parent; anchors.margins: -2; radius: 12
                    color: "transparent"; border.color: Qt.rgba(0.5, 0.3, 0.95, 0.3); border.width: 1
                    SequentialAnimation on border.color {
                        running: chatInput.text.trim() !== ""; loops: Animation.Infinite
                        ColorAnimation { to: Qt.rgba(0.35, 0.55, 1.0, 0.4); duration: 1200 }
                        ColorAnimation { to: Qt.rgba(0.5, 0.3, 0.95, 0.3); duration: 1200 }
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: sendMessage()
                }
            }
        }
    }

    // ══════════════════════════════════════
    // ── Send Message ──
    // ══════════════════════════════════════
    function sendMessage() {
        var msg = chatInput.text.trim();
        if (!msg || isSending) return;

        chatExpanded = true;
        showSuggestions = false;
        showAgentPicker = false;

        // Save to history
        var hist = chatHistory.slice();
        hist.push(msg);
        if (hist.length > 50) hist = hist.slice(-50);
        chatHistory = hist;
        historyIndex = -1;

        // Add user message
        var msgs = messages.slice();
        msgs.push({ role: "user", content: msg });
        messages = msgs;
        chatInput.text = "";
        isSending = true;
        isStreaming = true;

        // Build message history for context
        var apiMessages = [];
        for (var i = 0; i < messages.length; i++) {
            apiMessages.push({ role: messages[i].role, content: messages[i].content });
        }

        // Use the agent/chat/completions endpoint for streaming
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/chat");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isSending = false;
                isStreaming = false;
                var msgs2 = messages.slice();
                try {
                    var data = JSON.parse(xhr.responseText);
                    var content = data.response || data.message || data.content || "";
                    if (data.choices && data.choices.length > 0) {
                        content = data.choices[0].message.content;
                    }
                    if (content) {
                        msgs2.push({ role: "assistant", content: cleanText(content), agent: getAgentName() });
                    } else if (data.error) {
                        msgs2.push({ role: "assistant", content: "Error: " + data.error, agent: "System" });
                    }
                } catch(e) {
                    var raw = xhr.responseText || "No response";
                    msgs2.push({ role: "assistant", content: cleanText(raw), agent: getAgentName() });
                }
                messages = msgs2;
            }
        };
        xhr.send(JSON.stringify({ message: msg, agent: selectedAgent }));
    }
}
