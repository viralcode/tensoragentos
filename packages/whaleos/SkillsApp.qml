import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: skillsApp
    anchors.fill: parent
    color: "transparent"

    property var skills: []
    property var mdSkills: []
    property string activeView: "list"
    property string editingPath: ""
    property string editingContent: ""

    Component.onCompleted: loadSkills()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar: Skill Tree ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 220
            color: Qt.rgba(0, 0, 0, 0.2)

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 1
                color: root.borderColor
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Skills"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    // New skill button
                    Rectangle {
                        width: 26; height: 26; radius: 6
                        color: newSkillMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"

                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: root.textSecondary }
                        MouseArea {
                            id: newSkillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { /* TODO: create skill */ }
                        }
                    }
                }

                // Search
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: root.radiusSm
                    color: root.bgSurface
                    border.color: root.borderColor
                    border.width: 1

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.textPrimary
                        font.pixelSize: 12
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🔍 Search skills..."
                            color: root.textMuted
                            font.pixelSize: 12
                            visible: !parent.text && !parent.activeFocus
                        }
                    }
                }

                // API Skills section
                Text {
                    text: "API SKILLS"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: root.textMuted
                    Layout.topMargin: 4
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 150)
                    model: skills
                    spacing: 2
                    clip: true

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 30
                        radius: root.radiusSm
                        color: "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Text { text: "⚡"; font.pixelSize: 10 }
                            Text { text: modelData.name || modelData; font.pixelSize: 12; color: root.textSecondary }
                        }
                    }
                }

                // MD Skills section
                Text {
                    text: "MARKDOWN SKILLS"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: root.textMuted
                    Layout.topMargin: 4
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: mdSkills
                    spacing: 2
                    clip: true

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 30
                        radius: root.radiusSm
                        color: skillItemMouse.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Text { text: "📄"; font.pixelSize: 10 }
                            Text {
                                text: modelData.name || modelData
                                font.pixelSize: 12
                                color: root.textSecondary
                                elide: Text.ElideRight
                                width: 160
                            }
                        }

                        MouseArea {
                            id: skillItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                editingPath = modelData.path || "";
                                activeView = "editor";
                                loadSkillContent(editingPath);
                            }
                        }
                    }
                }
            }
        }

        // ── Content Area ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // List view
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                visible: activeView === "list"
                spacing: 16

                Text {
                    text: "Skills & Integrations"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: root.textPrimary
                }

                Text {
                    text: "Select a skill from the sidebar to view or edit"
                    font.pixelSize: 13
                    color: root.textSecondary
                }

                Item { Layout.fillHeight: true }
            }

            // Editor view
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                visible: activeView === "editor"
                spacing: 8

                // Editor toolbar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "📝 " + editingPath.split("/").pop()
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: root.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 70; height: 30; radius: root.radiusSm
                        color: root.accentBlue
                        Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: 12; color: "#ffffff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveSkill() }
                    }

                    Rectangle {
                        width: 70; height: 30; radius: root.radiusSm
                        color: Qt.rgba(1,1,1,0.06)
                        border.color: root.borderColor; border.width: 1
                        Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 12; color: root.accentRed }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                    }
                }

                // Editor area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.radiusSm
                    color: "#1a1a2e"
                    border.color: root.borderColor
                    border.width: 1

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        contentHeight: editorField.contentHeight
                        clip: true

                        TextEdit {
                            id: editorField
                            width: parent.width
                            text: editingContent
                            color: "#98d1ce"
                            font.pixelSize: 13
                            font.family: "monospace"
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                        }
                    }
                }
            }
        }
    }

    function loadSkills() {
        API.getSkills(function(status, data) {
            if (status === 200 && Array.isArray(data)) {
                skills = data;
            }
        });
        API.getMdSkills(function(status, data) {
            if (status === 200 && Array.isArray(data)) {
                mdSkills = data;
            }
        });
    }

    function loadSkillContent(path) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://localhost:7777/api/md-skills/content?path=" + encodeURIComponent(path));
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    editingContent = data.content || "";
                } catch(e) { editingContent = "Failed to load"; }
            }
        };
        xhr.send();
    }

    function saveSkill() {
        var body = JSON.stringify({ path: editingPath, content: editorField.text });
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:7777/api/md-skills/save");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(body);
    }
}
