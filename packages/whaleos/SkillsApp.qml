import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    anchors.fill: parent; color: "transparent"

    property string activeTab: "api"
    property var apiSkills: []
    property var mdSkills: []
    property bool loading: true
    property string editingSkillPath: ""
    property string editingSkillContent: ""
    property bool editorOpen: false
    property bool nameDialogOpen: false
    property string newSkillNameInput: ""

    Component.onCompleted: loadAllSkills()

    function loadAllSkills() {
        loading = true;

        // Local icon map — API never returns icons, so inject from here
        var iconMap = {
            "github":     { icon: "\uf09b", brands: true  },
            "weather":    { icon: "\uf0c2", brands: false },
            "notion":     { icon: "\uf15c", brands: false },
            "google":     { icon: "\uf1a0", brands: true  },
            "1password":  { icon: "\uf023", brands: false },
            "elevenlabs": { icon: "\uf028", brands: false },
            "spotify":    { icon: "\uf1bc", brands: true  },
            "twilio":     { icon: "\uf095", brands: false },
            "twitter":    { icon: "\uf099", brands: true  },
            "trello":     { icon: "\uf181", brands: true  }
        };

        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/skills");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText);
                        var raw = d.skills || [];
                        var mapped = [];
                        for (var i = 0; i < raw.length; i++) {
                            var s = raw[i];
                            var im = iconMap[s.id] || { icon: "\uf0e7", brands: false };
                            mapped.push({
                                id:          s.id,
                                name:        s.name,
                                description: s.description,
                                configured:  !!(s.hasKey && s.enabled),
                                icon:        im.icon,
                                brands:      im.brands
                            });
                        }
                        apiSkills = mapped;
                    } catch(e) {}
                }
                if (apiSkills.length === 0) {
                    apiSkills = [
                        { id: "github",     name: "GitHub",          description: "Access repos, issues, PRs",         configured: false, icon: "\uf09b", brands: true  },
                        { id: "weather",    name: "OpenWeatherMap",   description: "Current weather and forecasts",     configured: false, icon: "\uf0c2", brands: false },
                        { id: "notion",     name: "Notion",           description: "Workspace pages and databases",      configured: false, icon: "\uf15c", brands: false },
                        { id: "google",     name: "Google Services",  description: "Calendar, Gmail, Drive, Tasks",      configured: false, icon: "\uf1a0", brands: true  },
                        { id: "1password",  name: "1Password",        description: "Secrets and credential management",  configured: false, icon: "\uf023", brands: false },
                        { id: "elevenlabs", name: "ElevenLabs",       description: "Text-to-speech voice synthesis",     configured: false, icon: "\uf028", brands: false },
                        { id: "spotify",    name: "Spotify",          description: "Music playback and playlists",       configured: false, icon: "\uf1bc", brands: true  },
                        { id: "twilio",     name: "Twilio",           description: "SMS messages and voice calls",       configured: false, icon: "\uf095", brands: false }
                    ];
                }
                loading = false;
            }
        };
        xhr.send();

        var xhr2 = new XMLHttpRequest();
        xhr2.open("GET", root.apiBase + "/md-skills");
        xhr2.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr2.onreadystatechange = function() {
            if (xhr2.readyState === 4 && xhr2.status === 200) {
                try { var d = JSON.parse(xhr2.responseText); mdSkills = d.mdSkills || []; } catch(e) {}
            }
        };
        xhr2.send();
    }

    // Validate tables: maps skillId -> validation URL and expected status
    // Returns empty string if no external validation available for this skill
    function getValidateUrl(skillId, key) {
        if (skillId === "github")      return "https://api.github.com/user";
        if (skillId === "weather")     return "https://api.openweathermap.org/data/2.5/weather?q=London&appid=" + key;
        if (skillId === "notion")      return "https://api.notion.com/v1/users/me";
        if (skillId === "elevenlabs")  return "https://api.elevenlabs.io/v1/user";
        return ""; // No external check for others, skip validation
    }

    function saveSkill(skillId, keyInput) {
        var key = keyInput.text.trim();
        if (!key) { root.showToast("Enter an API key", "error"); return; }

        var validateUrl = getValidateUrl(skillId, key);

        if (validateUrl) {
            // Validate token before saving
            root.showToast("Verifying token...", "info");
            var vxhr = new XMLHttpRequest();
            vxhr.open("GET", validateUrl);
            vxhr.setRequestHeader("Authorization", "Bearer " + key);
            if (skillId === "github") {
                vxhr.setRequestHeader("Authorization", "token " + key);
                vxhr.setRequestHeader("Accept", "application/vnd.github.v3+json");
            }
            vxhr.onreadystatechange = function() {
                if (vxhr.readyState === 4) {
                    if (vxhr.status === 200 || vxhr.status === 201) {
                        doSaveSkill(skillId, key, keyInput);
                    } else if (vxhr.status === 401 || vxhr.status === 403) {
                        root.showToast("Invalid API token for " + skillId, "error");
                    } else {
                        // Network error or rate limit — save anyway with warning
                        root.showToast("Could not verify token, saving anyway...", "warning");
                        doSaveSkill(skillId, key, keyInput);
                    }
                }
            };
            vxhr.send();
        } else {
            // No validation available, save directly
            doSaveSkill(skillId, key, keyInput);
        }
    }

    function doSaveSkill(skillId, key, keyInput) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/skills/" + skillId + "/config");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast(skillId.charAt(0).toUpperCase() + skillId.slice(1) + " connected!", "success");
                    keyInput.text = ""; loadAllSkills();
                } else {
                    root.showToast("Failed to save " + skillId + " (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        xhr.send(JSON.stringify({ apiKey: key, enabled: true }));
    }

    function disconnectSkill(skillId) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/skills/" + skillId + "/config");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast(skillId + " disconnected", "success");
                    loadAllSkills();
                } else {
                    root.showToast("Failed to disconnect (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        // Send null apiKey to clear it — backend treats null/empty as "remove key"
        xhr.send(JSON.stringify({ apiKey: null, enabled: false }));
    }

    function createNewSkill() {
        // Show name dialog instead of auto-generating name
        newSkillNameInput = "";
        nameDialogOpen = true;
    }

    function doCreateSkill(skillName) {
        if (!skillName || !skillName.trim()) { root.showToast("Enter a skill name", "error"); return; }
        nameDialogOpen = false;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/md-skills/create");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast("Skill '" + skillName + "' created", "success");
                    try {
                        var d = JSON.parse(xhr.responseText);
                        // API returns the skill directory — open SKILL.md inside it
                        if (d.path) { openSkillEditor(d.path + "/SKILL.md"); }
                    } catch(e) {}
                } else {
                    var msg = "Failed to create skill (HTTP " + xhr.status + ")";
                    try { var e = JSON.parse(xhr.responseText); if (e.error) msg = e.error; } catch(_) {}
                    root.showToast(msg, "error");
                }
                loadAllSkills();
            }
        };
        xhr.send(JSON.stringify({ name: skillName.trim(), description: "A custom skill" }));
    }

    function openSkillEditor(path) {
        editingSkillPath = path;
        editorOpen = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/md-skills/content?path=" + encodeURIComponent(path));
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try { var d = JSON.parse(xhr.responseText); editingSkillContent = d.content || ""; } catch(e) {}
            }
        };
        xhr.send();
    }

    function saveSkillFile() {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/md-skills/save");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { root.showToast("Skill saved successfully", "success"); }
                else { root.showToast("Failed to save skill (HTTP " + xhr.status + ")", "error"); }
                editorOpen = false; loadAllSkills();
            }
        };
        xhr.send(JSON.stringify({ path: editingSkillPath, content: skillEditor.text }));
    }

    Flickable {
        anchors.fill: parent; anchors.margins: Math.round(24 * root.sf)
        contentHeight: skillsCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: !editorOpen

        Column {
            id: skillsCol; width: parent.width; spacing: Math.round(18 * root.sf)

            Text { text: "Skills"; font.pixelSize: Math.round(22 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
            Text { text: "API integrations and markdown-based skills"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }

            // Tab bar
            Rectangle {
                width: tabRow.width + Math.round(6 * root.sf); height: Math.round(40 * root.sf)
                radius: Math.round(10 * root.sf); color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1

                Row {
                    id: tabRow; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                    Repeater {
                        model: [{ key: "api", label: "API Skills" }, { key: "markdown", label: "Markdown Skills" }]
                        Rectangle {
                            width: Math.round(130 * root.sf); height: Math.round(32 * root.sf); radius: Math.round(8 * root.sf)
                            color: activeTab === modelData.key ? root.accentBlue : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: activeTab === modelData.key ? "#fff" : root.textSecondary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = modelData.key }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            // API Skills tab
            Column {
                width: parent.width; spacing: Math.round(14 * root.sf); visible: activeTab === "api"
                Repeater {
                    model: apiSkills
                    Rectangle {
                        width: skillsCol.width; height: sCol.height + 28
                        radius: root.radiusMd; color: root.bgCard
                        border.color: modelData.configured ? Qt.rgba(0.13,0.77,0.37,0.3) : root.borderColor; border.width: 1

                        Column {
                            id: sCol; anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Math.round(16 * root.sf); spacing: Math.round(10 * root.sf)

                            RowLayout {
                                width: parent.width; spacing: Math.round(10 * root.sf)
                                Rectangle {
                                    width: Math.round(32 * root.sf); height: Math.round(32 * root.sf); radius: 8; color: Qt.rgba(1,1,1,0.06)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon || "\uf0e7"
                                        font.family: modelData.brands ? root.iconFontBrands : root.iconFont
                                        font.weight: modelData.brands ? Font.Normal : Font.Black
                                        font.pixelSize: Math.round(16 * root.sf); color: root.accentBlue
                                    }
                                }
                                Column {
                                    Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                                    Text { text: modelData.name; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: root.textPrimary }
                                    Text { text: modelData.description || ""; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                }
                                Rectangle {
                                    width: statusLabel.width + 14; height: Math.round(22 * root.sf); radius: 4
                                    color: modelData.configured ? Qt.rgba(0.13,0.77,0.37,0.15) : Qt.rgba(1,1,1,0.05)
                                    Text { id: statusLabel; anchors.centerIn: parent; text: modelData.configured ? "Connected" : "Not configured"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: modelData.configured ? root.accentGreen : root.textMuted }
                                }
                            }
                            RowLayout {
                                width: parent.width; spacing: Math.round(6 * root.sf)
                                Rectangle {
                                    Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: root.radiusSm
                                    color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                    TextInput {
                                        id: skillKeyInput; anchors.fill: parent; anchors.margins: Math.round(8 * root.sf)
                                        color: root.textPrimary; font.pixelSize: Math.round(12 * root.sf); clip: true
                                        echoMode: TextInput.Password; verticalAlignment: TextInput.AlignVCenter
                                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                            text: modelData.configured ? "••••••••  (enter new key to update)" : "Enter API key..."
                                            color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text }
                                    }
                                }
                                // Connect button — only shown when not configured or has new input
                                Rectangle {
                                    width: Math.round(70 * root.sf); height: Math.round(30 * root.sf)
                                    radius: root.radiusSm; color: root.accentBlue
                                    visible: !modelData.configured || skillKeyInput.text.length > 0
                                    Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveSkill(modelData.id, skillKeyInput) }
                                }
                                // Disconnect button — only shown when configured and no new input
                                Rectangle {
                                    width: Math.round(86 * root.sf); height: Math.round(30 * root.sf)
                                    radius: root.radiusSm; color: Qt.rgba(0.97,0.27,0.27,0.15)
                                    border.color: Qt.rgba(0.97,0.27,0.27,0.3); border.width: 1
                                    visible: modelData.configured && skillKeyInput.text.length === 0
                                    Text { anchors.centerIn: parent; text: "Disconnect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#f87171" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: disconnectSkill(modelData.id) }
                                }
                            }
                        }
                    }
                }
            }

            // Markdown Skills tab
            Column {
                width: parent.width; spacing: Math.round(10 * root.sf); visible: activeTab === "markdown"

                RowLayout {
                    width: parent.width
                    Text { text: mdSkills.length + " skills loaded"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted; Layout.fillWidth: true }
                    Rectangle {
                        width: Math.round(100 * root.sf); height: Math.round(28 * root.sf); radius: root.radiusSm; color: root.accentBlue
                        Row { anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                            Text { text: "+"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: "white" }
                            Text { text: "New Skill"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "white" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: createNewSkill() }
                    }
                }

                Repeater {
                    model: mdSkills
                    Rectangle {
                        width: skillsCol.width; height: Math.round(54 * root.sf)
                        radius: root.radiusMd; color: root.bgCard
                        border.color: root.borderColor; border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            Rectangle {
                                width: Math.round(30 * root.sf); height: Math.round(30 * root.sf); radius: 6; color: Qt.rgba(0.96,0.58,0.09,0.15)
                                Text { anchors.centerIn: parent; text: "\uf15c"; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(14 * root.sf); color: root.accentOrange }
                            }
                            Column {
                                Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                                Text { text: modelData.name || modelData.dir || "Skill"; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: root.textPrimary }
                                Text { text: modelData.description || modelData.path || ""; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; elide: Text.ElideRight; width: parent.width }
                            }
                            Rectangle {
                                width: Math.round(50 * root.sf); height: Math.round(26 * root.sf); radius: root.radiusSm
                                color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                                Text { anchors.centerIn: parent; text: "Edit"; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openSkillEditor(modelData.path || "") }
                            }
                        }
                    }
                }

                // Empty state
                Column {
                    width: parent.width; spacing: Math.round(8 * root.sf); visible: mdSkills.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    Item { width: Math.round(1 * root.sf); height: Math.round(20 * root.sf) }
                    Text { text: "\uf15c"; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(32 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "No markdown skills found"; font.pixelSize: Math.round(14 * root.sf); color: root.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "Add .md files to ~/.openwhale/skills/"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
        }
    }

    // ── New Skill Name Dialog ──
    Rectangle {
        anchors.fill: parent; color: Qt.rgba(0,0,0,0.7); visible: nameDialogOpen; z: 100

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(320 * root.sf); height: nameDialogCol.height + Math.round(32 * root.sf)
            radius: root.radiusMd; color: root.bgElevated
            border.color: root.borderLight; border.width: 1

            Column {
                id: nameDialogCol
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: Math.round(20 * root.sf)
                spacing: Math.round(14 * root.sf)

                Text { text: "New Skill"; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
                Text { text: "Enter a name for your new skill"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }

                Rectangle {
                    width: parent.width; height: Math.round(36 * root.sf); radius: root.radiusSm
                    color: Qt.rgba(0,0,0,0.4); border.color: skillNameField.activeFocus ? root.accentBlue : Qt.rgba(1,1,1,0.12); border.width: 1
                    TextInput {
                        id: skillNameField; anchors.fill: parent; anchors.margins: Math.round(10 * root.sf)
                        color: root.textPrimary; font.pixelSize: Math.round(13 * root.sf)
                        verticalAlignment: TextInput.AlignVCenter; clip: true
                        text: newSkillNameInput
                        onTextChanged: newSkillNameInput = text
                        Keys.onReturnPressed: doCreateSkill(text)
                        Keys.onEscapePressed: nameDialogOpen = false
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                               text: "e.g. My Custom Skill"; color: Qt.rgba(1,1,1,0.2)
                               font.pixelSize: Math.round(13 * root.sf); visible: !parent.text }
                    }
                }

                RowLayout {
                    width: parent.width; spacing: Math.round(8 * root.sf)
                    Rectangle {
                        Layout.fillWidth: true; height: Math.round(34 * root.sf); radius: root.radiusSm
                        color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nameDialogOpen = false }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: Math.round(34 * root.sf); radius: root.radiusSm; color: root.accentBlue
                        Text { anchors.centerIn: parent; text: "Create Skill"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: doCreateSkill(newSkillNameInput) }
                    }
                }
            }
        }

        // Focus the text field when dialog opens
        onVisibleChanged: if (visible) skillNameField.forceActiveFocus()
    }

    // ── Markdown Editor ──
    Rectangle {
        anchors.fill: parent; color: root.bgSurface; visible: editorOpen

        Column {
            anchors.fill: parent; anchors.margins: Math.round(16 * root.sf); spacing: Math.round(10 * root.sf)

            RowLayout {
                width: parent.width
                Text { text: "\uf060"; font.family: root.iconFont; font.weight: Font.Black; font.pixelSize: Math.round(14 * root.sf); color: root.textSecondary
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editorOpen = false }
                }
                Text { text: "  Skill Editor"; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.Bold; color: root.textPrimary; Layout.fillWidth: true }
                Rectangle {
                    width: Math.round(60 * root.sf); height: Math.round(28 * root.sf); radius: root.radiusSm; color: root.accentBlue
                    Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveSkillFile() }
                }
            }

            Text { text: editingSkillPath; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; font.family: "monospace" }
            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            // Toolbar
            RowLayout {
                width: parent.width; spacing: Math.round(4 * root.sf)
                Repeater {
                    model: [
                        { label: "H1", insert: "# " },
                        { label: "H2", insert: "## " },
                        { label: "B", insert: "**bold**" },
                        { label: "I", insert: "_italic_" },
                        { label: "```", insert: "```\n\n```" },
                        { label: "•", insert: "- " },
                        { label: "🔗", insert: "[text](url)" }
                    ]
                    Rectangle {
                        width: Math.round(32 * root.sf); height: Math.round(24 * root.sf); radius: 4
                        color: tbMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                        Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.Bold; color: root.textSecondary; font.family: "monospace" }
                        MouseArea { id: tbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { skillEditor.insert(skillEditor.cursorPosition, modelData.insert); } }
                    }
                }
                Item { Layout.fillWidth: true }
                Text { text: skillEditor.lineCount + " lines"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; font.family: "monospace" }
            }

            Rectangle {
                width: parent.width; height: parent.height - 100
                radius: root.radiusMd; color: Qt.rgba(0,0,0,0.5)
                border.color: root.borderColor; border.width: 1

                RowLayout {
                    anchors.fill: parent; spacing: Math.round(0 * root.sf)

                    // Line numbers
                    Rectangle {
                        Layout.fillHeight: true; width: Math.round(40 * root.sf); color: Qt.rgba(0,0,0,0.3)
                        radius: root.radiusMd
                        Rectangle { anchors.right: parent.right; width: Math.round(1 * root.sf); height: parent.height; color: Qt.rgba(1,1,1,0.06) }

                        Flickable {
                            id: lineNumFlick; anchors.fill: parent; anchors.margins: Math.round(4 * root.sf)
                            contentY: editorFlick.contentY; clip: true; interactive: false
                            contentHeight: lineNumCol.height

                            Column {
                                id: lineNumCol; width: parent.width
                                Repeater {
                                    model: Math.max(1, skillEditor.lineCount)
                                    Text {
                                        width: parent.width; height: skillEditor.font.pixelSize + 6
                                        text: (index + 1); font.pixelSize: Math.round(11 * root.sf); font.family: "monospace"
                                        color: Qt.rgba(1,1,1,0.25); horizontalAlignment: Text.AlignRight
                                        rightPadding: 6
                                    }
                                }
                            }
                        }
                    }

                    // Editor
                    Flickable {
                        id: editorFlick; Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: skillEditor.contentHeight + 20; clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: skillEditor; width: parent.width - 16
                            x: Math.round(8 * root.sf); y: 4
                            text: editingSkillContent; color: root.textPrimary
                            font.pixelSize: Math.round(13 * root.sf); font.family: "monospace"
                            wrapMode: TextEdit.NoWrap; selectByMouse: true
                            selectionColor: Qt.rgba(0.23,0.51,0.97,0.4)
                            tabStopDistance: 28
                        }
                    }
                }
            }
        }
    }
}
