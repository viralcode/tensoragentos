import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property var agentList: []
    property bool loading: true
    property bool showNewAgent: false
    property bool showCoordination: false
    property string coordMode: "auto"

    // New agent form fields
    property string newName: ""
    property string newRole: ""
    property string newDescription: ""
    property string newModel: ""
    property string newSystemPrompt: ""
    property string newWorkspace: ""
    property string newCapabilities: "general, code, tools"

    Component.onCompleted: loadAgents()

    function loadAgents() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/agents");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                loading = false;
                if (xhr.status === 200) {
                    try { agentList = JSON.parse(xhr.responseText); } catch(e) { agentList = []; }
                }
                if (agentList.length === 0) {
                    agentList = [{
                        id: "main", name: "OpenWhale", description: "Default general-purpose AI assistant",
                        model: "default", isDefault: true, enabled: true,
                        capabilities: ["general", "code", "tools"]
                    }];
                }
            }
        };
        xhr.send();
    }

    function createAgent() {
        if (!newName) { root.showToast("Agent name is required", "error"); return; }
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/agents");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200 || xhr.status === 201) {
                    root.showToast("Agent '" + newName + "' created successfully", "success");
                } else {
                    root.showToast("Failed to create agent (HTTP " + xhr.status + ")", "error");
                }
                showNewAgent = false;
                newName = ""; newRole = ""; newDescription = "";
                newModel = ""; newSystemPrompt = ""; newWorkspace = "";
                newCapabilities = "general, code, tools";
                loadAgents();
            }
        };
        var caps = newCapabilities.split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s; });
        xhr.send(JSON.stringify({
            name: newName, description: newDescription || newRole,
            model: newModel || undefined, systemPrompt: newSystemPrompt || undefined,
            workspace: newWorkspace || undefined, capabilities: caps, enabled: true
        }));
    }

    function deleteAgent(agentId) {
        var xhr = new XMLHttpRequest();
        xhr.open("DELETE", root.apiBase + "/agents/" + agentId);
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { root.showToast("Agent deleted", "success"); }
                else { root.showToast("Failed to delete agent (HTTP " + xhr.status + ")", "error"); }
                loadAgents();
            }
        };
        xhr.send();
    }

    function toggleAgent(agentId, enabled) {
        var xhr = new XMLHttpRequest();
        xhr.open("PUT", root.apiBase + "/agents/" + agentId);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { root.showToast("Agent " + (enabled ? "disabled" : "enabled"), "success"); }
                else { root.showToast("Failed to update agent", "error"); }
                loadAgents();
            }
        };
        xhr.send(JSON.stringify({ enabled: !enabled }));
    }

    Flickable {
        anchors.fill: parent; anchors.margins: Math.round(24 * root.sf)
        contentHeight: agentCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: agentCol; width: parent.width; spacing: Math.round(18 * root.sf)

            // ════════════════════════════════════
            // ── Header Row ──
            // ════════════════════════════════════
            RowLayout {
                width: parent.width

                Column {
                    Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                    Text { text: "Agents"; font.pixelSize: Math.round(20 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
                    Text { text: "Configure and manage AI agents for multi-agent coordination"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                }

                // Coordination Button
                Rectangle {
                    width: coordBtnRow.width + 20; height: Math.round(34 * root.sf); radius: root.radiusSm
                    color: coordBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

                    Row {
                        id: coordBtnRow; anchors.centerIn: parent; spacing: Math.round(6 * root.sf)

                        // Multi-agent icon (drawn)
                        Canvas {
                            width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.fillStyle = "#999";
                                ctx.beginPath(); ctx.arc(4, 5, 2.5, 0, Math.PI * 2); ctx.fill();
                                ctx.beginPath(); ctx.arc(10, 5, 2.5, 0, Math.PI * 2); ctx.fill();
                                ctx.beginPath(); ctx.arc(4, 13, 4, Math.PI * 1.2, Math.PI * 1.8); ctx.fill();
                                ctx.beginPath(); ctx.arc(10, 13, 4, Math.PI * 1.2, Math.PI * 1.8); ctx.fill();
                            }
                        }
                        Text {
                            text: "Coordination"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium
                            color: root.textSecondary; anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: coordBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showCoordination = !showCoordination
                    }
                }

                // + New Agent Button
                Rectangle {
                    width: newBtnRow.width + 20; height: Math.round(34 * root.sf); radius: root.radiusSm
                    color: newBtnMa.containsMouse ? Qt.darker(root.accentBlue, 1.2) : root.accentBlue

                    Row {
                        id: newBtnRow; anchors.centerIn: parent; spacing: Math.round(5 * root.sf)
                        Text { text: "+"; font.pixelSize: Math.round(15 * root.sf); font.weight: Font.Bold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "New Agent"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: newBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showNewAgent = !showNewAgent
                    }
                }
            }

            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            // ════════════════════════════════════
            // ── Multi-Agent Coordination Panel ──
            // ════════════════════════════════════
            Rectangle {
                width: parent.width; height: coordCol.height + 24; radius: root.radiusMd
                color: Qt.rgba(0.24, 0.25, 0.59, 0.08)
                border.color: Qt.rgba(0.24, 0.25, 0.59, 0.25); border.width: 1
                visible: showCoordination

                Column {
                    id: coordCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Math.round(14 * root.sf); spacing: Math.round(10 * root.sf)

                    Text {
                        text: "Multi-Agent Coordination"
                        font.pixelSize: Math.round(16 * root.sf); font.weight: Font.DemiBold; color: "#fff"
                    }

                    Text {
                        text: "Enable agents to work together on complex tasks. The coordinator routes prompts to specialized agents based on their roles."
                        font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary
                        width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.4
                    }

                    // Coordination mode selector
                    RowLayout {
                        width: parent.width; spacing: Math.round(8 * root.sf)

                        Text { text: "Coordination mode:"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted; Layout.fillWidth: true }

                        // Auto button
                        Rectangle {
                            width: Math.round(80 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                            color: coordMode === "auto" ? root.accentBlue : Qt.rgba(1, 1, 1, 0.06)
                            border.color: coordMode === "auto" ? root.accentBlue : Qt.rgba(1, 1, 1, 0.1); border.width: 1

                            Text { anchors.centerIn: parent; text: "Auto"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium; color: coordMode === "auto" ? "#fff" : root.textSecondary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: coordMode = "auto" }
                        }

                        // Manual button
                        Rectangle {
                            width: Math.round(80 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                            color: coordMode === "manual" ? root.accentBlue : Qt.rgba(1, 1, 1, 0.06)
                            border.color: coordMode === "manual" ? root.accentBlue : Qt.rgba(1, 1, 1, 0.1); border.width: 1

                            Text { anchors.centerIn: parent; text: "Manual"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.Medium; color: coordMode === "manual" ? "#fff" : root.textSecondary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: coordMode = "manual" }
                        }
                    }
                }
            }

            // ════════════════════════════════════
            // ── New Agent Dialog ──
            // ════════════════════════════════════
            Rectangle {
                width: parent.width; height: formCol.height + 24; radius: root.radiusMd
                color: Qt.rgba(0.13, 0.77, 0.37, 0.06)
                border.color: Qt.rgba(0.13, 0.77, 0.37, 0.2); border.width: 1
                visible: showNewAgent

                Column {
                    id: formCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Math.round(14 * root.sf); spacing: Math.round(12 * root.sf)

                    Text { text: "Create New Agent"; font.pixelSize: Math.round(15 * root.sf); font.weight: Font.DemiBold; color: "#fff" }

                    // Name field
                    Column { width: parent.width; spacing: Math.round(4 * root.sf)
                        Text { text: "Name *"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        Rectangle {
                            width: parent.width; height: Math.round(34 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            TextInput {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); verticalAlignment: TextInput.AlignVCenter
                                color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true
                                onTextChanged: newName = text
                                Text { anchors.fill: parent; text: "Agent name..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    // Role field
                    Column { width: parent.width; spacing: Math.round(4 * root.sf)
                        Text { text: "Role"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        Rectangle {
                            width: parent.width; height: Math.round(34 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            TextInput {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); verticalAlignment: TextInput.AlignVCenter
                                color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true
                                onTextChanged: newRole = text
                                Text { anchors.fill: parent; text: "e.g. coder, researcher, writer..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    // Description field
                    Column { width: parent.width; spacing: Math.round(4 * root.sf)
                        Text { text: "Description"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        Rectangle {
                            width: parent.width; height: Math.round(60 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            TextInput {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); verticalAlignment: TextInput.AlignTop
                                color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true; wrapMode: TextInput.WrapAnywhere
                                onTextChanged: newDescription = text
                                Text { anchors.fill: parent; text: "What does this agent do?"; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text }
                            }
                        }
                    }

                    // Model field
                    Column { width: parent.width; spacing: Math.round(4 * root.sf)
                        Text { text: "Model (optional)"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        Rectangle {
                            width: parent.width; height: Math.round(34 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            TextInput {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); verticalAlignment: TextInput.AlignVCenter
                                color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true
                                onTextChanged: newModel = text
                                Text { anchors.fill: parent; text: "Override model for this agent..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    // System Prompt field
                    Column { width: parent.width; spacing: Math.round(4 * root.sf)
                        Text { text: "System Prompt (optional)"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        Rectangle {
                            width: parent.width; height: Math.round(72 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            Flickable {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); clip: true
                                contentHeight: sysPromptInput.contentHeight
                                TextEdit {
                                    id: sysPromptInput; width: parent.width
                                    color: "#fff"; font.pixelSize: Math.round(12 * root.sf); wrapMode: TextEdit.WrapAnywhere
                                    onTextChanged: newSystemPrompt = text
                                    Text { text: "Custom system prompt for this agent..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text }
                                }
                            }
                        }
                    }

                    // Capabilities field
                    Column { width: parent.width; spacing: Math.round(4 * root.sf)
                        Text { text: "Capabilities (comma separated)"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        Rectangle {
                            width: parent.width; height: Math.round(34 * root.sf); radius: root.radiusSm
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            TextInput {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); verticalAlignment: TextInput.AlignVCenter
                                color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true; text: "general, code, tools"
                                onTextChanged: newCapabilities = text
                            }
                        }
                    }

                    // Buttons
                    RowLayout {
                        width: parent.width; spacing: Math.round(8 * root.sf)
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: Math.round(70 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                            color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary }
                            MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: showNewAgent = false }
                        }

                        Rectangle {
                            width: Math.round(90 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                            color: createMa.containsMouse ? Qt.darker(root.accentGreen, 1.2) : root.accentGreen
                            Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { id: createMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: createAgent() }
                        }
                    }
                }
            }

            // ════════════════════════════════════
            // ── Agent List ──
            // ════════════════════════════════════
            Repeater {
                model: agentList

                Rectangle {
                    id: agentCard
                    width: agentCol.width; height: aCardCol.height + 24
                    radius: root.radiusMd; color: root.bgCard
                    border.color: modelData.isDefault ? Qt.rgba(0.24, 0.25, 0.59, 0.35) : root.borderColor
                    border.width: 1

                    Column {
                        id: aCardCol; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Math.round(14 * root.sf); spacing: Math.round(8 * root.sf)

                        // ── Agent header ──
                        RowLayout {
                            width: parent.width; spacing: Math.round(10 * root.sf)

                            // Robot icon (drawn)
                            Rectangle {
                                width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 8
                                color: Qt.rgba(0.23, 0.51, 0.96, 0.1)

                                Canvas {
                                    anchors.centerIn: parent; width: Math.round(20 * root.sf); height: Math.round(20 * root.sf)
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        ctx.fillStyle = "#3b82f6";
                                        // Head
                                        ctx.beginPath();
                                        ctx.roundRect(3, 4, 14, 12, [3]);
                                        ctx.fill();
                                        // Eyes
                                        ctx.fillStyle = "#0a0a0a";
                                        ctx.beginPath(); ctx.arc(7.5, 9, 1.8, 0, Math.PI * 2); ctx.fill();
                                        ctx.beginPath(); ctx.arc(12.5, 9, 1.8, 0, Math.PI * 2); ctx.fill();
                                        // Antenna
                                        ctx.strokeStyle = "#3b82f6"; ctx.lineWidth = 1.5;
                                        ctx.beginPath(); ctx.moveTo(10, 4); ctx.lineTo(10, 1); ctx.stroke();
                                        ctx.fillStyle = "#3b82f6";
                                        ctx.beginPath(); ctx.arc(10, 0.5, 1.5, 0, Math.PI * 2); ctx.fill();
                                        // Mouth
                                        ctx.strokeStyle = "#0a0a0a"; ctx.lineWidth = 1;
                                        ctx.beginPath(); ctx.moveTo(7, 13); ctx.lineTo(13, 13); ctx.stroke();
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true; spacing: Math.round(1 * root.sf)

                                Row { spacing: Math.round(8 * root.sf)
                                    Text {
                                        text: modelData.name || "Agent"
                                        font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff"
                                    }
                                    // DEFAULT badge
                                    Rectangle {
                                        visible: modelData.isDefault === true
                                        width: defText.width + 10; height: Math.round(18 * root.sf); radius: 3
                                        color: Qt.rgba(0.24, 0.25, 0.59, 0.3)
                                        anchors.verticalCenter: parent.children[0].verticalCenter
                                        Text { id: defText; anchors.centerIn: parent; text: "DEFAULT"; font.pixelSize: Math.round(9 * root.sf); font.weight: Font.Bold; color: "#818cf8" }
                                    }
                                }

                                Text {
                                    text: modelData.description || "agent"
                                    font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                                }
                            }

                            // Toggle switch
                            Rectangle {
                                width: Math.round(44 * root.sf); height: Math.round(24 * root.sf); radius: 12
                                color: modelData.enabled ? root.accentBlue : Qt.rgba(1, 1, 1, 0.15)

                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: Math.round(18 * root.sf); height: Math.round(18 * root.sf); radius: 9
                                    color: "#fff"
                                    x: modelData.enabled ? parent.width - width - 3 : 3
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleAgent(modelData.id, modelData.enabled)
                                }
                            }
                        }

                        // ── Agent details ──
                        Text {
                            visible: (modelData.description || "") !== ""
                            text: modelData.description || ""
                            font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary
                            width: parent.width; wrapMode: Text.WordWrap
                        }

                        // Model info
                        Row { spacing: Math.round(6 * root.sf)
                            Text { text: "MODEL:"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Bold; color: root.textMuted }
                            Text { text: modelData.model || "default"; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary; font.family: "monospace" }
                        }

                        // Capability tags
                        Flow {
                            width: parent.width; spacing: Math.round(6 * root.sf)

                            Repeater {
                                model: modelData.capabilities || []

                                Rectangle {
                                    width: capText.width + 14; height: Math.round(22 * root.sf); radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                    Text {
                                        id: capText; anchors.centerIn: parent
                                        text: modelData; font.pixelSize: Math.round(10 * root.sf); color: root.textSecondary
                                    }
                                }
                            }
                        }

                        // Delete button (non-default only)
                        RowLayout {
                            visible: !modelData.isDefault
                            width: parent.width; spacing: Math.round(8 * root.sf)

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: delRow.width + 16; height: Math.round(26 * root.sf); radius: root.radiusSm
                                color: delMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1

                                Row {
                                    id: delRow; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                                    Canvas {
                                        width: Math.round(10 * root.sf); height: Math.round(10 * root.sf); anchors.verticalCenter: parent.verticalCenter
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            ctx.strokeStyle = "#ef4444"; ctx.lineWidth = 1.2;
                                            ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(8, 8); ctx.stroke();
                                            ctx.beginPath(); ctx.moveTo(8, 2); ctx.lineTo(2, 8); ctx.stroke();
                                        }
                                    }
                                    Text { text: "Delete"; font.pixelSize: Math.round(11 * root.sf); color: root.accentRed; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteAgent(modelData.id) }
                            }
                        }
                    }
                }
            }

            // ── Empty state ──
            Column {
                visible: agentList.length === 0 && !loading
                width: parent.width; spacing: Math.round(8 * root.sf)
                anchors.horizontalCenter: parent.horizontalCenter

                Item { width: Math.round(1 * root.sf); height: Math.round(30 * root.sf) }

                Canvas {
                    width: Math.round(48 * root.sf); height: Math.round(48 * root.sf); anchors.horizontalCenter: parent.horizontalCenter
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#666";
                        ctx.beginPath(); ctx.roundRect(8, 10, 32, 28, [6]); ctx.fill();
                        ctx.fillStyle = "#1f1f1f";
                        ctx.beginPath(); ctx.arc(18, 22, 4, 0, Math.PI * 2); ctx.fill();
                        ctx.beginPath(); ctx.arc(30, 22, 4, 0, Math.PI * 2); ctx.fill();
                        ctx.strokeStyle = "#1f1f1f"; ctx.lineWidth = 2;
                        ctx.beginPath(); ctx.moveTo(18, 30); ctx.lineTo(30, 30); ctx.stroke();
                        ctx.strokeStyle = "#666"; ctx.lineWidth = 2;
                        ctx.beginPath(); ctx.moveTo(24, 10); ctx.lineTo(24, 4); ctx.stroke();
                        ctx.fillStyle = "#666";
                        ctx.beginPath(); ctx.arc(24, 3, 3, 0, Math.PI * 2); ctx.fill();
                    }
                }

                Text {
                    text: "No agents configured"
                    font.pixelSize: Math.round(14 * root.sf); color: root.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Click + New Agent to create one"
                    font.pixelSize: Math.round(12 * root.sf); color: root.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Loading indicator
            Text {
                visible: loading
                text: "Loading agents..."
                font.pixelSize: Math.round(12 * root.sf); color: root.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item { width: Math.round(1 * root.sf); height: Math.round(20 * root.sf) }
        }
    }
}
