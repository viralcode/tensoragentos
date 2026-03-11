/*
 * TerminalApp.qml — Real Linux Terminal with PTY + VT100 Emulation
 *
 * Full interactive terminal with:
 *   • Real PTY (pseudo-terminal) — nano, vi, vim, emacs all work
 *   • VT100/xterm ANSI escape sequence parsing
 *   • 256-color + true-color support
 *   • Canvas-based character grid rendering
 *   • Scrollback buffer with mouse wheel scrolling
 *   • Full keyboard input (arrow keys, function keys, etc.)
 *   • Alternate screen buffer (for TUI apps)
 *   • Resize support (SIGWINCH)
 *   • Tab completion and all bash features
 */

import QtQuick
import QtQuick.Layouts
import TensorAgent.Terminal 1.0

Rectangle {
    id: terminalApp
    anchors.fill: parent
    color: "#0d1117"

    // ════════════════════════════════════════════════
    // ── Color Palette (matches xterm-256color)
    // ════════════════════════════════════════════════

    // Standard 16 ANSI colors (0-15)
    readonly property var ansiColors: [
        "#000000", "#cd3131", "#0dbc79", "#e5e510",  // 0-3:  black, red, green, yellow
        "#2472c8", "#bc3fbc", "#11a8cd", "#e5e5e5",  // 4-7:  blue, magenta, cyan, white
        "#666666", "#f14c4c", "#23d18b", "#f5f543",  // 8-11: bright black, red, green, yellow
        "#3b8eea", "#d670d6", "#29b8db", "#ffffff"   // 12-15: bright blue, magenta, cyan, white
    ]

    // Convert 256-color index to hex color
    function colorFromIndex(idx) {
        if (idx < 16) return ansiColors[idx];
        if (idx < 232) {
            // 6x6x6 color cube (indices 16-231)
            var i = idx - 16;
            var r = Math.floor(i / 36);
            var g = Math.floor((i % 36) / 6);
            var b = i % 6;
            r = r > 0 ? 55 + r * 40 : 0;
            g = g > 0 ? 55 + g * 40 : 0;
            b = b > 0 ? 55 + b * 40 : 0;
            return "#" + hex2(r) + hex2(g) + hex2(b);
        }
        // Grayscale ramp (indices 232-255)
        var v = 8 + (idx - 232) * 10;
        return "#" + hex2(v) + hex2(v) + hex2(v);
    }

    function hex2(n) {
        var h = Math.floor(n).toString(16);
        return h.length < 2 ? "0" + h : h;
    }

    // ════════════════════════════════════════════════
    // ── Terminal Geometry
    // ════════════════════════════════════════════════

    property int cellWidth: 0
    property int cellHeight: 0
    property int termRows: 24
    property int termCols: 80
    property int scrollOffset: 0    // How many lines scrolled back (0 = at bottom)
    property bool autoScroll: true  // Auto-scroll to bottom on new output

    // Calculate terminal dimensions based on available space
    function calcGeometry() {
        // Use a monospace font metric to determine cell size
        var testSize = Math.round(14 * root.sf);
        // Approximate: monospace char width ~= 0.6 × height
        cellHeight = testSize + Math.round(4 * root.sf);
        cellWidth = Math.round(testSize * 0.602);

        var availW = terminalApp.width - Math.round(16 * root.sf);
        var availH = terminalApp.height - Math.round(8 * root.sf);

        var newCols = Math.max(20, Math.floor(availW / cellWidth));
        var newRows = Math.max(5, Math.floor(availH / cellHeight));

        if (newCols !== termCols || newRows !== termRows) {
            termCols = newCols;
            termRows = newRows;
            return true;
        }
        return false;
    }

    // ════════════════════════════════════════════════
    // ── PTY Process + Terminal Emulator (C++ backends)
    // ════════════════════════════════════════════════

    PtyProcess {
        id: pty

        onDataReceived: function(data) {
            emulator.processData(data);
            if (autoScroll) scrollOffset = 0;
        }

        onFinished: function(exitCode) {
            // Shell exited — restart it
            console.log("Terminal: Shell exited with code", exitCode, "— restarting");
            restartTimer.start();
        }
    }

    TerminalEmulator {
        id: emulator

        onScreenChanged: {
            termCanvas.requestPaint();
            cursorBlink.restart();
            cursorVisible = true;
        }

        onTitleChanged: function(title) {
            // Could update window title if needed
            console.log("Terminal title:", title);
        }

        onBellRang: {
            // Visual bell — brief flash
            bellFlash.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 500
        onTriggered: startTerminal()
    }

    // ════════════════════════════════════════════════
    // ── Initialization
    // ════════════════════════════════════════════════

    Component.onCompleted: {
        calcGeometry();
        startTerminal();
    }

    function startTerminal() {
        emulator.init(termRows, termCols);
        pty.start(termRows, termCols);
        termCanvas.forceActiveFocus();
    }

    Component.onDestruction: {
        pty.stop();
    }

    onWidthChanged: handleResize()
    onHeightChanged: handleResize()

    Timer {
        id: resizeTimer
        interval: 100
        onTriggered: doResize()
    }

    function handleResize() {
        resizeTimer.restart();
    }

    function doResize() {
        if (calcGeometry()) {
            emulator.resize(termRows, termCols);
            pty.resize(termRows, termCols);
            termCanvas.requestPaint();
        }
    }

    // ════════════════════════════════════════════════
    // ── Cursor Blink
    // ════════════════════════════════════════════════

    property bool cursorVisible: true

    Timer {
        id: cursorBlink
        interval: 530
        running: termCanvas.activeFocus
        repeat: true
        onTriggered: {
            cursorVisible = !cursorVisible;
            termCanvas.requestPaint();
        }
    }

    // ════════════════════════════════════════════════
    // ── Visual Bell Flash
    // ════════════════════════════════════════════════

    Rectangle {
        id: bellOverlay
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
        z: 10

        SequentialAnimation {
            id: bellFlash
            NumberAnimation { target: bellOverlay; property: "opacity"; to: 0.15; duration: 50 }
            NumberAnimation { target: bellOverlay; property: "opacity"; to: 0; duration: 100 }
        }
    }

    // ════════════════════════════════════════════════
    // ── Canvas-based Terminal Renderer
    // ════════════════════════════════════════════════

    Canvas {
        id: termCanvas
        anchors.fill: parent
        anchors.margins: Math.round(4 * root.sf)
        focus: true
        antialiasing: false

        property real fontSize: Math.round(14 * root.sf)

        // Click to focus
        MouseArea {
            anchors.fill: parent
            onClicked: termCanvas.forceActiveFocus()
            onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0) {
                    // Scroll up (into scrollback)
                    scrollOffset = Math.min(scrollOffset + 3, emulator.scrollbackSize());
                    autoScroll = false;
                } else {
                    // Scroll down (toward current)
                    scrollOffset = Math.max(0, scrollOffset - 3);
                    if (scrollOffset === 0) autoScroll = true;
                }
                termCanvas.requestPaint();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            var w = termCanvas.width;
            var h = termCanvas.height;

            // Clear background
            ctx.fillStyle = "#0d1117";
            ctx.fillRect(0, 0, w, h);

            if (cellWidth <= 0 || cellHeight <= 0) return;

            var fontStr = fontSize + "px monospace";
            ctx.font = fontStr;
            ctx.textBaseline = "top";

            var lines = emulator.getScreenLines();
            var cRow = emulator.cursorRow;
            var cCol = emulator.cursorCol;
            var showCursor = cursorVisible && emulator.cursorVisible && scrollOffset === 0;

            // Render each row
            for (var r = 0; r < termRows && r < lines.length; r++) {
                var y = r * cellHeight;
                var attrsStr = emulator.getRowAttrs(r);
                var line = lines[r];

                // Parse attribute segments for this row
                var attrs = attrsStr.split(";");

                for (var c = 0; c < termCols; c++) {
                    var x = c * cellWidth;
                    var ch = c < line.length ? line[c] : " ";

                    // Parse cell attributes
                    var fgColor = "#d4d4d8";  // Default FG
                    var bgColor = "";          // Default BG (transparent)
                    var isBold = false;
                    var isDim = false;
                    var isUnderline = false;
                    var isInverse = false;
                    var isItalic = false;

                    if (c < attrs.length && attrs[c]) {
                        var parts = attrs[c].split(",");
                        if (parts.length >= 2) {
                            // Parse FG
                            var fgPart = parts[0];
                            if (fgPart !== "-" && fgPart !== "") {
                                if (fgPart.startsWith("r")) {
                                    // RGB: r128,255,0
                                    var rgbParts = fgPart.substring(1).split(",");
                                    // Wait — actually the RGB values after 'r' are part of the same comma-split
                                    // Re-parse: if fgPart starts with 'r', the next 2 parts are G and B
                                    // and the bg starts at parts[3]
                                    if (parts.length >= 4) {
                                        var rr = parseInt(fgPart.substring(1));
                                        var gg = parseInt(parts[1]);
                                        var bb = parseInt(parts[2]);
                                        fgColor = "rgb(" + rr + "," + gg + "," + bb + ")";
                                        // Shift parts for BG parsing
                                        var bgPart = parts[3];
                                        if (bgPart && bgPart !== "-" && bgPart !== "") {
                                            if (bgPart.startsWith("r") && parts.length >= 7) {
                                                var br = parseInt(bgPart.substring(1));
                                                var bgg = parseInt(parts[4]);
                                                var bbb = parseInt(parts[5]);
                                                bgColor = "rgb(" + br + "," + bgg + "," + bbb + ")";
                                                if (parts.length >= 8) {
                                                    var attrBits = parseInt(parts[7]);
                                                    parseAttrBits(attrBits);
                                                }
                                            } else {
                                                bgColor = colorFromIndex(parseInt(bgPart));
                                                if (parts.length >= 5) {
                                                    var attrBits2 = parseInt(parts[4]);
                                                    parseAttrBits(attrBits2);
                                                }
                                            }
                                        } else if (parts.length >= 5) {
                                            var attrBits3 = parseInt(parts[4]);
                                            parseAttrBits(attrBits3);
                                        }
                                        // Skip the complex parsing below
                                        applyRendering();
                                        continue;
                                    }
                                } else {
                                    fgColor = colorFromIndex(parseInt(fgPart));
                                }
                            }

                            // Parse BG
                            if (parts.length >= 2) {
                                var bgP = parts[1];
                                if (bgP && bgP !== "-" && bgP !== "") {
                                    if (bgP.startsWith("r") && parts.length >= 4) {
                                        var br2 = parseInt(bgP.substring(1));
                                        var bg2 = parseInt(parts[2]);
                                        var bb2 = parseInt(parts[3]);
                                        bgColor = "rgb(" + br2 + "," + bg2 + "," + bb2 + ")";
                                        if (parts.length >= 5) {
                                            parseAttrBits(parseInt(parts[4]));
                                        }
                                    } else {
                                        bgColor = colorFromIndex(parseInt(bgP));
                                    }
                                }
                            }

                            // Parse attribute bitmask
                            var attrIdx = 2;
                            if (parts.length > attrIdx) {
                                var ab = parseInt(parts[attrIdx]);
                                if (!isNaN(ab)) {
                                    parseAttrBits(ab);
                                }
                            }
                        }
                    }

                    function parseAttrBits(bits) {
                        if (isNaN(bits)) return;
                        isBold = (bits & 1) !== 0;
                        isDim = (bits & 2) !== 0;
                        isUnderline = (bits & 4) !== 0;
                        isInverse = (bits & 8) !== 0;
                        isItalic = (bits & 16) !== 0;
                    }

                    function applyRendering() {
                        renderCell(ctx, x, y, ch, fgColor, bgColor,
                                   isBold, isDim, isUnderline, isInverse, isItalic,
                                   r, c, cRow, cCol, showCursor);
                    }

                    // Handle inverse
                    if (isInverse) {
                        var tmp = fgColor;
                        fgColor = bgColor || "#0d1117";
                        bgColor = tmp;
                    }

                    // Handle dim
                    if (isDim) {
                        fgColor = dimColor(fgColor);
                    }

                    // Draw background
                    if (bgColor) {
                        ctx.fillStyle = bgColor;
                        ctx.fillRect(x, y, cellWidth, cellHeight);
                    }

                    // Draw cursor
                    if (showCursor && r === cRow && c === cCol) {
                        ctx.fillStyle = "#60a5fa";
                        ctx.fillRect(x, y, cellWidth, cellHeight);
                        fgColor = "#0d1117";  // Dark text on cursor
                    }

                    // Draw character
                    if (ch !== " ") {
                        var font = "";
                        if (isItalic) font += "italic ";
                        if (isBold) font += "bold ";
                        font += fontSize + "px monospace";
                        ctx.font = font;
                        ctx.fillStyle = fgColor;
                        ctx.fillText(ch, x, y + Math.round(2 * root.sf));

                        // Reset font if we changed it
                        if (isBold || isItalic) {
                            ctx.font = fontStr;
                        }
                    }

                    // Draw underline
                    if (isUnderline) {
                        ctx.strokeStyle = fgColor;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(x, y + cellHeight - 1);
                        ctx.lineTo(x + cellWidth, y + cellHeight - 1);
                        ctx.stroke();
                    }
                }
            }

            // Draw scrollback indicator
            if (scrollOffset > 0) {
                ctx.fillStyle = "rgba(96, 165, 250, 0.8)";
                ctx.font = "bold " + Math.round(11 * root.sf) + "px monospace";
                var scrollText = "↑ " + scrollOffset + " lines scrolled";
                ctx.fillText(scrollText, Math.round(8 * root.sf), Math.round(4 * root.sf));
            }
        }

        function renderCell(ctx, x, y, ch, fg, bg, bold, dim, underline, inverse, italic, r, c, cRow, cCol, showCursor) {
            if (inverse) {
                var tmp = fg;
                fg = bg || "#0d1117";
                bg = tmp;
            }
            if (dim) fg = dimColor(fg);
            if (bg) {
                ctx.fillStyle = bg;
                ctx.fillRect(x, y, cellWidth, cellHeight);
            }
            if (showCursor && r === cRow && c === cCol) {
                ctx.fillStyle = "#60a5fa";
                ctx.fillRect(x, y, cellWidth, cellHeight);
                fg = "#0d1117";
            }
            if (ch !== " ") {
                var font = "";
                if (italic) font += "italic ";
                if (bold) font += "bold ";
                font += fontSize + "px monospace";
                ctx.font = font;
                ctx.fillStyle = fg;
                ctx.fillText(ch, x, y + Math.round(2 * root.sf));
            }
            if (underline) {
                ctx.strokeStyle = fg;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(x, y + cellHeight - 1);
                ctx.lineTo(x + cellWidth, y + cellHeight - 1);
                ctx.stroke();
            }
        }

        // ════════════════════════════════════════════════
        // ── Keyboard Input Handler
        // ════════════════════════════════════════════════

        Keys.onPressed: function(event) {
            // Auto-scroll on keypress
            scrollOffset = 0;
            autoScroll = true;

            var seq = "";

            // Modifier keys only — don't send
            if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control ||
                event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                return;
            }

            var ctrl = (event.modifiers & Qt.ControlModifier);
            var alt = (event.modifiers & Qt.AltModifier);
            var shift = (event.modifiers & Qt.ShiftModifier);

            // Ctrl+key sequences
            if (ctrl && !alt) {
                // Don't intercept Ctrl+Shift+C/V for copy/paste
                if ((event.key === Qt.Key_C || event.key === Qt.Key_V) && shift) {
                    return;  // Let the system handle Ctrl+Shift+C/V
                }

                // Standard Ctrl sequences
                var ctrlKeys = {};
                ctrlKeys[Qt.Key_A] = "\x01";
                ctrlKeys[Qt.Key_B] = "\x02";
                ctrlKeys[Qt.Key_C] = "\x03";
                ctrlKeys[Qt.Key_D] = "\x04";
                ctrlKeys[Qt.Key_E] = "\x05";
                ctrlKeys[Qt.Key_F] = "\x06";
                ctrlKeys[Qt.Key_G] = "\x07";
                ctrlKeys[Qt.Key_H] = "\x08";
                ctrlKeys[Qt.Key_I] = "\x09";
                ctrlKeys[Qt.Key_J] = "\x0a";
                ctrlKeys[Qt.Key_K] = "\x0b";
                ctrlKeys[Qt.Key_L] = "\x0c";
                ctrlKeys[Qt.Key_M] = "\x0d";
                ctrlKeys[Qt.Key_N] = "\x0e";
                ctrlKeys[Qt.Key_O] = "\x0f";
                ctrlKeys[Qt.Key_P] = "\x10";
                ctrlKeys[Qt.Key_Q] = "\x11";
                ctrlKeys[Qt.Key_R] = "\x12";
                ctrlKeys[Qt.Key_S] = "\x13";
                ctrlKeys[Qt.Key_T] = "\x14";
                ctrlKeys[Qt.Key_U] = "\x15";
                ctrlKeys[Qt.Key_V] = "\x16";
                ctrlKeys[Qt.Key_W] = "\x17";
                ctrlKeys[Qt.Key_X] = "\x18";
                ctrlKeys[Qt.Key_Y] = "\x19";
                ctrlKeys[Qt.Key_Z] = "\x1a";

                if (event.key in ctrlKeys) {
                    seq = ctrlKeys[event.key];
                }
                else if (event.key === Qt.Key_BracketLeft) seq = "\x1b";
                else if (event.key === Qt.Key_Backslash) seq = "\x1c";
                else if (event.key === Qt.Key_BracketRight) seq = "\x1d";
                else if (event.key === Qt.Key_AsciiCircum || event.key === Qt.Key_6) seq = "\x1e";
                else if (event.key === Qt.Key_Slash) seq = "\x1f";

                if (seq) {
                    pty.write(seq);
                    event.accepted = true;
                    return;
                }
            }

            // Special keys — send VT/xterm escape sequences
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                seq = "\r";
                break;
            case Qt.Key_Backspace:
                seq = "\x7f";
                break;
            case Qt.Key_Tab:
                seq = "\t";
                break;
            case Qt.Key_Escape:
                seq = "\x1b";
                break;
            case Qt.Key_Up:
                seq = "\x1b[A";
                break;
            case Qt.Key_Down:
                seq = "\x1b[B";
                break;
            case Qt.Key_Right:
                seq = "\x1b[C";
                break;
            case Qt.Key_Left:
                seq = "\x1b[D";
                break;
            case Qt.Key_Home:
                seq = "\x1b[H";
                break;
            case Qt.Key_End:
                seq = "\x1b[F";
                break;
            case Qt.Key_PageUp:
                seq = "\x1b[5~";
                break;
            case Qt.Key_PageDown:
                seq = "\x1b[6~";
                break;
            case Qt.Key_Insert:
                seq = "\x1b[2~";
                break;
            case Qt.Key_Delete:
                seq = "\x1b[3~";
                break;
            case Qt.Key_F1:
                seq = "\x1bOP";
                break;
            case Qt.Key_F2:
                seq = "\x1bOQ";
                break;
            case Qt.Key_F3:
                seq = "\x1bOR";
                break;
            case Qt.Key_F4:
                seq = "\x1bOS";
                break;
            case Qt.Key_F5:
                seq = "\x1b[15~";
                break;
            case Qt.Key_F6:
                seq = "\x1b[17~";
                break;
            case Qt.Key_F7:
                seq = "\x1b[18~";
                break;
            case Qt.Key_F8:
                seq = "\x1b[19~";
                break;
            case Qt.Key_F9:
                seq = "\x1b[20~";
                break;
            case Qt.Key_F10:
                seq = "\x1b[21~";
                break;
            case Qt.Key_F11:
                seq = "\x1b[23~";
                break;
            case Qt.Key_F12:
                seq = "\x1b[24~";
                break;
            default:
                if (event.text) {
                    seq = event.text;
                }
                break;
            }

            if (seq) {
                // Alt modifier wraps in ESC prefix
                if (alt && seq.length > 0) {
                    seq = "\x1b" + seq;
                }
                pty.write(seq);
                event.accepted = true;
            }
        }
    }

    // ════════════════════════════════════════════════
    // ── Helpers
    // ════════════════════════════════════════════════

    function dimColor(color) {
        // Make a color dimmer by reducing opacity
        // Simple approach: return with reduced value
        if (color.startsWith("rgb(")) return color;
        if (color.startsWith("#") && color.length === 7) {
            var r = parseInt(color.substr(1, 2), 16);
            var g = parseInt(color.substr(3, 2), 16);
            var b = parseInt(color.substr(5, 2), 16);
            r = Math.floor(r * 0.6);
            g = Math.floor(g * 0.6);
            b = Math.floor(b * 0.6);
            return "#" + hex2(r) + hex2(g) + hex2(b);
        }
        return color;
    }
}
