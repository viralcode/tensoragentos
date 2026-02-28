import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsApp; anchors.fill: parent; color: "transparent"
    property string activeTab: "profile"
    property var userList: []
    property bool showAddUser: false
    property string newUsername: ""
    property string newPassword: ""
    property bool waConnecting: false
    property string waQrCode: ""
    property bool waConnected: false
    property string tgToken: ""
    property string dcToken: ""
    Component.onCompleted: loadUsers()
    function loadUsers() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/api/users");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { try { var d = JSON.parse(xhr.responseText); userList = d.users || []; } catch(e) {}
            }
                if (userList.length === 0) userList = [{ username: root.currentUser, role: "admin" }];
            }
        };
        xhr.send();
    }
    function addUser() {
        if (!newUsername || !newPassword) return;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/api/users");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() { if (xhr.readyState === 4) { showAddUser = false; newUsername = ""; newPassword = ""; loadUsers(); }
    };
        xhr.send(JSON.stringify({ username: newUsername, password: newPassword }));
    }
    function deleteUser(u) {
        var xhr = new XMLHttpRequest();
        xhr.open("DELETE", root.apiBase + "/api/users/" + u);
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() { if (xhr.readyState === 4) loadUsers(); };
        xhr.send();
    }
    function connectWhatsApp() {
        waConnecting = true; waQrCode = "";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/api/channels/whatsapp/connect");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() { if (xhr.readyState === 4) pollWAQR(); };
        xhr.send();
    }
    function pollWAQR() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/api/channels/whatsapp/status");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try { var d = JSON.parse(xhr.responseText); waConnected = d.connected || false; if (d.qrCode) waQrCode = d.qrCode; if (!waConnected && waConnecting) qrTimer.start(); else waConnecting = false; } catch(e) { waConnecting = false; }
            } else { waConnecting = false; }
        };
        xhr.send();
    }
    Timer { id: qrTimer; interval: 3000; repeat: false; onTriggered: pollWAQR() }
    function connectCh(t, tok) {
        if (!tok) return;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/api/channels/" + t);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() { if (xhr.readyState === 4) console.log(t + " saved"); };
        xhr.send(JSON.stringify({ token: tok, enabled: true }));
    }
    RowLayout {
        anchors.fill: parent; spacing: 0
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 170; color: Qt.rgba(0,0,0,0.2)
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: root.borderColor }
            Column {
                anchors.fill: parent; anchors.margins: 8; anchors.topMargin: 10; spacing: 2
                Repeater {
                    model: [{ id: "profile", icon: "\uf007", label: "Profile" }, { id: "users", icon: "\uf0c0", label: "Users" }, { id: "channels", icon: "\uf1e6", label: "Channels" }]
                    delegate: Rectangle {
                        width: parent ? parent.width : 150; height: 34; radius: root.radiusSm
                        color: activeTab === modelData.id ? Qt.rgba(1,1,1,0.08) : sMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"
                        Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; spacing: 8
                            Text { text: modelData.icon; font.family: root.iconFont; font.pixelSize: 13; color: root.accentBlue }
                            Text { text: modelData.label; font.pixelSize: 13; color: activeTab === modelData.id ? "#fff" : root.textSecondary }
                        }
                        Rectangle { visible: activeTab === modelData.id; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 18; radius: 2; color: root.accentBlue }
                        MouseArea { id: sMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = modelData.id }
                    }
                }
            }
        }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; contentHeight: cCol.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: cCol; width: parent.width - 32; x: 16; y: 16; spacing: 14
                // PROFILE
                Column { width: parent.width; spacing: 12; visible: activeTab === "profile"
                    Text { text: "Profile"; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Manage your account settings"; font.pixelSize: 12; color: root.textMuted }
                    Rectangle { width: parent.width; height: pI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: pI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 10
                            RowLayout { spacing: 10
                                Rectangle { width: 48; height: 48; radius: 24; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: root.currentUser.charAt(0).toUpperCase(); font.pixelSize: 20; font.weight: Font.Bold; color: "#fff" }
                            }
                                Column { spacing: 2; Layout.fillWidth: true
                                Text { text: root.currentUser; font.pixelSize: 16; font.weight: Font.DemiBold; color: "#fff" }
                                Text { text: "Administrator"; font.pixelSize: 11; color: root.textMuted }
                            }
                            }
                            Rectangle { width: parent.width; height: 1; color: root.borderColor }
                            Text { text: "Change Password"; font.pixelSize: 12; color: root.textMuted }
                            RowLayout { width: parent.width; spacing: 6
                                Rectangle { Layout.fillWidth: true; height: 32; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: 8; color: "#fff"; font.pixelSize: 12; echoMode: TextInput.Password; clip: true
                                Text { visible: !parent.text; text: "New password..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            } }
                                Rectangle { width: 65; height: 32; radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Update"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                            }
                            }
                        }
                    }
                }
                // USERS
                Column { width: parent.width; spacing: 12; visible: activeTab === "users"
                    RowLayout { width: parent.width
                        Column { Layout.fillWidth: true; spacing: 2
                        Text { text: "User Management"; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#fff" }
                        Text { text: "Manage who can access this system"; font.pixelSize: 12; color: root.textMuted }
                    }
                        Rectangle { width: 90; height: 30; radius: root.radiusSm; color: root.accentBlue
                        Text { anchors.centerIn: parent; text: "+ Add User"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showAddUser = true }
                    }
                    }
                    Rectangle { visible: showAddUser; width: parent.width; height: aUI.height + 24; radius: root.radiusMd; color: Qt.rgba(0.13,0.77,0.37,0.08); border.color: Qt.rgba(0.13,0.77,0.37,0.2); border.width: 1
                        Column { id: aUI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                            Text { text: "Create New User"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#fff" }
                            RowLayout { width: parent.width; spacing: 8
                                Column { Layout.fillWidth: true; spacing: 4
                                Text { text: "Username"; font.pixelSize: 11; color: root.textMuted }
                                Rectangle { width: parent.width; height: 30; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: 8; color: "#fff"; font.pixelSize: 12; clip: true; onTextChanged: newUsername = text
                                Text { visible: !parent.text; text: "Username..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            } }
                            }
                                Column { Layout.fillWidth: true; spacing: 4
                                Text { text: "Password"; font.pixelSize: 11; color: root.textMuted }
                                Rectangle { width: parent.width; height: 30; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: 8; color: "#fff"; font.pixelSize: 12; echoMode: TextInput.Password; clip: true; onTextChanged: newPassword = text
                                Text { visible: !parent.text; text: "Password..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            } }
                            }
                            }
                            RowLayout { width: parent.width; spacing: 6
                            Item { Layout.fillWidth: true }
                                Rectangle { width: 55; height: 26; radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06)
                                Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showAddUser = false }
                            }
                                Rectangle { width: 55; height: 26; radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addUser() }
                            }
                            }
                        }
                    }
                    Repeater { model: userList; delegate: Rectangle { width: cCol.width; height: 52; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Rectangle { width: 32; height: 32; radius: 16; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: (modelData.username || "?").charAt(0).toUpperCase(); color: "#fff"; font.pixelSize: 14; font.weight: Font.Medium }
                        }
                            Column { Layout.fillWidth: true; spacing: 2
                            Text { text: modelData.username || ""; font.pixelSize: 13; font.weight: Font.Medium; color: "#fff" }
                            Text { text: modelData.role || "user"; font.pixelSize: 10; color: root.textMuted }
                        }
                            Rectangle { width: 50; height: 20; radius: 10; color: Qt.rgba(0.13,0.77,0.37,0.15)
                            Text { anchors.centerIn: parent; text: "Active"; font.pixelSize: 9; color: root.accentGreen }
                        }
                            Rectangle { visible: (modelData.username || "") !== root.currentUser; width: 50; height: 22; radius: root.radiusSm; color: Qt.rgba(0.94,0.27,0.27,0.1); border.color: Qt.rgba(0.94,0.27,0.27,0.3); border.width: 1
                            Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 9; color: "#ef4444" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deleteUser(modelData.username) }
                        }
                        }
                    }
                }
                }
                // CHANNELS
                Column { width: parent.width; spacing: 12; visible: activeTab === "channels"
                    Text { text: "Channels"; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Connect messaging platforms"; font.pixelSize: 12; color: root.textMuted }
                    Rectangle { width: parent.width; height: wI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: waConnected ? Qt.rgba(0.13,0.77,0.37,0.3) : root.borderColor; border.width: 1
                        Column { id: wI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                            RowLayout { width: parent.width; spacing: 10
                                Rectangle { width: 36; height: 36; radius: 10; color: Qt.rgba(0.15,0.68,0.38,0.15)
                                Text { anchors.centerIn: parent; text: "\uf232"; font.family: root.iconFont; font.pixelSize: 16; color: "#25D366" }
                            }
                                Column { Layout.fillWidth: true; spacing: 2
                                Text { text: "WhatsApp"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#fff" }
                                Text { text: waConnected ? "Connected" : "Connect via QR code"; font.pixelSize: 11; color: waConnected ? root.accentGreen : root.textMuted }
                            }
                                Rectangle { width: 70; height: 28; radius: root.radiusSm; color: waConnected ? Qt.rgba(0.13,0.77,0.37,0.15) : root.accentBlue
                                Text { anchors.centerIn: parent; text: waConnecting ? "Waiting..." : waConnected ? "\u2713 Connected" : "Connect"; font.pixelSize: 11; font.weight: Font.DemiBold; color: waConnected ? root.accentGreen : "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!waConnected && !waConnecting) connectWhatsApp() }
                            }
                            }
                            Rectangle { visible: waQrCode !== "" && !waConnected; width: 200; height: 200; radius: root.radiusMd; color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter
                            Image { anchors.fill: parent; anchors.margins: 8; source: waQrCode; fillMode: Image.PreserveAspectFit; smooth: true }
                        }
                            Text { visible: waConnecting && waQrCode === ""; text: "Initializing WhatsApp..."; font.pixelSize: 11; color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                    Rectangle { width: parent.width; height: tI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: tI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                            RowLayout { width: parent.width; spacing: 10
                            Rectangle { width: 36; height: 36; radius: 10; color: Qt.rgba(0.16,0.55,0.85,0.15)
                            Text { anchors.centerIn: parent; text: "\uf2c6"; font.family: root.iconFont; font.pixelSize: 16; color: "#0088cc" }
                        }
                            Column { Layout.fillWidth: true; spacing: 2
                            Text { text: "Telegram"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Connect with bot token"; font.pixelSize: 11; color: root.textMuted }
                        } }
                            RowLayout { width: parent.width; spacing: 6
                            Rectangle { Layout.fillWidth: true; height: 30; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: 8; color: "#fff"; font.pixelSize: 11; clip: true; onTextChanged: tgToken = text
                            Text { visible: !parent.text; text: "Bot token from @BotFather..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        } }
                            Rectangle { width: 65; height: 30; radius: root.radiusSm; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectCh("telegram", tgToken) }
                        } }
                        }
                    }
                    Rectangle { width: parent.width; height: dI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: dI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                            RowLayout { width: parent.width; spacing: 10
                            Rectangle { width: 36; height: 36; radius: 10; color: Qt.rgba(0.35,0.40,0.95,0.15)
                            Text { anchors.centerIn: parent; text: "\uf11b"; font.family: root.iconFont; font.pixelSize: 16; color: "#5865F2" }
                        }
                            Column { Layout.fillWidth: true; spacing: 2
                            Text { text: "Discord"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Connect with bot token"; font.pixelSize: 11; color: root.textMuted }
                        } }
                            RowLayout { width: parent.width; spacing: 6
                            Rectangle { Layout.fillWidth: true; height: 30; radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: 8; color: "#fff"; font.pixelSize: 11; clip: true; onTextChanged: dcToken = text
                            Text { visible: !parent.text; text: "Discord bot token..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        } }
                            Rectangle { width: 65; height: 30; radius: root.radiusSm; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectCh("discord", dcToken) }
                        } }
                        }
                    }
                }
            }
        }
    }
}
