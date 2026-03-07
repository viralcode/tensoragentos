import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: loginScreen
    anchors.fill: parent
    color: "#050510"

    property bool loginBusy: false
    property real glowPhase: 0

    Timer {
        running: true; repeat: true; interval: 60
        onTriggered: glowPhase += 0.04
    }

    // ── Background: Aurora (original style) ──
    Rectangle {
        anchors.fill: parent
        color: "#050510"
    }

    // Cyan nebula - top
    Rectangle {
        x: parent.width * 0.15; y: parent.height * 0.0
        width: parent.width * 0.7; height: parent.height * 0.5
        radius: width / 2; opacity: 0.09; rotation: -5
        color: "#0ea5e9"
    }

    // Indigo nebula - center
    Rectangle {
        x: parent.width * 0.2; y: parent.height * 0.1
        width: parent.width * 0.65; height: parent.height * 0.55
        radius: width / 2; opacity: 0.11; rotation: 10
        color: "#4f46e5"
    }

    // Rose accent - bottom
    Rectangle {
        x: parent.width * 0.5; y: parent.height * 0.5
        width: parent.width * 0.5; height: parent.height * 0.4
        radius: width / 2; opacity: 0.05
        color: "#f43f5e"
    }

    // Star field
    Canvas {
        anchors.fill: parent; opacity: 0.4
        onPaint: {
            var ctx = getContext("2d");
            var seed = 42;
            function rand() { seed = (seed * 16807 + 0) % 2147483647; return seed / 2147483647; }
            for (var i = 0; i < 90; i++) {
                var sx = rand() * width; var sy = rand() * height;
                var sr = rand() * 1.2 + 0.3; var so = rand() * 0.5 + 0.1;
                ctx.beginPath(); ctx.fillStyle = "rgba(255, 255, 255, " + so + ")";
                ctx.arc(sx, sy, sr, 0, Math.PI * 2); ctx.fill();
            }
        }
    }

    // ── Horizontal scan line (futuristic) ──
    Rectangle {
        id: scanLine
        width: parent.width; height: Math.round(1 * root.sf)
        color: Qt.rgba(0.35, 0.55, 1.0, 0.06)
        y: 0

        SequentialAnimation on y {
            running: true; loops: Animation.Infinite
            NumberAnimation { to: loginScreen.height; duration: 6000; easing.type: Easing.Linear }
            NumberAnimation { to: 0; duration: 0 }
        }
    }

    // ── Clock (top center) ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(50 * root.sf)
        spacing: Math.round(2 * root.sf)
        opacity: 0

        Text {
            id: loginClock
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "h:mm")
            font.pixelSize: Math.round(52 * root.sf)
            font.weight: Font.Light
            font.letterSpacing: Math.round(4 * root.sf)
            color: "#ffffff"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            font.pixelSize: Math.round(13 * root.sf)
            color: Qt.rgba(1, 1, 1, 0.45)
            font.letterSpacing: Math.round(1 * root.sf)
        }

        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: loginClock.text = Qt.formatTime(new Date(), "h:mm")
        }

        // Fade in
        Component.onCompleted: fadeInClock.start()
        NumberAnimation on opacity { id: fadeInClock; to: 1.0; duration: 800; easing.type: Easing.OutCubic }
    }

    // ── Center content ──
    Column {
        id: centerContent
        anchors.centerIn: parent
        spacing: Math.round(20 * root.sf)
        opacity: 0

        // Animated logo with rings
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(120 * root.sf); height: Math.round(120 * root.sf)

            // Outer rotating ring
            Rectangle {
                id: outerRing
                anchors.centerIn: parent
                width: Math.round(110 * root.sf); height: width; radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(0.35, 0.55, 1.0, 0.12)
                border.width: Math.round(1 * root.sf)
                rotation: 0

                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 20000
                    running: true; loops: Animation.Infinite
                }

                // Accent dot on ring
                Rectangle {
                    width: Math.round(4 * root.sf); height: Math.round(4 * root.sf)
                    radius: width / 2; color: "#60a5fa"
                    x: parent.width / 2 - width / 2
                    y: -height / 2
                    opacity: 0.8
                }
            }

            // Middle pulsing ring
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(90 * root.sf); height: width; radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(0.4, 0.5, 1.0, 0.1)
                border.width: Math.round(1 * root.sf)

                SequentialAnimation on border.color {
                    running: true; loops: Animation.Infinite
                    ColorAnimation { to: Qt.rgba(0.4, 0.5, 1.0, 0.25); duration: 2000; easing.type: Easing.InOutSine }
                    ColorAnimation { to: Qt.rgba(0.4, 0.5, 1.0, 0.08); duration: 2000; easing.type: Easing.InOutSine }
                }
            }

            // Inner circle (glass)
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(74 * root.sf); height: width; radius: width / 2
                color: Qt.rgba(0.08, 0.08, 0.15, 0.6)
                border.color: Qt.rgba(0.4, 0.5, 1.0, 0.15); border.width: 1
            }

            // Whale logo
            Image {
                anchors.centerIn: parent
                width: Math.round(48 * root.sf); height: Math.round(48 * root.sf)
                source: "assets/whale_logo.png"
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
            }
        }

        // OS Name
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "T E N S O R A G E N T   O S"
            font.pixelSize: Math.round(13 * root.sf)
            font.weight: Font.Medium
            font.letterSpacing: Math.round(2 * root.sf)
            color: Qt.rgba(1, 1, 1, 0.5)
        }

        // Spacer
        Item { width: 1; height: Math.round(8 * root.sf) }

        // Username field (pill)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(280 * root.sf); height: Math.round(42 * root.sf)
            radius: Math.round(21 * root.sf)
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: userField.activeFocus ? Qt.rgba(0.4, 0.55, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Math.round(16 * root.sf)
                anchors.rightMargin: Math.round(16 * root.sf)
                spacing: Math.round(8 * root.sf)

                Canvas {
                    width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter
                    property real s: root.sf; property bool focused: userField.activeFocus
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.strokeStyle = focused ? "#818cf8" : "rgba(255,255,255,0.3)";
                        ctx.lineWidth = 1.2; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.arc(7, 5, 2.8, 0, Math.PI * 2); ctx.stroke();
                        ctx.beginPath(); ctx.arc(7, 15, 5.5, Math.PI * 1.15, Math.PI * 1.85); ctx.stroke();
                        ctx.restore();
                    }
                    onFocusedChanged: requestPaint(); onSChanged: requestPaint()
                }

                TextInput {
                    id: userField
                    width: parent.width - Math.round(22 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#e2e8f0"; font.pixelSize: Math.round(13 * root.sf); clip: true
                    text: ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Username"; color: Qt.rgba(1, 1, 1, 0.2)
                        font.pixelSize: Math.round(13 * root.sf)
                        visible: !parent.text && !parent.activeFocus
                    }

                    Keys.onTabPressed: passField.forceActiveFocus()
                }
            }
        }

        // Password field (pill)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(280 * root.sf); height: Math.round(42 * root.sf)
            radius: Math.round(21 * root.sf)
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: passField.activeFocus ? Qt.rgba(0.4, 0.55, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Math.round(16 * root.sf)
                anchors.rightMargin: Math.round(7 * root.sf)
                spacing: Math.round(8 * root.sf)

                Canvas {
                    width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter
                    property real s: root.sf; property bool focused: passField.activeFocus
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                        ctx.save(); ctx.scale(s, s);
                        ctx.strokeStyle = focused ? "#818cf8" : "rgba(255,255,255,0.3)";
                        ctx.lineWidth = 1.2; ctx.lineCap = "round";
                        ctx.strokeRect(3, 7, 8, 6);
                        ctx.beginPath(); ctx.arc(7, 7, 2.5, Math.PI, 0); ctx.stroke();
                        ctx.restore();
                    }
                    onFocusedChanged: requestPaint(); onSChanged: requestPaint()
                }

                TextInput {
                    id: passField
                    width: parent.width - loginArrow.width - Math.round(38 * root.sf)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#e2e8f0"; font.pixelSize: Math.round(13 * root.sf)
                    echoMode: TextInput.Password; clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"; color: Qt.rgba(1, 1, 1, 0.2)
                        font.pixelSize: Math.round(13 * root.sf)
                        visible: !parent.text && !parent.activeFocus
                    }

                    Keys.onReturnPressed: doLogin()
                    Component.onCompleted: forceActiveFocus()
                }

                Rectangle {
                    id: loginArrow
                    width: Math.round(28 * root.sf); height: Math.round(28 * root.sf)
                    radius: width / 2; anchors.verticalCenter: parent.verticalCenter
                    color: loginMouse.containsMouse ? Qt.rgba(0.4, 0.5, 1.0, 0.3) : Qt.rgba(1, 1, 1, 0.08)

                    Canvas {
                        anchors.centerIn: parent
                        width: Math.round(10 * root.sf); height: Math.round(10 * root.sf)
                        property real s: root.sf
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                            ctx.save(); ctx.scale(s, s);
                            ctx.strokeStyle = "#fff"; ctx.lineWidth = 1.6; ctx.lineCap = "round"; ctx.lineJoin = "round";
                            ctx.beginPath(); ctx.moveTo(3, 1.5); ctx.lineTo(7.5, 5); ctx.lineTo(3, 8.5); ctx.stroke();
                            ctx.restore();
                        }
                        onSChanged: requestPaint()
                    }

                    MouseArea {
                        id: loginMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: doLogin()
                    }
                }
            }
        }

        // Status
        Text {
            id: errorText
            anchors.horizontalCenter: parent.horizontalCenter
            text: loginBusy ? "Authenticating..." : ""
            color: loginBusy ? Qt.rgba(0.6, 0.7, 1.0, 0.5) : "#f87171"
            font.pixelSize: Math.round(11 * root.sf)
            font.letterSpacing: Math.round(0.5 * root.sf)
            visible: text !== ""
        }

        // Fade in center content
        Component.onCompleted: fadeInCenter.start()
        NumberAnimation on opacity {
            id: fadeInCenter; to: 1.0; duration: 1000
            easing.type: Easing.OutCubic
        }
    }

    // ── Power Buttons (bottom-right) ──
    Row {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: Math.round(18 * root.sf)
        anchors.rightMargin: Math.round(18 * root.sf)
        spacing: Math.round(10 * root.sf)
        opacity: 0
        Component.onCompleted: fadeInPower.start()
        NumberAnimation on opacity { id: fadeInPower; to: 1.0; duration: 1200; easing.type: Easing.OutCubic }

        // Restart
        Rectangle {
            width: Math.round(34 * root.sf); height: Math.round(34 * root.sf)
            radius: width / 2; color: loginRestartMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

            Canvas {
                anchors.centerIn: parent
                width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                property real s: root.sf; property bool hov: loginRestartMa.containsMouse
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                    ctx.save(); ctx.scale(s, s);
                    ctx.strokeStyle = hov ? "#f59e0b" : "rgba(255,255,255,0.35)";
                    ctx.lineWidth = 1.4; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(7, 7, 4.5, -0.5, Math.PI * 1.5); ctx.stroke();
                    ctx.fillStyle = ctx.strokeStyle;
                    ctx.beginPath(); ctx.moveTo(7, 1.5); ctx.lineTo(10, 3.5); ctx.lineTo(7, 5.5); ctx.fill();
                    ctx.restore();
                }
                onHovChanged: requestPaint(); onSChanged: requestPaint()
            }
            MouseArea { id: loginRestartMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sysManager.runCommandAsync("sudo reboot", "") }
        }

        // Shut Down
        Rectangle {
            width: Math.round(34 * root.sf); height: Math.round(34 * root.sf)
            radius: width / 2; color: loginShutdownMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

            Canvas {
                anchors.centerIn: parent
                width: Math.round(14 * root.sf); height: Math.round(14 * root.sf)
                property real s: root.sf; property bool hov: loginShutdownMa.containsMouse
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                    ctx.save(); ctx.scale(s, s);
                    ctx.strokeStyle = hov ? "#ef4444" : "rgba(255,255,255,0.35)";
                    ctx.lineWidth = 1.6; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.moveTo(7, 1.5); ctx.lineTo(7, 6); ctx.stroke();
                    ctx.beginPath(); ctx.arc(7, 7, 4.5, -1.2, Math.PI + 1.2); ctx.stroke();
                    ctx.restore();
                }
                onHovChanged: requestPaint(); onSChanged: requestPaint()
            }
            MouseArea { id: loginShutdownMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sysManager.runCommandAsync("sudo shutdown -h now", "") }
        }
    }

    // ════════════════════════════════════════
    // ── Auth Logic ──
    // ════════════════════════════════════════

    Timer {
        id: xhrTimeout; interval: 5000; running: false; repeat: false
        property string pendingUser: ""
        onTriggered: { if (loginBusy) { loginBusy = false; root.onLoginSuccess(pendingUser, "system"); } }
    }

    Connections {
        target: sysManager
        function onAuthResult(success) {
            if (!loginBusy) return;
            if (!success) { loginBusy = false; errorText.text = "Incorrect password"; return; }
            proceedAfterAuth();
        }
    }

    function doLogin() {
        if (loginBusy) return;
        loginBusy = true; errorText.text = "";
        var hasAsync = (typeof sysManager.authenticateAsync === "function");
        if (hasAsync) { sysManager.authenticateAsync(userField.text, passField.text); }
        else {
            var ok = sysManager.authenticate(userField.text, passField.text);
            if (!ok) { loginBusy = false; errorText.text = "Incorrect password"; return; }
            proceedAfterAuth();
        }
    }

    function proceedAfterAuth() {
        xhrTimeout.pendingUser = userField.text; xhrTimeout.restart();
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBase + "/auth/login");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                xhrTimeout.stop(); loginBusy = false;
                if (xhr.status === 200) {
                    try { var resp = JSON.parse(xhr.responseText); if (resp.ok && resp.sessionId) { root.onLoginSuccess(userField.text, resp.sessionId); return; } } catch(e) {}
                }
                root.onLoginSuccess(userField.text, "system");
            }
        };
        xhr.send(JSON.stringify({ username: "admin", password: "admin" }));
    }
}
