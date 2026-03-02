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
        try {
            var result = sysManager.listUsers();
            userList = JSON.parse(result);
        } catch(e) {
            userList = [{ username: root.currentUser, role: "admin" }];
        }
    }
    function addUser() {
        if (!newUsername || !newPassword) { root.showToast("Username and password required", "error"); return; }
        var ok = sysManager.addUser(newUsername, newPassword);
        if (ok) {
            root.showToast("User '" + newUsername + "' created successfully", "success");
        } else {
            root.showToast("Failed to create user '" + newUsername + "'", "error");
        }
        showAddUser = false; newUsername = ""; newPassword = ""; loadUsers();
    }
    function deleteUser(u) {
        if (u === root.currentUser) { root.showToast("Cannot delete your own account", "error"); return; }
        var ok = sysManager.deleteUser(u);
        if (ok) {
            root.showToast("User '" + u + "' deleted", "success");
        } else {
            root.showToast("Failed to delete user '" + u + "'", "error");
        }
        loadUsers();
    }
    function changePassword(newPass) {
        if (!newPass) { root.showToast("Enter a new password", "error"); return; }
        var ok = sysManager.changePassword(root.currentUser, newPass);
        if (ok) {
            root.showToast("Password updated successfully", "success");
        } else {
            root.showToast("Failed to update password", "error");
        }
    }
    property int qrPollCount: 0
    function connectWhatsApp() {
        waConnecting = true; waQrCode = ""; qrPollCount = 0;
        root.showToast("Initializing WhatsApp...", "success");
        // First disconnect to clear any stuck state, then reconnect
        var dxhr = new XMLHttpRequest();
        dxhr.open("POST", root.apiBase + "/channels/whatsapp/disconnect");
        dxhr.setRequestHeader("Content-Type", "application/json");
        dxhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        dxhr.onreadystatechange = function() {
            if (dxhr.readyState === 4) {
                // Now reconnect fresh
                var xhr = new XMLHttpRequest();
                xhr.open("POST", root.apiBase + "/channels/whatsapp/connect");
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        if (xhr.status === 200) { qrTimer.start(); }
                        else { root.showToast("Failed to start WhatsApp (HTTP " + xhr.status + ")", "error"); waConnecting = false; }
                    }
                };
                xhr.send();
            }
        };
        dxhr.send();
    }
    function pollWAQR() {
        qrPollCount++;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBase + "/channels/whatsapp/status");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    waConnected = d.connected || false;
                    if (d.qrCode) { waQrCode = d.qrCode; root.showToast("Scan QR code with WhatsApp", "success"); }
                    if (waConnected) { root.showToast("WhatsApp connected!", "success"); waConnecting = false; }
                    else if (waConnecting && qrPollCount < 20) { qrTimer.start(); }
                    else { waConnecting = false; if (!waConnected) root.showToast("WhatsApp connection timed out", "error"); }
                } catch(e) { waConnecting = false; root.showToast("WhatsApp error", "error"); }
            } else if (xhr.readyState === 4) { waConnecting = false; root.showToast("WhatsApp status check failed", "error"); }
        };
        xhr.send();
    }
    Timer { id: qrTimer; interval: 3000; repeat: false; onTriggered: pollWAQR() }
    function connectCh(t, tok) {
        if (!tok) { root.showToast("Enter a token for " + t, "error"); return; }
        root.showToast("Connecting " + t.charAt(0).toUpperCase() + t.slice(1) + "...", "success");
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/channels/" + t);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + root.sessionId);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) { root.showToast(t.charAt(0).toUpperCase() + t.slice(1) + " connected successfully!", "success"); }
                else {
                    try { var e = JSON.parse(xhr.responseText); root.showToast(e.error || "Failed to connect " + t, "error"); }
                    catch(ex) { root.showToast("Failed to connect " + t + " (HTTP " + xhr.status + ")", "error"); }
                }
            }
        };
        xhr.send(JSON.stringify({ token: tok, enabled: true }));
    }
    RowLayout {
        anchors.fill: parent; spacing: Math.round(0 * root.sf)
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: Math.round(170 * root.sf); color: Qt.rgba(0,0,0,0.2)
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: Math.round(1 * root.sf); color: root.borderColor }
            Column {
                anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); anchors.topMargin: Math.round(10 * root.sf); spacing: Math.round(2 * root.sf)
                Repeater {
                    model: [{ id: "profile", icon: "\uf007", label: "Profile" }, { id: "users", icon: "\uf0c0", label: "Users" }, { id: "channels", icon: "\uf1e6", label: "Channels" }]
                    delegate: Rectangle {
                        width: parent ? parent.width : 150; height: Math.round(34 * root.sf); radius: root.radiusSm
                        color: activeTab === modelData.id ? Qt.rgba(1,1,1,0.08) : sMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"
                        Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(10 * root.sf); spacing: Math.round(8 * root.sf)
                            Text { text: modelData.icon; font.family: root.iconFont; font.pixelSize: Math.round(13 * root.sf); color: root.accentBlue }
                            Text { text: modelData.label; font.pixelSize: Math.round(13 * root.sf); color: activeTab === modelData.id ? "#fff" : root.textSecondary }
                        }
                        Rectangle { visible: activeTab === modelData.id; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Math.round(3 * root.sf); height: Math.round(18 * root.sf); radius: 2; color: root.accentBlue }
                        MouseArea { id: sMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activeTab = modelData.id }
                    }
                }
            }
        }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; contentHeight: cCol.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: cCol; width: parent.width - 32; x: Math.round(16 * root.sf); y: Math.round(16 * root.sf); spacing: Math.round(14 * root.sf)
                // PROFILE
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "profile"
                    Text { text: "Profile"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Manage your account settings"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                    Rectangle { width: parent.width; height: pI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: pI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            RowLayout { spacing: Math.round(10 * root.sf)
                                Rectangle { width: Math.round(48 * root.sf); height: Math.round(48 * root.sf); radius: 24; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: root.currentUser.charAt(0).toUpperCase(); font.pixelSize: Math.round(20 * root.sf); font.weight: Font.Bold; color: "#fff" }
                            }
                                Column { spacing: Math.round(2 * root.sf); Layout.fillWidth: true
                                Text { text: root.currentUser; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                Text { text: "Administrator"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                            }
                            }
                            Rectangle { width: parent.width; height: Math.round(1 * root.sf); color: root.borderColor }
                            Text { text: "Change Password"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                                Rectangle { Layout.fillWidth: true; height: Math.round(32 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { id: pwField; anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(12 * root.sf); echoMode: TextInput.Password; clip: true
                                Text { visible: !parent.text; text: "New password..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                            } }
                                Rectangle { width: Math.round(65 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Update"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: changePassword(pwField.text) }
                            }
                            }
                        }
                    }
                }
                // USERS
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "users"
                    RowLayout { width: parent.width
                        Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                        Text { text: "User Management"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        Text { text: "Manage who can access this system"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                    }
                        Rectangle { width: Math.round(90 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                        Text { anchors.centerIn: parent; text: "+ Add User"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showAddUser = true }
                    }
                    }
                    Rectangle { visible: showAddUser; width: parent.width; height: aUI.height + 24; radius: root.radiusMd; color: Qt.rgba(0.13,0.77,0.37,0.08); border.color: Qt.rgba(0.13,0.77,0.37,0.2); border.width: 1
                        Column { id: aUI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            Text { text: "Create New User"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            RowLayout { width: parent.width; spacing: Math.round(8 * root.sf)
                                Column { Layout.fillWidth: true; spacing: Math.round(4 * root.sf)
                                Text { text: "Username"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                Rectangle { width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(12 * root.sf); clip: true; onTextChanged: newUsername = text
                                Text { visible: !parent.text; text: "Username..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                            } }
                            }
                                Column { Layout.fillWidth: true; spacing: Math.round(4 * root.sf)
                                Text { text: "Password"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                                Rectangle { width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(12 * root.sf); echoMode: TextInput.Password; clip: true; onTextChanged: newPassword = text
                                Text { visible: !parent.text; text: "Password..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(12 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                            } }
                            }
                            }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                            Item { Layout.fillWidth: true }
                                Rectangle { width: Math.round(55 * root.sf); height: Math.round(26 * root.sf); radius: root.radiusSm; color: Qt.rgba(1,1,1,0.06)
                                Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(11 * root.sf); color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showAddUser = false }
                            }
                                Rectangle { width: Math.round(55 * root.sf); height: Math.round(26 * root.sf); radius: root.radiusSm; color: root.accentBlue
                                Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addUser() }
                            }
                            }
                        }
                    }
                    Repeater { model: userList; delegate: Rectangle { width: cCol.width; height: Math.round(52 * root.sf); radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        RowLayout { anchors.fill: parent; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            Rectangle { width: Math.round(32 * root.sf); height: Math.round(32 * root.sf); radius: 16; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: (modelData.username || "?").charAt(0).toUpperCase(); color: "#fff"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Medium }
                        }
                            Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                            Text { text: modelData.username || ""; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.Medium; color: "#fff" }
                            Text { text: modelData.role || "user"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
                        }
                            Rectangle { width: Math.round(50 * root.sf); height: Math.round(20 * root.sf); radius: 10; color: Qt.rgba(0.13,0.77,0.37,0.15)
                            Text { anchors.centerIn: parent; text: "Active"; font.pixelSize: Math.round(9 * root.sf); color: root.accentGreen }
                        }
                            Rectangle { visible: (modelData.username || "") !== root.currentUser; width: Math.round(50 * root.sf); height: Math.round(22 * root.sf); radius: root.radiusSm; color: Qt.rgba(0.94,0.27,0.27,0.1); border.color: Qt.rgba(0.94,0.27,0.27,0.3); border.width: 1
                            Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: Math.round(9 * root.sf); color: "#ef4444" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deleteUser(modelData.username) }
                        }
                        }
                    }
                }
                }
                // CHANNELS
                Column { width: parent.width; spacing: Math.round(12 * root.sf); visible: activeTab === "channels"
                    Text { text: "Channels"; font.pixelSize: Math.round(18 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                    Text { text: "Connect messaging platforms"; font.pixelSize: Math.round(12 * root.sf); color: root.textMuted }
                    Rectangle { width: parent.width; height: wI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: waConnected ? Qt.rgba(0.13,0.77,0.37,0.3) : root.borderColor; border.width: 1
                        Column { id: wI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width; spacing: Math.round(10 * root.sf)
                                Rectangle { width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: Qt.rgba(0.15,0.68,0.38,0.15)
                                Text { anchors.centerIn: parent; text: "\uf232"; font.family: root.iconFont; font.pixelSize: Math.round(16 * root.sf); color: "#25D366" }
                            }
                                Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                                Text { text: "WhatsApp"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                                Text { text: waConnected ? "Connected" : "Connect via QR code"; font.pixelSize: Math.round(11 * root.sf); color: waConnected ? root.accentGreen : root.textMuted }
                            }
                                Rectangle { width: Math.round(70 * root.sf); height: Math.round(28 * root.sf); radius: root.radiusSm; color: waConnected ? Qt.rgba(0.13,0.77,0.37,0.15) : root.accentBlue
                                Text { anchors.centerIn: parent; text: waConnecting ? "Waiting..." : waConnected ? "\u2713 Connected" : "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: waConnected ? root.accentGreen : "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!waConnected && !waConnecting) connectWhatsApp() }
                            }
                            }
                            Rectangle { visible: waQrCode !== "" && !waConnected; width: Math.round(200 * root.sf); height: Math.round(200 * root.sf); radius: root.radiusMd; color: "#fff"; anchors.horizontalCenter: parent.horizontalCenter
                            Image { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); source: waQrCode; fillMode: Image.PreserveAspectFit; smooth: true }
                        }
                            Text { visible: waConnecting && waQrCode === ""; text: "Initializing WhatsApp..."; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                    Rectangle { width: parent.width; height: tI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: tI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width; spacing: Math.round(10 * root.sf)
                            Rectangle { width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: Qt.rgba(0.16,0.55,0.85,0.15)
                            Text { anchors.centerIn: parent; text: "\uf2c6"; font.family: root.iconFont; font.pixelSize: Math.round(16 * root.sf); color: "#0088cc" }
                        }
                            Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                            Text { text: "Telegram"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Connect with bot token"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        } }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                            Rectangle { Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(11 * root.sf); clip: true; onTextChanged: tgToken = text
                            Text { visible: !parent.text; text: "Bot token from @BotFather..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(11 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                        } }
                            Rectangle { width: Math.round(65 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectCh("telegram", tgToken) }
                        } }
                        }
                    }
                    Rectangle { width: parent.width; height: dI.height + 24; radius: root.radiusMd; color: root.bgCard; border.color: root.borderColor; border.width: 1
                        Column { id: dI; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)
                            RowLayout { width: parent.width; spacing: Math.round(10 * root.sf)
                            Rectangle { width: Math.round(36 * root.sf); height: Math.round(36 * root.sf); radius: 10; color: Qt.rgba(0.35,0.40,0.95,0.15)
                            Text { anchors.centerIn: parent; text: "\uf11b"; font.family: root.iconFont; font.pixelSize: Math.round(16 * root.sf); color: "#5865F2" }
                        }
                            Column { Layout.fillWidth: true; spacing: Math.round(2 * root.sf)
                            Text { text: "Discord"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            Text { text: "Connect with bot token"; font.pixelSize: Math.round(11 * root.sf); color: root.textMuted }
                        } }
                            RowLayout { width: parent.width; spacing: Math.round(6 * root.sf)
                            Rectangle { Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: root.radiusSm; color: Qt.rgba(0,0,0,0.3); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            TextInput { anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); color: "#fff"; font.pixelSize: Math.round(11 * root.sf); clip: true; onTextChanged: dcToken = text
                            Text { visible: !parent.text; text: "Discord bot token..."; color: Qt.rgba(1,1,1,0.2); font.pixelSize: Math.round(11 * root.sf); anchors.verticalCenter: parent.verticalCenter }
                        } }
                            Rectangle { width: Math.round(65 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm; color: root.accentBlue
                            Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectCh("discord", dcToken) }
                        } }
                        }
                    }
                }
            }
        }
    }
}
