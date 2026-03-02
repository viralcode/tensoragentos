import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property var allServers: []
    property var filteredServers: []
    property bool loading: true
    property string searchText: ""
    property string activeFilter: "all"  // "all", "running", "1", "2", "3"
    property var configServerId: ""
    property var configEnvVars: []
    property var configValues: ({})
    property bool showConfigDialog: false

    Component.onCompleted: loadServers()

    function loadServers() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/mcp/servers");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    allServers = d.servers || [];
                } catch(e) {}
                filterServers();
                loading = false;
            }
        };
        xhr.send();
    }

    function filterServers() {
        var result = [];
        var q = searchText.toLowerCase();
        for (var i = 0; i < allServers.length; i++) {
            var s = allServers[i];
            if (q && s.name.toLowerCase().indexOf(q) === -1 && s.description.toLowerCase().indexOf(q) === -1) continue;
            if (activeFilter === "running" && !s.running) continue;
            if (activeFilter === "1" && s.tier !== 1) continue;
            if (activeFilter === "2" && s.tier !== 2) continue;
            if (activeFilter === "3" && s.tier !== 3) continue;
            result.push(s);
        }
        filteredServers = result;
    }

    function startServer(serverId) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/mcp/servers/" + serverId + "/start");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    if (d.success) {
                        root.showToast(serverId + " started with " + (d.tools ? d.tools.length : 0) + " tools", "success");
                    } else {
                        root.showToast(d.error || "Failed to start " + serverId, "error");
                    }
                } catch(e) {}
                loadServers();
            }
        };
        xhr.send("{}");
    }

    function stopServer(serverId) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/mcp/servers/" + serverId + "/stop");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                root.showToast(serverId + " stopped", "info");
                loadServers();
            }
        };
        xhr.send("{}");
    }

    function configureServer(serverId, envObj) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/mcp/servers/" + serverId + "/configure");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                root.showToast("Configuration saved for " + serverId, "success");
                loadServers();
            }
        };
        xhr.send(JSON.stringify({ env: envObj }));
    }

    function openConfig(serverId, envVars) {
        configServerId = serverId;
        configEnvVars = envVars;
        configValues = {};
        showConfigDialog = true;
    }

    function getTierLabel(tier) {
        if (tier === 1) return "CORE";
        if (tier === 2) return "PRO";
        return "STORE";
    }
    function getTierColor(tier) {
        if (tier === 1) return "#22c55e";
        if (tier === 2) return "#a855f7";
        return "#3b82f6";
    }
    function getCategoryColor(cat) {
        if (cat === "ai") return "#f59e0b";
        if (cat === "search") return "#06b6d4";
        if (cat === "data") return "#10b981";
        if (cat === "dev") return "#8b5cf6";
        if (cat === "productivity") return "#ec4899";
        if (cat === "analytics") return "#f97316";
        return "#64748b";
    }

    Flickable {
        anchors.fill: parent; anchors.margins: Math.round(24 * root.sf)
        contentHeight: mainCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainCol; width: parent.width; spacing: Math.round(20 * root.sf)

            // ─── Header ───
            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                    Text { text: "MCP Apps"; font.pixelSize: Math.round(20 * root.sf); font.bold: true; color: root.textPrimary }
                    Text { text: allServers.length + " servers available · " + allServers.filter(function(s){return s.running}).length + " running"; font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary }
                }
                Rectangle {
                    width: Math.round(220 * root.sf); height: Math.round(32 * root.sf)
                    radius: Math.round(8 * root.sf); color: Qt.rgba(1,1,1,0.06)
                    border.color: Qt.rgba(1,1,1,0.1)
                    TextInput {
                        anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                        font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary
                        clip: true; selectByMouse: true
                        onTextChanged: { searchText = text; filterServers() }
                        Text { anchors.fill: parent; text: "Search apps..."; color: Qt.rgba(1,1,1,0.25); visible: !parent.text; font.pixelSize: Math.round(12 * root.sf) }
                    }
                }
                Rectangle {
                    width: Math.round(90 * root.sf); height: Math.round(32 * root.sf)
                    radius: Math.round(8 * root.sf); color: "#6366f1"
                    Text { anchors.centerIn: parent; text: "↻ Refresh"; font.pixelSize: Math.round(11 * root.sf); color: "white" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: loadServers() }
                }
            }

            // ─── Filter Pills ───
            Flow {
                width: parent.width; spacing: Math.round(8 * root.sf)
                Repeater {
                    model: [
                        { key: "all", label: "All" },
                        { key: "running", label: "Running" },
                        { key: "1", label: "Core" },
                        { key: "2", label: "Pro" },
                        { key: "3", label: "Store" }
                    ]
                    Rectangle {
                        width: Math.round(70 * root.sf); height: Math.round(28 * root.sf)
                        radius: Math.round(14 * root.sf)
                        color: activeFilter === modelData.key ? "#6366f1" : Qt.rgba(1,1,1,0.06)
                        border.color: activeFilter === modelData.key ? "#818cf8" : Qt.rgba(1,1,1,0.1)
                        Text {
                            anchors.centerIn: parent; text: modelData.label
                            font.pixelSize: Math.round(11 * root.sf); font.bold: activeFilter === modelData.key
                            color: activeFilter === modelData.key ? "white" : root.textSecondary
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { activeFilter = modelData.key; filterServers() }
                        }
                    }
                }
            }

            // ─── Loading Indicator ───
            Text {
                visible: loading
                text: "Loading MCP servers..."
                font.pixelSize: Math.round(13 * root.sf); color: root.textSecondary
            }

            // ─── Server Cards Grid ───
            Grid {
                width: parent.width
                columns: Math.max(1, Math.floor(parent.width / Math.round(320 * root.sf)))
                rowSpacing: Math.round(14 * root.sf)
                columnSpacing: Math.round(14 * root.sf)
                visible: !loading

                Repeater {
                    model: filteredServers
                    Rectangle {
                        width: Math.round(300 * root.sf); height: Math.round(160 * root.sf)
                        radius: Math.round(12 * root.sf)
                        color: Qt.rgba(1,1,1,0.04)
                        border.color: modelData.running ? Qt.rgba(0.39, 0.82, 0.38, 0.4) : Qt.rgba(1,1,1,0.08)
                        border.width: modelData.running ? 2 : 1

                        // Subtle glow for running servers
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            visible: modelData.running
                            color: "transparent"
                            border.color: Qt.rgba(0.39, 0.82, 0.38, 0.15)
                            border.width: 3
                        }

                        Column {
                            anchors.fill: parent; anchors.margins: Math.round(14 * root.sf)
                            spacing: Math.round(8 * root.sf)

                            // Top row: name + tier badge + status
                            RowLayout {
                                width: parent.width
                                Text {
                                    text: modelData.name
                                    font.pixelSize: Math.round(14 * root.sf); font.bold: true
                                    color: root.textPrimary; Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                // Tier badge
                                Rectangle {
                                    width: Math.round(42 * root.sf); height: Math.round(18 * root.sf)
                                    radius: Math.round(4 * root.sf)
                                    color: Qt.rgba(0,0,0,0.3); border.color: getTierColor(modelData.tier)
                                    Text {
                                        anchors.centerIn: parent; text: getTierLabel(modelData.tier)
                                        font.pixelSize: Math.round(9 * root.sf); font.bold: true
                                        color: getTierColor(modelData.tier)
                                    }
                                }
                                // Status dot
                                Rectangle {
                                    width: Math.round(10 * root.sf); height: Math.round(10 * root.sf)
                                    radius: width / 2
                                    color: modelData.running ? "#22c55e" : Qt.rgba(1,1,1,0.2)
                                }
                            }

                            // Category pill
                            Rectangle {
                                width: catLabel.width + Math.round(12 * root.sf); height: Math.round(18 * root.sf)
                                radius: Math.round(9 * root.sf)
                                color: Qt.rgba(0,0,0,0.3); border.color: getCategoryColor(modelData.category)
                                Text {
                                    id: catLabel; anchors.centerIn: parent
                                    text: modelData.category; font.pixelSize: Math.round(9 * root.sf)
                                    color: getCategoryColor(modelData.category); font.capitalization: Font.AllUppercase
                                }
                            }

                            // Description
                            Text {
                                width: parent.width; text: modelData.description
                                font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary
                                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            }

                            // Tool count when running
                            Text {
                                visible: modelData.running
                                text: modelData.toolCount + " tools active"
                                font.pixelSize: Math.round(10 * root.sf); color: "#22c55e"
                            }

                            // Bottom row: action buttons
                            RowLayout {
                                width: parent.width; spacing: Math.round(8 * root.sf)

                                // Configure button (if needs env vars)
                                Rectangle {
                                    visible: modelData.needsConfig
                                    width: Math.round(80 * root.sf); height: Math.round(26 * root.sf)
                                    radius: Math.round(6 * root.sf)
                                    color: configMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                                    border.color: Qt.rgba(1,1,1,0.15)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent; text: "⚙ Config"
                                        font.pixelSize: Math.round(10 * root.sf); color: "#94a3b8"
                                    }
                                    MouseArea {
                                        id: configMouse; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: openConfig(modelData.id, modelData.envVars)
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Start/Stop button
                                Rectangle {
                                    width: Math.round(80 * root.sf); height: Math.round(26 * root.sf)
                                    radius: Math.round(6 * root.sf)
                                    color: modelData.running
                                        ? (stopMouse.containsMouse ? Qt.rgba(0.94,0.27,0.22,0.2) : Qt.rgba(0.94,0.27,0.22,0.1))
                                        : (startMouse.containsMouse ? Qt.rgba(0.13,0.78,0.27,0.2) : Qt.rgba(0.13,0.78,0.27,0.1))
                                    border.color: modelData.running ? "#ef4444" : "#22c55e"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.running ? "■ Stop" : "▶ Start"
                                        font.pixelSize: Math.round(10 * root.sf); font.bold: true
                                        color: modelData.running ? "#ef4444" : "#22c55e"
                                    }
                                    MouseArea {
                                        id: startMouse; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        visible: !modelData.running
                                        onClicked: {
                                            if (modelData.needsConfig && !modelData.configured) {
                                                openConfig(modelData.id, modelData.envVars);
                                            } else {
                                                startServer(modelData.id);
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: stopMouse; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        visible: modelData.running
                                        onClicked: stopServer(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─── Empty State ───
            Text {
                visible: !loading && filteredServers.length === 0
                text: "No servers found matching your search"
                font.pixelSize: Math.round(13 * root.sf); color: root.textSecondary
            }
        }
    }

    // ═══════════════════════════════════════════
    // Configuration Dialog
    // ═══════════════════════════════════════════
    Rectangle {
        id: configDialog
        visible: showConfigDialog
        anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.6)
        z: 100

        MouseArea { anchors.fill: parent; onClicked: showConfigDialog = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(400 * root.sf); height: configDialogCol.height + Math.round(40 * root.sf)
            radius: Math.round(16 * root.sf)
            color: Qt.rgba(0.1, 0.1, 0.14, 0.95)
            border.color: Qt.rgba(1,1,1,0.15)

            MouseArea { anchors.fill: parent } // Prevent click-through

            Column {
                id: configDialogCol
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: Math.round(20 * root.sf)
                spacing: Math.round(14 * root.sf)

                Text {
                    text: "Configure " + configServerId
                    font.pixelSize: Math.round(16 * root.sf); font.bold: true; color: root.textPrimary
                }
                Text {
                    text: "Enter the required API keys to enable this MCP server."
                    font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary
                    width: parent.width; wrapMode: Text.WordWrap
                }

                Repeater {
                    model: configEnvVars
                    Column {
                        width: parent.width; spacing: Math.round(4 * root.sf)
                        Text {
                            text: modelData; font.pixelSize: Math.round(11 * root.sf)
                            color: root.textSecondary; font.bold: true
                        }
                        Rectangle {
                            width: parent.width; height: Math.round(34 * root.sf)
                            radius: Math.round(8 * root.sf); color: Qt.rgba(1,1,1,0.06)
                            border.color: Qt.rgba(1,1,1,0.12)
                            TextInput {
                                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                                font.pixelSize: Math.round(12 * root.sf); color: root.textPrimary
                                clip: true; selectByMouse: true; echoMode: TextInput.Password
                                onTextChanged: {
                                    var cv = configValues;
                                    cv[modelData] = text;
                                    configValues = cv;
                                }
                                Text {
                                    anchors.fill: parent; text: "Enter value..."
                                    color: Qt.rgba(1,1,1,0.2); visible: !parent.text
                                    font.pixelSize: Math.round(12 * root.sf)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width; spacing: Math.round(10 * root.sf)
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: Math.round(80 * root.sf); height: Math.round(30 * root.sf)
                        radius: Math.round(8 * root.sf); color: Qt.rgba(1,1,1,0.06)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showConfigDialog = false }
                    }
                    Rectangle {
                        width: Math.round(120 * root.sf); height: Math.round(30 * root.sf)
                        radius: Math.round(8 * root.sf); color: "#6366f1"
                        Text { anchors.centerIn: parent; text: "Save & Start"; font.pixelSize: Math.round(11 * root.sf); font.bold: true; color: "white" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                configureServer(configServerId, configValues);
                                showConfigDialog = false;
                                // Auto-start after configuring
                                Qt.callLater(function() { startServer(configServerId) });
                            }
                        }
                    }
                }
            }
        }
    }
}
