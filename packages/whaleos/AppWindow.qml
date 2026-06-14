import QtQuick
import QtQuick.Layouts
import QtWayland.Compositor

Rectangle {
    id: appWindow
    x: initialX
    y: initialY

    readonly property bool isDialog: toplevelObj !== null && toplevelObj.parentToplevel !== null
    property real defaultWidth: Math.round(700 * root.sf)
    property real defaultHeight: Math.round(450 * root.sf)
    property bool centeredOnce: false

    // width/height set once in Component.onCompleted — NOT live-bound to windowArea
    // so chat panel expanding/collapsing never resizes open windows. For dialogs, wrap content.
    width: isDialog ? (surfaceItem.width > 0 ? surfaceItem.width : Math.round(400 * root.sf)) : defaultWidth
    height: isDialog ? (surfaceItem.height > 0 ? surfaceItem.height : Math.round(250 * root.sf)) : defaultHeight

    onWidthChanged: centerDialog()
    onHeightChanged: centerDialog()

    radius: root.radiusLg
    color: isDialog ? "transparent" : Qt.rgba(1, 1, 1, 0.92)
    border.color: isDialog ? "transparent" : Qt.rgba(0, 0, 0, 0.08)
    border.width: 1
    clip: true
    z: 10

    property string windowTitle: "App"
    property string windowIcon: ""
    property string appId: ""
    property Item windowArea: parent
    property int initialX: 100
    property int initialY: Math.round(80 * root.sf)

    // Maximize state
    property bool maximized: false
    property real savedX: 0
    property real savedY: 0
    property real savedW: 0
    property real savedH: 0

    function toggleMaximize() {
        if (maximized) {
            appWindow.x = savedX; appWindow.y = savedY;
            appWindow.width = savedW; appWindow.height = savedH;
            maximized = false;
        } else {
            savedX = appWindow.x; savedY = appWindow.y;
            savedW = appWindow.width; savedH = appWindow.height;
            // Position at windowArea origin (accounts for top bar)
            if (windowArea) {
                appWindow.x = windowArea.x;
                appWindow.y = windowArea.y;
                appWindow.width = windowArea.width;
                appWindow.height = windowArea.height;
            }
            maximized = true;
        }
    }

    // Native app properties
    property bool isNative: appId.indexOf("native-") === 0 || appId.indexOf("wayland-") === 0
    property string nativeCmd: ""
    property string nativeSearchName: ""
    property int launchCountdown: 60

    // Set initial size + launch native app in one onCompleted handler
    // (QML only allows ONE Component.onCompleted per component)
    Component.onCompleted: {
        console.log("WhaleOS AppWindow completed loading. appId:", appId, "title:", windowTitle, "visible:", visible, "x:", x, "y:", y, "width:", width, "height:", height);
        if (windowArea) {
            // Native apps get a larger window
            var initW = isNative ? Math.round(900 * root.sf) : Math.round(700 * root.sf);
            var initH = isNative ? Math.round(600 * root.sf) : Math.round(450 * root.sf);
            var wAreaW = windowArea.width > 0 ? windowArea.width : root.width;
            var wAreaH = windowArea.height > 0 ? windowArea.height : (root.height - Math.round(44 * root.sf));
            defaultWidth  = Math.min(initW, wAreaW  - Math.round(20 * root.sf));
            defaultHeight = Math.min(initH, wAreaH - Math.round(20 * root.sf));
        }
    }

    function centerDialog() {
        if (!isDialog || centeredOnce || !surfaceItem || surfaceItem.width <= 0 || surfaceItem.height <= 0) return;
        var parentWinItem = findParentWindowItem();
        if (parentWinItem) {
            appWindow.x = parentWinItem.x + (parentWinItem.width - appWindow.width) / 2;
            appWindow.y = parentWinItem.y + (parentWinItem.height - appWindow.height) / 2;
            centeredOnce = true;
            console.log("WhaleOS: Centered dialog over parent window:", parentWinItem.windowTitle, "x:", appWindow.x, "y:", appWindow.y);
        } else if (windowArea && windowArea.width > 0) {
            appWindow.x = windowArea.x + (windowArea.width - appWindow.width) / 2;
            appWindow.y = windowArea.y + (windowArea.height - appWindow.height) / 2;
            centeredOnce = true;
            console.log("WhaleOS: Centered dialog over windowArea (fallback) x:", appWindow.x, "y:", appWindow.y);
        }
    }

    function findParentWindowItem() {
        if (!toplevelObj || !toplevelObj.parentToplevel || !parent) return null;
        for (var i = 0; i < parent.children.length; i++) {
            var child = parent.children[i];
            if (child !== appWindow && child.toplevelObj === toplevelObj.parentToplevel) {
                return child;
            }
        }
        return null;
    }

    property string nativeWinId: ""

    // Wayland surface (assigned by compositor)
    property var shellSurface: null
    property var toplevelObj: null

    function focusNativeSurface() {
        if (!isNative || !shellSurface || !surfaceItem) return;

        root.bringToFront(appWindow);
        if (typeof appWindow.forceActiveFocus === "function") appWindow.forceActiveFocus();
        if (typeof contentArea.forceActiveFocus === "function") contentArea.forceActiveFocus();
        if (typeof surfaceItem.forceActiveFocus === "function") surfaceItem.forceActiveFocus();
        if (typeof surfaceItem.takeFocus === "function") surfaceItem.takeFocus();

        // CRITICAL: Set Wayland-protocol-level keyboard focus.
        // Try multiple routes to get the actual WaylandSurface object:
        //   1. surfaceItem.surface  — ShellSurfaceItem exposes the WaylandSurface
        //   2. shellSurface.surface — XdgSurface.surface property
        //   3. shellSurface itself  — WlShellSurface IS a WaylandSurface
        try {
            var wlSurface = null;
            if (surfaceItem.surface)            wlSurface = surfaceItem.surface;
            if (!wlSurface && shellSurface.surface) wlSurface = shellSurface.surface;
            if (!wlSurface)                     wlSurface = shellSurface;

            if (comp.defaultSeat && wlSurface) {
                comp.defaultSeat.keyboardFocus = wlSurface;
                console.log("WhaleOS: keyboard focus SET for " + appWindow.windowTitle);
            } else {
                console.log("WhaleOS: keyboard focus SKIP — seat:" + !!comp.defaultSeat + " surface:" + !!wlSurface);
            }
        } catch(e) {
            console.log("WhaleOS: keyboard focus ERROR: " + e);
        }
    }

    // When a native surface arrives, configure it to fill the content area
    // (the area below WhaleOS's title bar)
    onShellSurfaceChanged: {
        if (shellSurface && toplevelObj) {
            console.log("WhaleOS Debug for", windowTitle, ": toplevelObj =", toplevelObj, "parentToplevel =", toplevelObj.parentToplevel);
            surfaceConfigureTimer.restart();
        }
        focusNativeSurface();
    }
    onToplevelObjChanged: {
        if (shellSurface && toplevelObj) {
            surfaceConfigureTimer.restart();
        }
        focusNativeSurface();
    }
    Timer {
        id: surfaceConfigureTimer
        interval: 150; repeat: false
        onTriggered: {
            if (toplevelObj && contentArea.width > 0 && contentArea.height > 0) {
                if (isDialog) {
                    // Tell the client dialog to choose its own size (0, 0 geometry suggestion)
                    if (typeof toplevelObj.sendConfigure === "function") {
                        toplevelObj.sendConfigure(Qt.size(0, 0), []);
                    }
                } else {
                    var sz = Qt.size(contentArea.width, contentArea.height);
                    // sendMaximized tells client to fill the given size
                    if (typeof toplevelObj.sendMaximized === "function") {
                        toplevelObj.sendMaximized(sz);
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: -1; radius: parent.radius + 1
        color: "transparent"; border.color: isDialog ? "transparent" : Qt.rgba(0, 0, 0, 0.12); border.width: 1; z: -1
    }

    // ── Title Bar ──
    Rectangle {
        id: titleBar
        visible: !isDialog
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: visible ? Math.round(38 * root.sf) : 0
        color: Qt.rgba(0.96, 0.96, 0.97, 0.98); radius: root.radiusLg

        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.radius; color: parent.color }
        // Subtle bottom border
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1
            color: Qt.rgba(0, 0, 0, 0.06)
        }

        MouseArea {
            id: dragArea; anchors.fill: parent; drag.target: maximized ? null : appWindow
            drag.minimumX: -appWindow.width + Math.round(100 * root.sf); drag.minimumY: 0
            drag.maximumX: windowArea ? windowArea.width - Math.round(100 * root.sf) : 800
            drag.maximumY: windowArea ? windowArea.height - Math.round(40 * root.sf) : 600
            cursorShape: Qt.SizeAllCursor
            onPressed: function(mouse) {
                root.bringToFront(appWindow);
            }
            onDoubleClicked: toggleMaximize()
        }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(12 * root.sf); anchors.rightMargin: Math.round(12 * root.sf); spacing: Math.round(8 * root.sf)

            // ── Traffic Light Buttons (Left) ──
            Row {
                spacing: Math.round(7 * root.sf)
                Layout.alignment: Qt.AlignVCenter

                // Close
                Rectangle {
                    width: Math.round(12 * root.sf); height: Math.round(12 * root.sf); radius: width / 2
                    color: closeHover.containsMouse ? "#ef4444" : "#d1d5db"
                    border.color: closeHover.containsMouse ? "#dc2626" : Qt.rgba(0,0,0,0.08); border.width: 0.5
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: closeWindow() }
                }
                // Maximize
                Rectangle {
                    visible: !isDialog
                    width: Math.round(12 * root.sf); height: Math.round(12 * root.sf); radius: width / 2
                    color: maxHover.containsMouse ? "#22c55e" : "#d1d5db"
                    border.color: maxHover.containsMouse ? "#16a34a" : Qt.rgba(0,0,0,0.08); border.width: 0.5
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { id: maxHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggleMaximize() }
                }
            }

            // ── Title (centered) ──
            Text {
                text: appWindow.windowTitle
                font.pixelSize: Math.round(12.5 * root.sf); font.weight: Font.DemiBold
                color: root.textPrimary; Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            // Spacer to balance traffic lights
            Item { width: Math.round(31 * root.sf) }
        }
    }


    // ── Body ──
    Item {
        id: contentArea
        clip: true  // Prevent native app surface from overflowing
        anchors.top: isDialog ? parent.top : titleBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom

        // Re-send configure when window is resized so native app fills properly
        onWidthChanged: if (isNative && toplevelObj) surfaceConfigureTimer.restart()
        onHeightChanged: if (isNative && toplevelObj) surfaceConfigureTimer.restart()

        // NOTE: No overlay MouseArea here! For native apps, the ShellSurfaceItem
        // must be the direct recipient of all input events (mouse + keyboard).
        // An overlay MouseArea would intercept events before they reach the
        // Wayland client, breaking keyboard and click-to-focus.

        Loader {
            anchors.fill: parent
            visible: !isNative
            source: {
                if (isNative) return "";
                if (appId === "nativeapps") return "NativeAppsLauncher.qml";
                if (appId === "settings") return "SettingsApp.qml";
                if (appId === "providers") return "ProvidersApp.qml";
                if (appId === "skills") return "SkillsApp.qml";
                if (appId === "extensions") return "AppsApp.qml";
                if (appId === "terminal") return "TerminalApp.qml";
                if (appId === "mcp") return "McpApp.qml";
                if (appId === "agents") return "AgentsApp.qml";
                if (appId === "files") return "FileManagerApp.qml";
                return "";
            }
        }

        // Embedded Wayland surface (rendered by compositor)
        ShellSurfaceItem {
            id: surfaceItem
            anchors.fill: isDialog ? undefined : parent
            visible: shellSurface !== null
            shellSurface: appWindow.shellSurface
            autoCreatePopupItems: true
            focusOnClick: true  // Give Qt focus when clicked, so wl_keyboard events flow

            // When this item gets Qt focus (user clicked), set wl_keyboard focus
            // on the Wayland seat so key events are forwarded to the client.
            onActiveFocusChanged: {
                if (activeFocus && isNative && shellSurface !== null && comp.defaultSeat) {
                    var surf = shellSurface.surface || shellSurface;
                    if (surf) comp.defaultSeat.keyboardFocus = surf;
                }
            }

            onSurfaceDestroyed: {
                // Native app closed itself — close the AppWindow too
                closeWindow();
            }
        }
        // NOTE: Right-click blocking is handled at the C++ level in main.cpp
        // via RightClickFilter. QML MouseArea cannot intercept Wayland pointer events.

        // Native app loading indicator (shown until surface arrives or timeout)

        Column {
            anchors.centerIn: parent
            spacing: Math.round(12 * root.sf)
            visible: isNative && shellSurface === null && appWindow.launchCountdown > 0

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * root.sf)
                Repeater {
                    model: 3
                    Rectangle {
                        width: Math.round(8 * root.sf); height: Math.round(8 * root.sf); radius: width / 2; color: root.accentBlue
                        SequentialAnimation on opacity {
                            running: isNative && shellSurface === null; loops: Animation.Infinite
                            PauseAnimation { duration: index * 200 }
                            NumberAnimation { to: 0.2; duration: 400 }
                            NumberAnimation { to: 1.0; duration: 400 }
                            PauseAnimation { duration: (2 - index) * 200 }
                        }
                    }
                }
            }

            Text {
                text: "Launching " + windowTitle + "..."
                font.pixelSize: Math.round(13 * root.sf); color: root.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Auto-close if app doesn't produce a surface in time
        Timer {
            id: launchTimeout
            interval: 1000; running: isNative && shellSurface === null && appWindow.launchCountdown > 0; repeat: true
            onTriggered: {
                appWindow.launchCountdown--;
                if (appWindow.launchCountdown <= 0) {
                    root.showToast(windowTitle + " did not open — it may be a CLI tool", "info");
                    closeWindow();
                }
            }
        }
    }




    function closeWindow() {
        // Hide immediately so user sees it vanish
        appWindow.visible = false;

        // Send close to Wayland surface if applicable
        if (toplevelObj) {
            if (typeof toplevelObj.sendClose === "function") {
                toplevelObj.sendClose();
            } else if (shellSurface) {
                try {
                    var surf = shellSurface.surface || shellSurface;
                    if (surf && surf.client) {
                        surf.client.close();
                    }
                } catch(e) {
                    console.log("WhaleOS: closeWindow fallback error: " + e);
                }
            }
        }

        // Defer openWindows cleanup so the Repeater model isn't mutated
        // while QML is still inside this delegate's execution context
        closeCleanupTimer.start();
    }

    Timer {
        id: closeCleanupTimer
        interval: 50; running: false; repeat: false
        onTriggered: {
            try {
                console.log("WhaleOS: closeCleanupTimer for " + appWindow.appId + " triggered. root: " + (typeof root) + ", parent: " + appWindow.parent);
                var target = null;
                if (typeof root !== "undefined" && typeof root.openWindows !== "undefined") {
                    target = root;
                } else {
                    var p = appWindow.parent;
                    while (p && typeof p.openWindows === "undefined") {
                        p = p.parent;
                    }
                    if (p && typeof p.openWindows !== "undefined") {
                        target = p;
                    }
                }
                console.log("WhaleOS: target: " + (target ? "found" : "null") + ", target.openWindows: " + (target ? typeof target.openWindows : "n/a"));
                if (target && target.openWindows) {
                    var wins = target.openWindows;
                    var newWins = [];
                    for (var i = 0; i < wins.length; i++) {
                        if (wins[i].appId !== appWindow.appId) newWins.push(wins[i]);
                    }
                    console.log("WhaleOS: old wins length: " + wins.length + ", new wins length: " + newWins.length);
                    target.openWindows = newWins;
                }
            } catch(e) {
                console.log("WhaleOS: openWindows cleanup error: " + e);
            }
        }
    }

    // ── Resize Handle ──
    MouseArea {
        visible: !isDialog
        width: Math.round(16 * root.sf); height: Math.round(16 * root.sf)
        anchors.right: parent.right; anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        property point pressPos
        onPressed: function(mouse) { pressPos = Qt.point(mouse.x, mouse.y); root.bringToFront(appWindow); }
        onPositionChanged: function(mouse) {
            var dx = mouse.x - pressPos.x;
            var dy = mouse.y - pressPos.y;
            appWindow.width = Math.max(Math.round(350 * root.sf), appWindow.width + dx);
            appWindow.height = Math.max(Math.round(250 * root.sf), appWindow.height + dy);
        }
    }
}
