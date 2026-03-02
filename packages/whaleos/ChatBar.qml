import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: chatBar
    height: chatExpanded ? (chatFullScreen ? parent.height - Math.round(20 * root.sf) : Math.min(Math.round(450 * root.sf), parent.height - Math.round(70 * root.sf))) : Math.round(48 * root.sf)
    radius: root.radiusLg
    color: "transparent"
    clip: true
    z: 10

    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property bool chatExpanded: false
    property bool chatFullScreen: false
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

    Component.onCompleted: { loadAgents(); loadHistory(); }

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
        return "AI";
    }

    // ── Glass background (only when expanded) ──
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        visible: chatExpanded
        color: Qt.rgba(0.07, 0.07, 0.11, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
    }

    // ── Chat Header (expanded) ──
    Rectangle {
        id: chatHeader
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(44 * root.sf); visible: chatExpanded
        color: Qt.rgba(0.06, 0.06, 0.10, 0.98); radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(14 * root.sf); anchors.rightMargin: Math.round(8 * root.sf); spacing: Math.round(8 * root.sf)

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
                font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#fff"
            }

            Rectangle {
                width: agentSelectorRow.width + Math.round(12 * root.sf); height: Math.round(20 * root.sf); radius: Math.round(4 * root.sf)
                color: agentPickerMa.containsMouse ? Qt.rgba(0.35, 0.55, 1.0, 0.2) : Qt.rgba(0.35, 0.55, 1.0, 0.1)
                visible: agentList.length > 1

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
                        ctx.strokeStyle = "#94a3b8"; ctx.lineWidth = 1.2; ctx.lineCap = "round";
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
                        ctx.strokeStyle = chatFullScreen ? "#60a5fa" : "#94a3b8"; ctx.lineWidth = 1.2; ctx.lineCap = "round";
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

                MouseArea { id: fsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chatFullScreen = !chatFullScreen }
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
        }
    }

    // ── Messages Area ──
    Item {
        anchors.top: chatHeader.bottom; anchors.left: parent.left
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
            anchors.fill: parent; anchors.leftMargin: Math.round(12 * root.sf); anchors.rightMargin: Math.round(12 * root.sf)
            anchors.topMargin: Math.round(8 * root.sf); anchors.bottomMargin: Math.round(4 * root.sf)
            model: messages; spacing: Math.round(16 * root.sf); clip: true

            delegate: Item {
                width: messageList.width
                height: msgRow.height + (modelData.toolCalls ? toolCol.height + Math.round(8 * root.sf) : 0)

                // Tool calls display (above the message if present)
                Column {
                    id: toolCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: modelData.role !== "user" ? Math.round(36 * root.sf) : 0
                    anchors.rightMargin: modelData.role === "user" ? parent.width * 0.15 : parent.width * 0.05
                    visible: modelData.toolCalls && modelData.toolCalls.length > 0
                    spacing: Math.round(3 * root.sf)
                    bottomPadding: visible ? Math.round(8 * root.sf) : 0

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

                // Message row: avatar + bubble for assistant, right-aligned bubble for user
                Row {
                    id: msgRow
                    anchors.top: toolCol.visible ? toolCol.bottom : parent.top
                    anchors.right: modelData.role === "user" ? parent.right : undefined
                    anchors.left: modelData.role !== "user" ? parent.left : undefined
                    spacing: Math.round(8 * root.sf)
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
                            ? Math.min(messageList.width * 0.72, userMsgMetrics.width + Math.round(36 * root.sf))
                            : messageList.width - Math.round(44 * root.sf)
                        height: msgContentCol.height + Math.round(18 * root.sf)
                        radius: Math.round(12 * root.sf)

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
                            anchors.margins: modelData.role === "user" ? Math.round(10 * root.sf) : Math.round(4 * root.sf)
                            spacing: Math.round(4 * root.sf)

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
                                font.pixelSize: Math.round(13 * root.sf)
                                color: modelData.role === "user" ? "#e0e7ff" : "#e4e4e7"
                                wrapMode: Text.Wrap; lineHeight: 1.5
                                textFormat: modelData.role === "user" ? Text.PlainText : Text.StyledText
                            }
                        }
                    }
                }
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
                                text: "📋 " + (activePlan ? activePlan.title || "Plan" : "")
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
                                    text: modelData.type === "thinking" ? "💭" :
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

                    // Thinking dots (when no content yet)
                    Rectangle {
                        visible: isSending && streamingContent.length === 0 && streamingSteps.length === 0
                        width: streamRow2.width + Math.round(20 * root.sf); height: Math.round(32 * root.sf); radius: Math.round(10 * root.sf)
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.color: Qt.rgba(0.2, 0.83, 0.6, 0.15); border.width: 1

                        Row {
                            id: streamRow2; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: Math.round(5 * root.sf); height: Math.round(5 * root.sf); radius: width / 2; color: "#34d399"
                                    SequentialAnimation on opacity {
                                        running: isSending; loops: Animation.Infinite
                                        PauseAnimation { duration: index * 200 }
                                        NumberAnimation { to: 0.2; duration: 400 }
                                        NumberAnimation { to: 1.0; duration: 400 }
                                        PauseAnimation { duration: (2 - index) * 200 }
                                    }
                                }
                            }
                            Text {
                                text: getAgentName() + " is thinking..."
                                font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
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
        anchors.leftMargin: Math.round(8 * root.sf); anchors.rightMargin: Math.round(8 * root.sf)
        anchors.bottomMargin: Math.round(8 * root.sf)
        height: Math.round(44 * root.sf); radius: Math.round(12 * root.sf)
        color: Qt.rgba(0.06, 0.06, 0.10, 0.95)
        border.color: chatInput.activeFocus ? Qt.rgba(0.35, 0.55, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(14 * root.sf); anchors.rightMargin: Math.round(6 * root.sf); spacing: Math.round(8 * root.sf)

            Canvas {
                width: Math.round(16 * root.sf); height: Math.round(16 * root.sf); visible: !chatExpanded
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

            TextInput {
                id: chatInput
                Layout.fillWidth: true
                verticalAlignment: TextInput.AlignVCenter
                color: "#e4e4e7"; font.pixelSize: Math.round(13 * root.sf); clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ask TensorAgent AI anything..."
                    color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: Math.round(13 * root.sf)
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

            Rectangle {
                visible: chatExpanded
                width: agentPillText.width + Math.round(14 * root.sf); height: Math.round(22 * root.sf); radius: Math.round(11 * root.sf)
                color: Qt.rgba(0.2, 0.83, 0.6, 0.1)
                border.color: Qt.rgba(0.2, 0.83, 0.6, 0.2); border.width: 1

                Text {
                    id: agentPillText; anchors.centerIn: parent
                    text: getAgentName(); font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: "#34d399"
                }
            }

            Rectangle {
                width: Math.round(34 * root.sf); height: Math.round(34 * root.sf); radius: Math.round(10 * root.sf)

                color: chatInput.text.trim() ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }

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

                Rectangle {
                    visible: chatInput.text.trim() !== ""
                    anchors.fill: parent; anchors.margins: -2; radius: Math.round(12 * root.sf)
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

    // ── Send Message via SSE Stream ──
    function sendMessage() {
        var msg = chatInput.text.trim();
        if (!msg || isSending) return;

        chatExpanded = true;
        showSuggestions = false;
        showAgentPicker = false;

        var hist = chatHistory.slice();
        hist.push(msg);
        if (hist.length > 50) hist = hist.slice(-50);
        chatHistory = hist;
        historyIndex = -1;

        // Create per-conversation workspace folder on first message
        var workDir = "/home/" + root.currentUser + "/Works/" + root.sessionId;
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
        }
        // Auto-scroll
        Qt.callLater(function() { messageList.positionViewAtEnd(); });
    }
}
