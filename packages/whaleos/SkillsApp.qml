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

    Component.onCompleted: loadAllSkills()

    function loadAllSkills() {
        loading = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/skills");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try { var d = JSON.parse(xhr.responseText); apiSkills = d.skills || []; } catch(e) {}
                }
                if (apiSkills.length === 0) {
                    apiSkills = [
                        { id: "github", name: "GitHub", description: "Repository management, issues, PRs", configured: false, icon: "\uf09b" },
                        { id: "weather", name: "OpenWeatherMap", description: "Current weather and forecasts", configured: false, icon: "\uf0c2" },
                        { id: "notion", name: "Notion", description: "Workspace pages and databases", configured: false, icon: "\uf15c" },
                        { id: "google", name: "Google Services", description: "Calendar, Gmail, Drive, Tasks", configured: false, icon: "\uf1a0" },
                        { id: "1password", name: "1Password", description: "Secrets and credential management", configured: false, icon: "\uf023" },
                        { id: "elevenlabs", name: "ElevenLabs", description: "Text-to-speech voice synthesis", configured: false, icon: "\uf028" },
                        { id: "spotify", name: "Spotify", description: "Music playback and playlists", configured: false, icon: "\uf1bc" },
                        { id: "twilio", name: "Twilio", description: "SMS messages and voice calls", configured: false, icon: "\uf095" }
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

    function saveSkill(skillId, keyInput) {
        var key = keyInput.text;
        if (!key) { root.showToast("Enter an API key", "error"); return; }
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/skills/" + skillId);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast(skillId.charAt(0).toUpperCase() + skillId.slice(1) + " connected successfully!", "success");
                    keyInput.text = ""; loadAllSkills();
                } else {
                    root.showToast("Failed to connect " + skillId + " (HTTP " + xhr.status + ")", "error");
                }
            }
        };
        xhr.send(JSON.stringify({ apiKey: key, enabled: true }));
    }

    function createNewSkill() {
        var name = "new-skill-" + Date.now();
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/md-skills/create");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    root.showToast("New skill created", "success");
                    try { var d = JSON.parse(xhr.responseText); if (d.path) { openSkillEditor(d.path); } } catch(e) {}
                } else {
                    root.showToast("Failed to create skill (HTTP " + xhr.status + ")", "error");
                }
                loadAllSkills();
            }
        };
        xhr.send(JSON.stringify({ name: name }));
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
        anchors.fill: parent; anchors.margins: Math.round(16 * root.sf)
        contentHeight: skillsCol.height; clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: !editorOpen

        Column {
            id: skillsCol; width: parent.width; spacing: Math.round(12 * root.sf)

            Text { text: "Skills"; font.pixelSize: Math.round(20 * root.sf); font.weight: Font.Bold; color: root.textPrimary }
            Text { text: "API integrations and markdown-based skills"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }

            // Tab bar
            Row {
                spacing: Math.round(0 * root.sf)
                Repeater {
                    model: [{ key: "api", label: "API Skills" }, { key: "markdown", label: "Markdown Skills" }]
                    Rectangle {
                        width: Math.round(120 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                        color: activeTab === modelData.key ? root.accentBlue : "transparent"
                        Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: activeTab === modelData.key ? "#fff" : root.textSecondary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = modelData.key }
                    }
                }
            }

            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }

            // API Skills tab
            Column {
                width: parent.width; spacing: Math.round(10 * root.sf); visible: activeTab === "api"
                Repeater {
                    model: apiSkills
                    Rectangle {
                        width: skillsCol.width; height: sCol.height + 20
                        radius: root.radiusMd; color: root.bgCard
                        border.color: modelData.configured ? Qt.rgba(0.13,0.77,0.37,0.3) : root.borderColor; border.width: 1

                        Column {
                            id: sCol; anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)

                            RowLayout {
                                width: parent.width; spacing: Math.round(10 * root.sf)
                                Rectangle {
                                    width: Math.round(32 * root.sf); height: Math.round(32 * root.sf); radius: 8; color: Qt.rgba(1,1,1,0.06)
                                    Text { anchors.centerIn: parent; text: modelData.icon || "\uf0e7"; font.family: modelData.id === "github" || modelData.id === "spotify" ? root.iconFontBrands : root.iconFont; font.pixelSize: Math.round(16 * root.sf); color: root.accentBlue }
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
                                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "Enter API key..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); visible: !parent.text }
                                    }
                                }
                                Rectangle {
                                    width: Math.round(70 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                    Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveSkill(modelData.id, skillKeyInput) }
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
                                Text { anchors.centerIn: parent; text: "\uf15c"; font.family: root.iconFont; font.pixelSize: Math.round(14 * root.sf); color: root.accentOrange }
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
                    Text { text: "\uf15c"; font.family: root.iconFont; font.pixelSize: Math.round(32 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "No markdown skills found"; font.pixelSize: Math.round(14 * root.sf); color: root.textSecondary; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "Add .md files to ~/.openwhale/skills/"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
        }
    }

    // ── Markdown Editor ──
    Rectangle {
        anchors.fill: parent; color: root.bgSurface; visible: editorOpen

        Column {
            anchors.fill: parent; anchors.margins: Math.round(16 * root.sf); spacing: Math.round(10 * root.sf)

            RowLayout {
                width: parent.width
                Text { text: "\uf060"; font.family: root.iconFont; font.pixelSize: Math.round(14 * root.sf); color: root.textSecondary
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
