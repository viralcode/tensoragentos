import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: loginScreen
    anchors.fill: parent
    color: "#050510"

    property bool loginBusy: false
    property real glowPhase: 0

    // ── Animated phase for effects (very slow — only used for whale ring) ──
    // PERF: 500ms interval. Login screen is mostly static; fast timers pin CPU on pixman renderer.
    Timer {
        running: true; repeat: true; interval: 500
        onTriggered: glowPhase += 0.3
    }

    // ════════════════════════════════════════
    // ── Aurora Background (matches desktop) ──
    // ════════════════════════════════════════

    // Base deep gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#050510" }
            GradientStop { position: 0.3; color: "#0a0f20" }
            GradientStop { position: 0.6; color: "#0c1025" }
            GradientStop { position: 1.0; color: "#08061a" }
        }
    }

    // Aurora glow - top center (cyan/teal)
    Rectangle {
        x: parent.width * 0.15; y: parent.height * 0.0
        width: parent.width * 0.7; height: parent.height * 0.5
        radius: width / 2; opacity: 0.09
        rotation: -5
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0ea5e9" }
            GradientStop { position: 0.4; color: "#06b6d4" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Aurora glow - center (purple/indigo)
    Rectangle {
        x: parent.width * 0.2; y: parent.height * 0.1
        width: parent.width * 0.65; height: parent.height * 0.55
        radius: width / 2; opacity: 0.11
        rotation: 10
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#7c3aed" }
            GradientStop { position: 0.5; color: "#1d4ed8" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Warm accent - bottom (rose/pink)
    Rectangle {
        x: parent.width * 0.5; y: parent.height * 0.5
        width: parent.width * 0.5; height: parent.height * 0.4
        radius: width / 2; opacity: 0.05
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f43f5e" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Star field
    Canvas {
        anchors.fill: parent; opacity: 0.4
        onPaint: {
            var ctx = getContext("2d");
            var seed = 42;
            function rand() { seed = (seed * 16807 + 0) % 2147483647; return seed / 2147483647; }
            for (var i = 0; i < 80; i++) {
                var sx = rand() * width; var sy = rand() * height;
                var sr = rand() * 1.2 + 0.3; var so = rand() * 0.5 + 0.1;
                ctx.beginPath(); ctx.fillStyle = "rgba(255, 255, 255, " + so + ")";
                ctx.arc(sx, sy, sr, 0, Math.PI * 2); ctx.fill();
            }
        }
    }

    // ════════════════════════════════════════
    // ── Login Card ──
    // ════════════════════════════════════════

    Rectangle {
        id: loginCard
        anchors.centerIn: parent
        width: Math.round(380 * root.sf)
        height: cardContent.height + Math.round(60 * root.sf)
        radius: Math.round(20 * root.sf)
        color: Qt.rgba(0.06, 0.06, 0.10, 0.75)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // Glassmorphism top shine
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: Math.round(1 * root.sf); radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.12) }
                GradientStop { position: 0.7; color: Qt.rgba(0.55, 0.35, 1.0, 0.15) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Subtle glow behind card — static, no animation (saves full repaint)
        Rectangle {
            anchors.centerIn: parent; z: -1
            width: parent.width + Math.round(60 * root.sf)
            height: parent.height + Math.round(60 * root.sf)
            radius: Math.round(40 * root.sf)
            opacity: 0.12
            color: "#3b82f6"
        }

        ColumnLayout {
            id: cardContent
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Math.round(30 * root.sf)
            spacing: Math.round(20 * root.sf)

            // ── Animated Whale Logo ──
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(80 * root.sf)
                Layout.preferredHeight: Math.round(80 * root.sf)

                // Pulsing ring — opacity animation only (safe, no binding loop)
                Rectangle {
                    id: whaleRing
                    anchors.centerIn: parent
                    width: Math.round(76 * root.sf)
                    height: Math.round(76 * root.sf)
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(0.35, 0.55, 1.0, 0.18)
                    border.width: Math.round(1.5 * root.sf)
                    SequentialAnimation on opacity {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }

                // Inner circle
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(68 * root.sf); height: width; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.15, 0.25, 0.55, 0.6) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.10, 0.10, 0.25, 0.4) }
                    }
                    border.color: Qt.rgba(0.4, 0.6, 1.0, 0.2); border.width: 1
                }

                // Whale logo
                Image {
                    anchors.centerIn: parent
                    width: Math.round(50 * root.sf); height: Math.round(50 * root.sf)
                    source: "assets/whale_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                }
            }

            // ── Title ──
            Column {
                Layout.alignment: Qt.AlignHCenter; spacing: Math.round(6 * root.sf)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TensorAgent OS"
                    font.pixelSize: Math.round(24 * root.sf)
                    font.weight: Font.Bold
                    font.letterSpacing: Math.round(1 * root.sf)
                    color: "#ffffff"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var hour = new Date().getHours();
                        if (hour < 12) return "Good morning";
                        if (hour < 17) return "Good afternoon";
                        return "Good evening";
                    }
                    font.pixelSize: Math.round(13 * root.sf)
                    color: Qt.rgba(0.6, 0.7, 0.9, 0.7)
                }
            }

            // ── Form ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: Math.round(14 * root.sf)

                // Username
                Column {
                    Layout.fillWidth: true; spacing: Math.round(6 * root.sf)
                    Text { text: "Username"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: Qt.rgba(0.6, 0.7, 0.9, 0.6) }
                    Rectangle {
                        width: parent.width; height: Math.round(44 * root.sf); radius: Math.round(10 * root.sf)
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: userField.activeFocus ? Qt.rgba(0.35, 0.55, 1.0, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: userField.activeFocus ? 1.5 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Row {
                            anchors.fill: parent; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            // User icon
                            Canvas {
                                width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                                anchors.verticalCenter: parent.verticalCenter
                                property real s: root.sf; property bool focused: userField.activeFocus
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                    ctx.save(); ctx.scale(s, s);
                                    ctx.strokeStyle = focused ? "#6b8aff" : "#555"; ctx.lineWidth = 1.4; ctx.lineCap = "round";
                                    ctx.beginPath(); ctx.arc(9, 6, 3.5, 0, Math.PI * 2); ctx.stroke();
                                    ctx.beginPath(); ctx.arc(9, 18, 7, Math.PI * 1.2, Math.PI * 1.8); ctx.stroke();
                                    ctx.restore();
                                }
                                onFocusedChanged: requestPaint(); onSChanged: requestPaint()
                            }
                            TextInput {
                                id: userField; width: parent.width - Math.round(28 * root.sf)
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#fff"; font.pixelSize: Math.round(14 * root.sf); clip: true
                                text: ""
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Enter username"; color: Qt.rgba(1,1,1,0.25); font.pixelSize: Math.round(14 * root.sf); visible: !parent.text && !parent.activeFocus }
                            }
                        }
                    }
                }

                // Password
                Column {
                    Layout.fillWidth: true; spacing: Math.round(6 * root.sf)
                    Text { text: "Password"; font.pixelSize: Math.round(11 * root.sf); font.weight: Font.Medium; color: Qt.rgba(0.6, 0.7, 0.9, 0.6) }
                    Rectangle {
                        width: parent.width; height: Math.round(44 * root.sf); radius: Math.round(10 * root.sf)
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: passField.activeFocus ? Qt.rgba(0.35, 0.55, 1.0, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: passField.activeFocus ? 1.5 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Row {
                            anchors.fill: parent; anchors.margins: Math.round(12 * root.sf); spacing: Math.round(10 * root.sf)
                            // Lock icon
                            Canvas {
                                width: Math.round(18 * root.sf); height: Math.round(18 * root.sf)
                                anchors.verticalCenter: parent.verticalCenter
                                property real s: root.sf; property bool focused: passField.activeFocus
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                    ctx.save(); ctx.scale(s, s);
                                    ctx.strokeStyle = focused ? "#6b8aff" : "#555"; ctx.lineWidth = 1.4; ctx.lineCap = "round";
                                    ctx.strokeRect(4, 8, 10, 9);
                                    ctx.beginPath(); ctx.arc(9, 8, 3.5, Math.PI, 0); ctx.stroke();
                                    ctx.beginPath(); ctx.arc(9, 12, 1, 0, Math.PI * 2); ctx.fill();
                                    ctx.restore();
                                }
                                onFocusedChanged: requestPaint(); onSChanged: requestPaint()
                            }
                            TextInput {
                                id: passField; width: parent.width - Math.round(28 * root.sf)
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#fff"; font.pixelSize: Math.round(14 * root.sf)
                                echoMode: TextInput.Password; clip: true
                                text: ""
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Enter password"; color: Qt.rgba(1,1,1,0.25); font.pixelSize: Math.round(14 * root.sf); visible: !parent.text && !parent.activeFocus }
                                Keys.onReturnPressed: doLogin()
                            }
                        }
                    }
                }

                // Error message
                Text {
                    id: errorText; Layout.alignment: Qt.AlignHCenter
                    text: ""; color: "#f87171"; font.pixelSize: Math.round(12 * root.sf); visible: text !== ""
                }

                // Sign In button
                Rectangle {
                    Layout.fillWidth: true; height: Math.round(52 * root.sf)
                    radius: Math.round(12 * root.sf)

                    color: loginMouse.pressed ? "#2563eb" : loginMouse.containsMouse ? "#4f7df7" : "#3b82f6"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // Button glow
                    Rectangle {
                        anchors.centerIn: parent; z: -1
                        width: parent.width; height: parent.height + Math.round(8 * root.sf)
                        radius: Math.round(14 * root.sf)
                        opacity: loginMouse.containsMouse ? 0.3 : 0.15
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        color: "#3b82f6"
                    }

                    Row {
                        anchors.centerIn: parent; spacing: Math.round(8 * root.sf)
                        Text {
                            text: loginBusy ? "" : "→"; font.pixelSize: Math.round(16 * root.sf)
                            font.weight: Font.Bold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                            visible: !loginBusy
                        }
                        Text {
                            text: loginBusy ? "Signing in..." : "Sign In"
                            font.pixelSize: Math.round(14 * root.sf); font.weight: Font.DemiBold
                            color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: loginMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: doLogin()
                    }
                }
            }

            // ── Footer ──
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(8 * root.sf)
                text: "Powered by TensorAgent Engine"
                font.pixelSize: Math.round(10 * root.sf)
                color: Qt.rgba(1, 1, 1, 0.2)
            }
        }
    }

    // ── Bottom version bar ──
    Text {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Math.round(16 * root.sf)
        text: "v0.1.0"
        font.pixelSize: Math.round(10 * root.sf)
        color: Qt.rgba(1, 1, 1, 0.15)
    }

    // Timeout timer: if XHR never fires callback, fall back to system session
    Timer {
        id: xhrTimeout
        interval: 5000; running: false; repeat: false
        property string pendingUser: ""
        onTriggered: {
            if (loginBusy) {
                console.log("LoginScreen: XHR timeout — falling back to system session");
                loginBusy = false;
                root.onLoginSuccess(pendingUser, "system");
            }
        }
    }

    function doLogin() {
        if (loginBusy) return;
        loginBusy = true;
        errorText.text = "";

        // Authenticate against Linux kernel (PAM/shadow)
        var ok = sysManager.authenticate(userField.text, passField.text);
        if (!ok) {
            loginBusy = false;
            errorText.text = "Invalid username or password";
            return;
        }

        // Start timeout — if API never responds, we'll still log in
        xhrTimeout.pendingUser = userField.text;
        xhrTimeout.restart();

        // Now get a real API session token from OpenWhale
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/auth/login");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                xhrTimeout.stop();  // Cancel timeout — we got a response
                loginBusy = false;
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (resp.ok && resp.sessionId) {
                            root.onLoginSuccess(userField.text, resp.sessionId);
                            return;
                        }
                    } catch(e) {}
                }
                // API login failed — fall back to "system" session (local mode)
                root.onLoginSuccess(userField.text, "system");
            }
        };
        xhr.send(JSON.stringify({ username: "admin", password: "admin" }));
    }
}
