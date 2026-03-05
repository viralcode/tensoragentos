import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import QtWayland.Compositor.WlShell
import "api.js" as API

WaylandCompositor {
    id: comp

    // Our custom Wayland socket — native apps connect here
    socketName: "whaleos-0"

    WaylandOutput {
        sizeFollowsWindow: true
        scaleFactor: 1
        manufacturer: "TensorAgent"
        model: "Virtual Display"
        window: Window {
            id: root
            visible: true
            visibility: Window.FullScreen
            flags: Qt.FramelessWindowHint | Qt.Window
            title: "TensorAgent OS"
            color: "#0d0d0d"

            // ── Clipboard: poll Wayland clipboard + keep Qt clipboard synced ──
            property string lastClipboard: ""
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    var text = sysManager.pasteFromClipboard();
                    if (text.length > 0 && text !== root.lastClipboard) {
                        root.lastClipboard = text;
                        sysManager.copyToClipboard(text);  // Syncs to Qt clipboard
                    }
                }
            }
            Shortcut {
                sequence: "Ctrl+V"
                context: Qt.ApplicationShortcut
                onActivated: {
                    var text = sysManager.pasteFromClipboard();
                    if (text.length > 0 && root.activeFocusItem) {
                        if (typeof root.activeFocusItem.insert === "function") {
                            root.activeFocusItem.insert(root.activeFocusItem.cursorPosition, text);
                        } else if (root.activeFocusItem.text !== undefined) {
                            root.activeFocusItem.text += text;
                        }
                    }
                }
            }
            Shortcut {
                sequence: "Ctrl+C"
                context: Qt.ApplicationShortcut
                onActivated: {
                    if (root.activeFocusItem && root.activeFocusItem.selectedText) {
                        sysManager.copyToClipboard(root.activeFocusItem.selectedText);
                    }
                }
            }

            // ── Display Scale ──
            property real userScale: 1.0
            readonly property real sf: userScale * Math.max(0.5, Math.min(2.5, Math.min(root.width / 1024.0, root.height / 768.0)))

            // ── Global State ──
            property bool loggedIn: false
            property string currentUser: ""
            property string sessionId: ""
            property var openWindows: []
            property string settingsOpenTab: ""  // Set before opening Settings to jump to a tab

            // ── Open App helper (usable from Desktop, context menu, etc.) ──
            function openAppWindow(appId, title, icon) {
                for (var i = 0; i < openWindows.length; i++) {
                    if (openWindows[i].appId === appId) return;
                }
                var wins = openWindows.slice();
                wins.push({ appId: appId, title: title, icon: icon });
                openWindows = wins;
            }


            // ── Wayland Surface Tracking ──
            property var pendingSurfaces: []   // Surfaces waiting to be assigned to AppWindows

            // ── API ──
            property string apiBase: "http://127.0.0.1:7777/dashboard/api"

            // ── Theme Constants ──
            readonly property color bgVoid: "#0d0d0d"
            readonly property color bgSurface: "#141414"
            readonly property color bgElevated: "#1c1c1c"
            readonly property color bgCard: "#1f1f1f"
            readonly property color borderColor: "#2a2a2a"
            readonly property color borderLight: "#333333"
            readonly property color textPrimary: "#ffffff"
            readonly property color textSecondary: "#999999"
            readonly property color textMuted: "#666666"
            readonly property color accentBlue: "#3b82f6"
            readonly property color accentGreen: "#22c55e"
            readonly property color accentRed: "#ef4444"
            readonly property color accentOrange: "#f97316"
            readonly property int radiusSm: Math.round(6 * sf)
            readonly property int radiusMd: Math.round(10 * sf)
            readonly property int radiusLg: Math.round(14 * sf)

            // ── Icon Fonts ──
            property string iconFont: faLoader.name
            property string iconFontBrands: faBrandsLoader.name

            FontLoader { id: faLoader; source: "fonts/fa-solid-900.woff2" }
            FontLoader { id: faBrandsLoader; source: "fonts/fa-brands-400.woff2" }
            FontLoader { id: systemFont; source: "" }

            // ── Window Management ──
            property int nextZ: 100

            function bringToFront(win) {
                nextZ++;
                win.z = nextZ;
            }

            // ── Assign a Wayland surface to an AppWindow ──
            function assignSurface(toplevel, xdgSurface) {
                // Try immediate match first
                if (tryMatchSurface(toplevel, xdgSurface)) return;

                // Title/appId may not be set yet — queue for deferred matching
                var pending = pendingSurfaces.slice();
                pending.push({ toplevel: toplevel, xdgSurface: xdgSurface, attempts: 0 });
                pendingSurfaces = pending;
                surfaceMatchTimer.start();
            }

            function tryMatchSurface(toplevel, xdgSurface) {
                var appTitle = toplevel.title || "";
                var appId = toplevel.appId || "";

                if (appTitle.length === 0 && appId.length === 0) return false;

                for (var i = 0; i < openWindows.length; i++) {
                    var win = openWindows[i];
                    if (win.appId && win.appId.indexOf("native-") === 0 && !win.surface) {
                        var searchName = win.searchName || "";
                        if (searchName.length > 0 &&
                            (appTitle.toLowerCase().indexOf(searchName.toLowerCase()) >= 0 ||
                             appId.toLowerCase().indexOf(searchName.toLowerCase()) >= 0)) {
                            var wins = openWindows.slice();
                            wins[i] = {
                                appId: win.appId,
                                title: win.title,
                                icon: win.icon,
                                cmd: win.cmd || "",
                                searchName: win.searchName || "",
                                surface: xdgSurface,
                                toplevel: toplevel
                            };
                            openWindows = wins;
                            return true;
                        }
                    }
                }
                return false;
            }

            // Timer to retry matching pending surfaces
            Timer {
                id: surfaceMatchTimer
                interval: 500; repeat: true; running: false
                onTriggered: {
                    var remaining = [];
                    for (var i = 0; i < root.pendingSurfaces.length; i++) {
                        var s = root.pendingSurfaces[i];
                        if (root.tryMatchSurface(s.toplevel, s.xdgSurface)) {
                            continue; // matched!
                        }
                        s.attempts++;
                        if (s.attempts < 20) {
                            remaining.push(s);
                        }
                    }
                    root.pendingSurfaces = remaining;
                    if (remaining.length === 0) surfaceMatchTimer.stop();
                }
            }

            // ── Login Screen ──
            Loader {
                id: loginLoader
                anchors.fill: parent
                active: !root.loggedIn
                source: "LoginScreen.qml"
            }

            // ── Desktop ──
            Loader {
                id: desktopLoader
                anchors.fill: parent
                active: root.loggedIn
                source: "Desktop.qml"
            }

            function onLoginSuccess(user, session) {
                currentUser = user;
                sessionId = session;
                API.setSession(session);
                loggedIn = true;
            }

            function doLogout() {
                loggedIn = false;
                currentUser = "";
                sessionId = "";
                openWindows = [];
            }

            // ── Toast Notification System ──
            function showToast(message, type) {
                toastText.text = message;
                toastText.color = "#fff";
                if (type === "success") {
                    toastBg.color = Qt.rgba(0.13, 0.77, 0.37, 0.95);
                    toastIcon.text = "✓";
                    toastIcon.color = "#fff";
                } else if (type === "error") {
                    toastBg.color = Qt.rgba(0.94, 0.27, 0.27, 0.95);
                    toastIcon.text = "✕";
                    toastIcon.color = "#fff";
                } else {
                    toastBg.color = Qt.rgba(0.23, 0.51, 0.96, 0.95);
                    toastIcon.text = "ℹ";
                    toastIcon.color = "#fff";
                }
                toastContainer.opacity = 1.0;
                toastContainer.y = 20;
                toastTimer.restart();
            }

            Item {
                id: toastContainer
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(-60 * root.sf); z: 99999
                width: toastRow.width + Math.round(32 * root.sf); height: Math.round(44 * root.sf)
                opacity: 0.0

                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: toastBg
                    anchors.fill: parent; radius: Math.round(12 * root.sf)
                    color: Qt.rgba(0.13, 0.77, 0.37, 0.95)

                    Row {
                        id: toastRow
                        anchors.centerIn: parent; spacing: Math.round(8 * root.sf)
                        Text { id: toastIcon; text: "✓"; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.Bold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                        Text { id: toastText; text: ""; font.pixelSize: Math.round(13 * root.sf); font.weight: Font.DemiBold; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Timer {
                    id: toastTimer; interval: 3000
                    onTriggered: { toastContainer.opacity = 0.0; toastContainer.y = Math.round(-60 * root.sf); }
                }
            }
        }
    }

    // ── XDG Shell — handles native app window surfaces ──
    XdgShell {
        onToplevelCreated: function(toplevel, xdgSurface) {
            console.log("WhaleOS Compositor: XDG surface — title:" + toplevel.title + " appId:" + toplevel.appId);
            root.assignSurface(toplevel, xdgSurface);
        }
    }

    // ── WlShell — fallback for older/simpler clients ──
    WlShell {
        onWlShellSurfaceCreated: function(shellSurface) {
            console.log("WhaleOS Compositor: WlShell surface — title:" + shellSurface.title + " className:" + shellSurface.className);
            root.assignSurface(shellSurface, shellSurface);
        }
    }

}
