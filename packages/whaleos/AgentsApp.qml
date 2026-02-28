import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property var agentList: []
    property bool loading: true
    property bool showNewAgent: false
    property bool showCoordination: false
    property string newName: ""
    property string newRole: ""
    property string newDesc: ""
    property string newModel: "default"

    Component.onCompleted: loadAgents()

    function loadAgents() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/agents");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try { var d = JSON.parse(xhr.responseText); agentList = d.agents || []; } catch(e) {}
                }
                if (agentList.length === 0) {
                    agentList = [{ id: "default", name: "OpenWhale", role: "agent", description: "Default general-purpose AI assistant", model: "default", isDefault: true, enabled: true, capabilities: ["general","code","tools"] }];
                }
                loading = false;
            }
        };
        xhr.send();
    }

    function createAgent() {
        if (!newName) return;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/agents");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                showNewAgent = false; newName = ""; newRole = ""; newDesc = "";
                loadAgents();
            }
        };
        xhr.send(JSON.stringify({ name: newName, role: newRole || "agent", description: newDesc, model: newModel }));
    }

    function deleteAgent(agentId) {
        var xhr = new XMLHttpRequest();
        xhr.open("DELETE", root.apiBase + "/agents/" + agentId);
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() { if (xhr.readyState === 4) loadAgents(); };
        xhr.send();
    }

    function toggleAgent(agentId, enabled) {
        var xhr = new XMLHttpRequest();
        xhr.open("PUT", root.apiBase + "/agents/" + agentId);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() { if (xhr.readyState === 4) loadAgents(); };
        xhr.send(JSON.stringify({ enabled: !enabled }));
    }

    Flickable {
        anchors.fill: parent; anchors.margins: 16
        contentHeight: agentCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: agentCol; width: parent.width; spacing: 12

            // Header
            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "Agents"; font.pixelSize: 20; font.weight: Font.Bold; color: root.textPrimary }
                    Text { text: "Configure and manage AI agents for multi-agent coordination"; font.pixelSize: 12; color: root.textMuted }
                }
                Rectangle {
                    width: coordLabel.width + 24; height: 32; radius: root.radiusSm
                    color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                    Row { anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf0c0"; font.family: root.iconFont; font.pixelSize: 12; color: root.textSecondary }
                        Text { id: coordLabel; text: "Coordination"; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.textSecondary }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showCoordination = !showCoordination }
                }
                Rectangle {
                    width: newLabel.width + 24; height: 32; radius: root.radiusSm; color: root.accentBlue
                    Row { anchors.centerIn: parent; spacing: 4
                        Text { text: "+"; font.pixelSize: 14; font.weight: Font.Bold; color: "white" }
                        Text { id: newLabel; text: "New Agent"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "white" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showNewAgent = true }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.borderColor }

            // Coordination panel
            Rectangle {
                width: parent.width; height: coordCol.height + 20; radius: root.radiusMd
                color: Qt.rgba(0.39,0.4,0.95,0.08); border.color: Qt.rgba(0.39,0.4,0.95,0.2); border.width: 1
                visible: showCoordination

                Column {
                    id: coordCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12; spacing: 8
                    Text { text: "Multi-Agent Coordination"; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.textPrimary }
                    Text { text: "Enable agents to work together on complex tasks. The coordinator routes prompts to specialized agents based on their roles."; font.pixelSize: 12; color: root.textSecondary; wrapMode: Text.WordWrap; width: parent.width }
                    RowLayout {
                        spacing: 8; width: parent.width
                        Text { text: "Coordination mode:"; font.pixelSize: 12; color: root.textMuted }
                        Rectangle { width: 80; height: 26; radius: root.radiusSm; color: root.accentBlue; Text { anchors.centerIn: parent; text: "Auto"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "white" } }
                        Rectangle { width: 80; height: 26; radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06); Text { anchors.centerIn: parent; text: "Manual"; font.pixelSize: 11; color: root.textSecondary } }
                    }
                }
            }

            // New Agent form
            Rectangle {
                width: parent.width; height: formCol.height + 20; radius: root.radiusMd
                color: Qt.rgba(0.13,0.77,0.37,0.08); border.color: Qt.rgba(0.13,0.77,0.37,0.2); border.width: 1
                visible: showNewAgent

                Column {
                    id: formCol; anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12; spacing: 10

                    Text { text: "Create New Agent"; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.textPrimary }

                    Column { width: parent.width; spacing: 4
                        Text { text: "Name"; font.pixelSize: 11; color: root.textMuted }
                        Rectangle { width: parent.width; height: 32; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: 8; color: root.textPrimary; font.pixelSize: 12; clip: true; onTextChanged: newName = text
                                Text { anchors.fill: parent; text: "Agent name..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 12; visible: !parent.text }
                            }
                        }
                    }
                    Column { width: parent.width; spacing: 4
                        Text { text: "Role"; font.pixelSize: 11; color: root.textMuted }
                        Rectangle { width: parent.width; height: 32; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: 8; color: root.textPrimary; font.pixelSize: 12; clip: true; onTextChanged: newRole = text
                                Text { anchors.fill: parent; text: "e.g. coder, researcher, writer..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 12; visible: !parent.text }
                            }
                        }
                    }
                    Column { width: parent.width; spacing: 4
                        Text { text: "Description"; font.pixelSize: 11; color: root.textMuted }
                        Rectangle { width: parent.width; height: 50; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: 8; color: root.textPrimary; font.pixelSize: 12; clip: true; wrapMode: TextInput.Wrap; onTextChanged: newDesc = text
                                Text { anchors.fill: parent; text: "What does this agent do?"; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 12; visible: !parent.text }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width; spacing: 8
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 60; height: 28; radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06);
                            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: root.textSecondary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showNewAgent = false }
                        }
                        Rectangle { width: 60; height: 28; radius: root.radiusSm; color: root.accentBlue;
                            Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "white" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: createAgent() }
                        }
                    }
                }
            }

            // Agent list
            Repeater {
                model: agentList
                Rectangle {
                    width: agentCol.width; height: aCol.height + 20
                    radius: root.radiusMd; color: root.bgCard
                    border.color: modelData.isDefault ? Qt.rgba(0.39,0.4,0.95,0.3) : root.borderColor; border.width: 1

                    Column {
                        id: aCol; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: 12; spacing: 6

                        RowLayout {
                            width: parent.width; spacing: 10
                            Rectangle {
                                width: 36; height: 36; radius: 10; color: Qt.rgba(0.39,0.4,0.95,0.15)
                                Text { anchors.centerIn: parent; text: "\uf544"; font.family: root.iconFont; font.pixelSize: 16; color: root.accentBlue }
                            }
                            Column {
                                Layout.fillWidth: true; spacing: 2
                                Row { spacing: 6
                                    Text { text: modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.textPrimary }
                                    Rectangle { visible: modelData.isDefault; width: defText.width + 8; height: 16; radius: 3; color: Qt.rgba(0.39,0.4,0.95,0.2)
                                        Text { id: defText; anchors.centerIn: parent; text: "DEFAULT"; font.pixelSize: 8; font.weight: Font.Bold; color: root.accentBlue }
                                    }
                                }
                                Text { text: modelData.role || "agent"; font.pixelSize: 11; color: root.textMuted }
                            }

                            // Toggle
                            Rectangle {
                                width: 40; height: 22; radius: 11
                                color: modelData.enabled ? root.accentBlue : Qt.rgba(1,1,1,0.1)
                                Rectangle {
                                    width: 18; height: 18; radius: 9; y: 2
                                    x: modelData.enabled ? 20 : 2
                                    color: "white"
                                    Behavior on x { NumberAnimation { duration: 150 } }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggleAgent(modelData.id, modelData.enabled) }
                            }
                        }

                        Text { text: modelData.description || ""; font.pixelSize: 12; color: root.textSecondary; wrapMode: Text.WordWrap; width: parent.width; visible: !!modelData.description }
                        Text { text: "MODEL: " + (modelData.model || "default"); font.pixelSize: 10; color: root.textMuted; font.family: "monospace" }

                        // Capabilities
                        Row {
                            spacing: 4; visible: modelData.capabilities && modelData.capabilities.length > 0
                            Repeater {
                                model: modelData.capabilities || []
                                Rectangle {
                                    width: capText.width + 10; height: 18; radius: 3; color: root.bgElevated
                                    Text { id: capText; anchors.centerIn: parent; text: modelData; font.pixelSize: 9; color: root.textSecondary }
                                }
                            }
                        }

                        // Delete button (not for default)
                        Rectangle {
                            visible: !modelData.isDefault; width: 60; height: 24; radius: root.radiusSm
                            color: Qt.rgba(0.94,0.27,0.27,0.1); border.color: Qt.rgba(0.94,0.27,0.27,0.3); border.width: 1
                            Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 10; color: "#ef4444" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deleteAgent(modelData.id) }
                        }
                    }
                }
            }
        }
    }
}
