import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: loginScreen
    anchors.fill: parent
    color: root.bgVoid

    // Subtle gradient wallpaper
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a0a0f" }
            GradientStop { position: 0.5; color: "#0d0d14" }
            GradientStop { position: 1.0; color: "#0a0f0a" }
        }
    }

    // Subtle dot pattern overlay
    Canvas {
        anchors.fill: parent
        opacity: 0.03
        onPaint: {
            var ctx = getContext("2d");
            ctx.fillStyle = "#ffffff";
            for (var x = 0; x < width; x += 30) {
                for (var y = 0; y < height; y += 30) {
                    ctx.beginPath();
                    ctx.arc(x, y, 1, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
    }

    // ── Center Login Card ──
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        width: 340

        // Avatar circle
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 88
            height: 88
            radius: 44
            color: root.bgElevated
            border.color: root.borderColor
            border.width: 1

            Canvas {
                anchors.centerIn: parent
                width: 48; height: 48
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath(); ctx.fillStyle = "#60a5fa";
                    ctx.moveTo(7, 32);
                    ctx.quadraticCurveTo(3, 19, 12, 14);
                    ctx.quadraticCurveTo(20, 7, 32, 10);
                    ctx.quadraticCurveTo(42, 12, 44, 22);
                    ctx.quadraticCurveTo(48, 29, 43, 34);
                    ctx.quadraticCurveTo(44, 38, 48, 36);
                    ctx.quadraticCurveTo(50, 33, 49, 42);
                    ctx.quadraticCurveTo(46, 46, 41, 38);
                    ctx.quadraticCurveTo(32, 42, 24, 40);
                    ctx.quadraticCurveTo(14, 39, 7, 32);
                    ctx.fill();
                    ctx.beginPath(); ctx.fillStyle = "#0f172a";
                    ctx.arc(18, 20, 2.5, 0, Math.PI * 2); ctx.fill();
                    ctx.beginPath(); ctx.fillStyle = "#fff";
                    ctx.arc(19, 19, 1, 0, Math.PI * 2); ctx.fill();
                    ctx.strokeStyle = "#60a5fa"; ctx.lineWidth = 1.5;
                    ctx.beginPath(); ctx.moveTo(27, 10); ctx.lineTo(27, 3); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(24, 3); ctx.quadraticCurveTo(27, -2, 30, 3); ctx.stroke();
                }
            }
        }

        // Title
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "DeepOS"
            font.pixelSize: 22
            font.weight: Font.DemiBold
            color: root.textPrimary
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Sign in to continue"
            font.pixelSize: 13
            color: root.textSecondary
        }

        // Login form
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            // Username field
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: root.radiusMd
                color: root.bgSurface
                border.color: userField.activeFocus ? root.accentBlue : root.borderColor
                border.width: 1

                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.margins: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.textPrimary
                    font.pixelSize: 14
                    clip: true
                    text: "admin"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Username"
                        color: root.textMuted
                        font.pixelSize: 14
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            // Password field
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: root.radiusMd
                color: root.bgSurface
                border.color: passField.activeFocus ? root.accentBlue : root.borderColor
                border.width: 1

                TextInput {
                    id: passField
                    anchors.fill: parent
                    anchors.margins: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.textPrimary
                    font.pixelSize: 14
                    echoMode: TextInput.Password
                    clip: true
                    text: "admin"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        color: root.textMuted
                        font.pixelSize: 14
                        visible: !parent.text && !parent.activeFocus
                    }

                    Keys.onReturnPressed: doLogin()
                }
            }

            // Error message
            Text {
                id: errorText
                Layout.alignment: Qt.AlignHCenter
                text: ""
                color: root.accentRed
                font.pixelSize: 12
                visible: text !== ""
            }

            // Sign in button
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: root.radiusMd
                color: loginMouse.pressed ? Qt.darker(root.accentBlue, 1.2) :
                       loginMouse.containsMouse ? Qt.lighter(root.accentBlue, 1.1) : root.accentBlue

                Text {
                    anchors.centerIn: parent
                    text: loginBusy ? "Signing in..." : "Sign In"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
                }
            }
        }

        // Version
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            text: "Powered by OpenWhale Engine"
            font.pixelSize: 11
            color: root.textMuted
        }
    }

    property bool loginBusy: false

    function doLogin() {
        if (loginBusy) return;
        loginBusy = true;
        errorText.text = "";

        API.login(userField.text, passField.text, function(status, data) {
            loginBusy = false;
            if (status === 200 && data.sessionId) {
                API.setSession(data.sessionId);
                root.onLoginSuccess(userField.text, data.sessionId);
            } else {
                errorText.text = data.error || "Login failed";
            }
        });
    }
}
