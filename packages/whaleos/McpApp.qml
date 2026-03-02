import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property var allTools: []
    property var filteredTools: []
    property bool loading: true
    property string searchText: ""
    property string activeCategory: "all"
    property var categories: ["all"]

    Component.onCompleted: loadTools()

    function loadTools() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/tools");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try { var d = JSON.parse(xhr.responseText); allTools = d.tools || []; } catch(e) {}
                }
                if (allTools.length === 0) {
                    allTools = [
                        { name: "exec", description: "Execute shell commands and scripts", category: "system", disabled: false, requiresApproval: true },
                        { name: "browser", description: "Web browsing and automation with Playwright", category: "web", disabled: false, requiresApproval: false },
                        { name: "web_fetch", description: "Fetch and parse web content", category: "web", disabled: false, requiresApproval: false },
                        { name: "file", description: "Read and write files on the host system", category: "system", disabled: false, requiresApproval: true },
                        { name: "image", description: "Generate and manipulate images", category: "media", disabled: false, requiresApproval: false },
                        { name: "screenshot", description: "Capture screenshots of the screen", category: "media", disabled: false, requiresApproval: false },
                        { name: "tts", description: "Text-to-speech synthesis", category: "media", disabled: false, requiresApproval: false },
                        { name: "memory", description: "Persistent vector memory with semantic search", category: "utility", disabled: false, requiresApproval: false },
                        { name: "db_query", description: "SQLite database operations and queries", category: "utility", disabled: false, requiresApproval: true },
                        { name: "code_exec", description: "Execute code in sandboxed environment", category: "system", disabled: false, requiresApproval: true },
                        { name: "cron", description: "Schedule and manage cron jobs", category: "system", disabled: false, requiresApproval: true },
                        { name: "canvas", description: "Draw and create visual content", category: "media", disabled: true, requiresApproval: false },
                        { name: "nodes", description: "Node-based workflow automation", category: "utility", disabled: true, requiresApproval: false },
                        { name: "extend", description: "Create custom tool extensions", category: "utility", disabled: false, requiresApproval: false },
                        { name: "planning", description: "Task decomposition and planning", category: "utility", disabled: false, requiresApproval: false },
                        { name: "git", description: "Git version control operations", category: "system", disabled: false, requiresApproval: true },
                        { name: "docker", description: "Docker container management", category: "system", disabled: true, requiresApproval: true },
                        { name: "ssh", description: "SSH remote server access", category: "system", disabled: true, requiresApproval: true },
                        { name: "qr_code", description: "Generate and decode QR codes", category: "utility", disabled: true, requiresApproval: false },
                        { name: "spreadsheet", description: "Create and edit spreadsheets", category: "utility", disabled: true, requiresApproval: false },
                        { name: "zip", description: "Compress and extract archives", category: "utility", disabled: false, requiresApproval: false },
                        { name: "email_send", description: "Send emails via SMTP", category: "communication", disabled: true, requiresApproval: true },
                        { name: "pdf", description: "Generate and parse PDF documents", category: "utility", disabled: false, requiresApproval: false },
                        { name: "system_info", description: "System hardware and OS information", category: "system", disabled: false, requiresApproval: false },
                        { name: "camera_snap", description: "Capture photos from camera", category: "device", disabled: true, requiresApproval: true },
                        { name: "camera_record", description: "Record video from camera", category: "device", disabled: true, requiresApproval: true },
                        { name: "screen_record", description: "Record screen activity", category: "device", disabled: true, requiresApproval: true },
                        { name: "skill_creator", description: "Create and edit AI skills", category: "utility", disabled: false, requiresApproval: false },
                        { name: "clipboard", description: "Read and write system clipboard", category: "utility", disabled: false, requiresApproval: false },
                        { name: "shortcuts", description: "macOS Shortcuts automation", category: "system", disabled: true, requiresApproval: false },
                        { name: "calendar_event", description: "Create calendar events", category: "utility", disabled: true, requiresApproval: false },
                        { name: "slides", description: "Create presentation slides", category: "media", disabled: true, requiresApproval: false }
                    ];
                }
                // Extract categories
                var cats = ["all"];
                for (var i = 0; i < allTools.length; i++) {
                    var cat = allTools[i].category || "other";
                    if (cats.indexOf(cat) === -1) cats.push(cat);
                }
                categories = cats;
                filterTools();
                loading = false;
            }
        };
        xhr.send();
    }

    function filterTools() {
        var result = [];
        var q = searchText.toLowerCase();
        for (var i = 0; i < allTools.length; i++) {
            var t = allTools[i];
            var matchSearch = !q || t.name.toLowerCase().indexOf(q) >= 0 || (t.description || "").toLowerCase().indexOf(q) >= 0;
            var matchCat = activeCategory === "all" || t.category === activeCategory;
            if (matchSearch && matchCat) result.push(t);
        }
        filteredTools = result;
    }

    function toggleTool(toolName, enabled) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/tools/" + toolName + "/toggle");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { root.showToast(toolName + (enabled ? " enabled" : " disabled"), "success"); }
                else { root.showToast("Failed to toggle " + toolName, "error"); }
                loadTools();
            }
        };
        xhr.send(JSON.stringify({ disabled: !enabled }));
    }

    function getCategoryColor(cat) {
        if (cat === "system") return "#f59e0b";
        if (cat === "web") return "#a855f7";
        if (cat === "media") return "#22c55e";
        if (cat === "utility") return "#3b82f6";
        if (cat === "communication") return "#a855f7";
        if (cat === "device") return "#22c55e";
        return "#6366f1";
    }

    function getToolIcon(name) {
        var icons = { exec: "\uf120", browser: "\uf0ac", web_fetch: "\uf019", file: "\uf15b", image: "\uf03e",
            screenshot: "\uf030", tts: "\uf028", memory: "\uf1c0", db_query: "\uf1c0", code_exec: "\uf121",
            cron: "\uf017", canvas: "\uf304", nodes: "\uf126", extend: "\uf12e", planning: "\uf5dc",
            git: "\uf841", docker: "\uf395", ssh: "\uf233", qr_code: "\uf029", spreadsheet: "\uf0ce",
            zip: "\uf187", email_send: "\uf0e0", pdf: "\uf1c1", system_info: "\uf0a0",
            camera_snap: "\uf030", camera_record: "\uf03d", screen_record: "\uf108",
            skill_creator: "\uf0d0", clipboard: "\uf328", shortcuts: "\uf0d0",
            calendar_event: "\uf073", slides: "\uf1c4" };
        return icons[name] || "\uf0e7";
    }

    Flickable {
        anchors.fill: parent; anchors.margins: Math.round(24 * root.sf)
        contentHeight: toolsCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: toolsCol; width: parent.width; spacing: Math.round(18 * root.sf)

            // Header
            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                    Text { text: "Tools"; font.pixelSize: Math.round(22 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
                    Text { text: allTools.length + " tools available for AI operations"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                }
                // Search
                Rectangle {
                    width: Math.round(180 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                    color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)
                        Text { text: "\uf002"; font.family: root.iconFont; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                        TextInput {
                            Layout.fillWidth: true; color: "#ffffff"; font.pixelSize: Math.round(12 * root.sf); clip: true
                            onTextChanged: { searchText = text; filterTools(); }
                            Text { anchors.fill: parent; text: "Search tools..."; color: Qt.rgba(1,1,1,0.25); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text }
                        }
                    }
                }
            }

            // Category pills
            Flow {
                width: parent.width; spacing: Math.round(10 * root.sf)
                Repeater {
                    model: categories
                    Rectangle {
                        width: catLabel.width + (catCount.visible ? catCount.width + 22 : 20); height: Math.round(34 * root.sf); radius: 17
                        color: activeCategory === modelData ? root.accentBlue : "transparent"
                        border.color: activeCategory === modelData ? root.accentBlue : root.borderColor; border.width: 1

                        Row {
                            anchors.centerIn: parent; spacing: Math.round(5 * root.sf)
                            Text { id: catLabel; text: modelData === "all" ? "All" : modelData.charAt(0).toUpperCase() + modelData.slice(1); font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: activeCategory === modelData ? "#fff" : root.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                id: catCount; visible: true; width: ccText.width + 8; height: Math.round(16 * root.sf); radius: 8
                                color: activeCategory === modelData ? Qt.rgba(1,1,1,0.2) : root.bgElevated
                                anchors.verticalCenter: parent.verticalCenter
                                Text { id: ccText; anchors.centerIn: parent; font.pixelSize: Math.round(9 * root.sf);
                                    color: activeCategory === modelData ? "#fff" : root.textMuted
                                    text: {
                                        if (modelData === "all") return allTools.length;
                                        var c = 0; for (var i = 0; i < allTools.length; i++) { if (allTools[i].category === modelData) c++; }
                                        return c;
                                    }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { activeCategory = modelData; filterTools(); } }
                    }
                }
            }

            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            // Tools grid (2-column)
            Grid {
                id: toolsGrid; width: parent.width; columns: 2; spacing: Math.round(8 * root.sf)
                Repeater {
                    model: filteredTools
                    Rectangle {
                        width: (toolsGrid.width - 8) / 2; height: toolItemCol.height + 16
                        radius: root.radiusMd; color: root.bgCard
                        border.color: root.borderColor; border.width: 1

                        Column {
                            id: toolItemCol; anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Math.round(10 * root.sf); spacing: Math.round(6 * root.sf)

                            RowLayout {
                                width: parent.width; spacing: Math.round(8 * root.sf)
                                Rectangle {
                                    width: Math.round(32 * root.sf); height: Math.round(32 * root.sf); radius: 8
                                    color: Qt.rgba(getCategoryColor(modelData.category).r || 0.3, getCategoryColor(modelData.category).g || 0.5, getCategoryColor(modelData.category).b || 0.9, 0.15)
                                    Text { anchors.centerIn: parent; text: getToolIcon(modelData.name); font.family: root.iconFont; font.pixelSize: Math.round(14 * root.sf); color: getCategoryColor(modelData.category) }
                                }
                                Column {
                                    Layout.fillWidth: true; spacing: Math.round(1 * root.sf)
                                    Text { text: modelData.name; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#ffffff" }
                                    Text { text: (modelData.category || "").toUpperCase(); font.pixelSize: Math.round(9 * root.sf); color: root.textMuted; font.letterSpacing: 0.5 }
                                }
                                // On/Off badge
                                Rectangle {
                                    width: onOffText.width + 12; height: Math.round(18 * root.sf); radius: 9
                                    color: modelData.disabled ? Qt.rgba(0.94,0.27,0.27,0.15) : Qt.rgba(0.13,0.77,0.37,0.15)
                                    Text { id: onOffText; anchors.centerIn: parent; text: modelData.disabled ? "Off" : "On"; font.pixelSize: Math.round(9 * root.sf); font.weight: Font.DemiBold; color: modelData.disabled ? "#ef4444" : root.accentGreen }
                                }
                            }

                            Text { text: modelData.description || ""; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary; wrapMode: Text.WordWrap; width: parent.width; lineHeight: 1.3 }

                            RowLayout {
                                width: parent.width; spacing: Math.round(4 * root.sf)
                                Text { text: modelData.requiresApproval ? "\uf023 Approval required" : "\u26A1 Auto-execute"; font.pixelSize: Math.round(9 * root.sf); color: root.textMuted; Layout.fillWidth: true }
                                // Toggle
                                Rectangle {
                                    width: Math.round(34 * root.sf); height: Math.round(18 * root.sf); radius: 9
                                    color: !modelData.disabled ? root.accentBlue : Qt.rgba(1,1,1,0.1)
                                    Rectangle {
                                        width: Math.round(14 * root.sf); height: Math.round(14 * root.sf); radius: 7; y: 2
                                        x: !modelData.disabled ? 18 : 2; color: "white"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggleTool(modelData.name, modelData.disabled) }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            Column {
                width: parent.width; spacing: Math.round(8 * root.sf); visible: filteredTools.length === 0 && !loading
                Item { width: Math.round(1 * root.sf); height: Math.round(30 * root.sf) }
                Text { text: "\uf002"; font.family: root.iconFont; font.pixelSize: Math.round(32 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "No tools found"; font.pixelSize: Math.round(14 * root.sf); color: root.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Try a different search term or category"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
}
