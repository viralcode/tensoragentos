import QtQuick
import QtQuick.Layouts

Rectangle {
    id: terminalApp
    anchors.fill: parent
    color: "#0a0a0a"

    property var outputLines: []
    property bool isRunning: false
    property string currentCwd: "/home/ainux"
    property var cmdHistory: []
    property int historyIndex: -1
    property string savedInput: ""

    Component.onCompleted: {
        appendLine("TensorAgent OS — Terminal");
        appendLine("System shell access. Type commands and press Enter.");
        appendLine("Type 'help' for available shortcuts.");
        appendLine("");
        cmdInput.forceActiveFocus();
    }

    function getPrompt() {
        var dir = currentCwd;
        dir = dir.replace("/home/ainux", "~");
        return "ainux@tensoragent:" + dir + "$ ";
    }

    function appendLine(text) {
        var lines = outputLines.slice();
        lines.push(text);
        if (lines.length > 1000) lines = lines.slice(lines.length - 800);
        outputLines = lines;
    }

    function appendLines(text) {
        if (!text) return;
        var parts = text.split("\n");
        if (parts.length > 0 && parts[parts.length - 1] === "") parts.pop();
        for (var i = 0; i < parts.length; i++) {
            appendLine(parts[i]);
        }
    }

    // Click anywhere to focus input
    MouseArea {
        anchors.fill: parent
        onClicked: cmdInput.forceActiveFocus()
    }

    Flickable {
        id: termFlick
        anchors.fill: parent
        anchors.margins: Math.round(10 * root.sf)
        contentHeight: termCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: true

        Column {
            id: termCol
            width: parent.width
            spacing: 0

            // ── Output Lines ──
            Repeater {
                model: outputLines
                Text {
                    width: termCol.width
                    text: modelData
                    color: {
                        if (modelData.indexOf("ainux@tensoragent:") === 0) return "#60a5fa";
                        if (modelData.indexOf("Error:") === 0 || modelData.indexOf("bash:") === 0) return "#ef4444";
                        if (modelData.indexOf("Permission denied") >= 0) return "#ef4444";
                        if (modelData.indexOf("command not found") >= 0) return "#f59e0b";
                        return "#d4d4d8";
                    }
                    font.pixelSize: Math.round(13 * root.sf)
                    font.family: "monospace"
                    wrapMode: Text.WrapAnywhere
                    height: implicitHeight + 2
                }
            }

            // ── Inline Prompt + Input ──
            Row {
                visible: !isRunning
                width: termCol.width
                spacing: 0

                Text {
                    id: promptText
                    text: getPrompt()
                    color: "#60a5fa"
                    font.pixelSize: Math.round(13 * root.sf)
                    font.family: "monospace"
                    height: implicitHeight + 2
                }

                TextInput {
                    id: cmdInput
                    width: termCol.width - promptText.width
                    color: "#d4d4d8"
                    selectionColor: "#3b82f6"
                    selectedTextColor: "#ffffff"
                    font.pixelSize: Math.round(13 * root.sf)
                    font.family: "monospace"
                    focus: true
                    activeFocusOnTab: true
                    height: promptText.height

                    // Blinking cursor
                    cursorVisible: true
                    cursorDelegate: Rectangle {
                        width: 8
                        height: Math.round(15 * root.sf)
                        color: "#d4d4d8"
                        visible: cmdInput.activeFocus

                        SequentialAnimation on opacity {
                            running: cmdInput.activeFocus
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 530 }
                            NumberAnimation { to: 1; duration: 530 }
                        }
                    }

                    Keys.onReturnPressed: executeCommand()
                    Keys.onUpPressed: navigateHistory(-1)
                    Keys.onDownPressed: navigateHistory(1)

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                            if (isRunning) {
                                isRunning = false;
                                appendLine("^C");
                            } else {
                                appendLine(getPrompt() + cmdInput.text + "^C");
                                cmdInput.text = "";
                            }
                            event.accepted = true;
                        }
                        if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                            outputLines = [];
                            event.accepted = true;
                        }
                    }
                }
            }

            // ── Busy line while command runs ──
            Row {
                visible: isRunning
                width: termCol.width
                spacing: 0

                Text {
                    text: getPrompt()
                    color: "#60a5fa"
                    font.pixelSize: Math.round(13 * root.sf)
                    font.family: "monospace"
                }

                Text {
                    text: "..."
                    color: "#f59e0b"
                    font.pixelSize: Math.round(13 * root.sf)
                    font.family: "monospace"

                    SequentialAnimation on opacity {
                        running: isRunning
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
            }
        }

        onContentHeightChanged: {
            Qt.callLater(function() {
                termFlick.contentY = Math.max(0, termFlick.contentHeight - termFlick.height);
            });
        }
    }

    function navigateHistory(direction) {
        if (cmdHistory.length === 0) return;
        if (historyIndex === -1 && direction === -1) {
            savedInput = cmdInput.text;
            historyIndex = cmdHistory.length - 1;
        } else if (direction === -1) {
            historyIndex = Math.max(0, historyIndex - 1);
        } else if (direction === 1) {
            historyIndex = historyIndex + 1;
            if (historyIndex >= cmdHistory.length) {
                historyIndex = -1;
                cmdInput.text = savedInput;
                return;
            }
        }
        if (historyIndex >= 0 && historyIndex < cmdHistory.length) {
            cmdInput.text = cmdHistory[historyIndex];
            cmdInput.cursorPosition = cmdInput.text.length;
        }
    }

    function executeCommand() {
        var cmd = cmdInput.text.trim();
        cmdInput.text = "";
        historyIndex = -1;

        appendLine(getPrompt() + cmd);

        if (!cmd) return;

        if (cmdHistory.length === 0 || cmdHistory[cmdHistory.length - 1] !== cmd) {
            var hist = cmdHistory.slice();
            hist.push(cmd);
            if (hist.length > 100) hist = hist.slice(hist.length - 100);
            cmdHistory = hist;
        }

        if (cmd === "clear") { outputLines = []; return; }
        if (cmd === "exit") { appendLine("Use the close button to close the terminal."); return; }

        // OpenWhale convenience commands
        if (cmd === "ow-restart" || cmd === "openwhale-restart") {
            cmd = "sudo systemctl restart openwhale.service && echo 'OpenWhale restarted successfully'";
        } else if (cmd === "ow-status" || cmd === "openwhale-status") {
            cmd = "systemctl status openwhale.service --no-pager -l 2>&1";
        } else if (cmd === "ow-logs" || cmd === "openwhale-logs") {
            cmd = "sudo journalctl -u openwhale.service -n 40 --no-pager 2>&1";
        } else if (cmd === "gui-restart") {
            cmd = "sudo systemctl restart ainux-gui.service && echo 'GUI restarted'";
        } else if (cmd === "gui-status") {
            cmd = "systemctl status ainux-gui.service --no-pager -l 2>&1";
        } else if (cmd === "help") {
            appendLine("");
            appendLine("TensorAgent OS Terminal - Available shortcuts:");
            appendLine("  ow-restart     Restart OpenWhale service");
            appendLine("  ow-status      OpenWhale service status");
            appendLine("  ow-logs        OpenWhale recent logs");
            appendLine("  gui-restart    Restart the GUI service");
            appendLine("  gui-status     GUI service status");
            appendLine("  clear          Clear terminal");
            appendLine("  Ctrl+L         Clear terminal");
            appendLine("  Ctrl+C         Cancel / interrupt");
            appendLine("  help           Show this help");
            appendLine("");
            appendLine("All standard Linux commands are available (ls, cat, grep, apt, etc.)");
            appendLine("");
            return;
        }

        isRunning = true;

        // Use sysManager.runCommand() — runs via QProcess/bash on the real system
        var resultStr = sysManager.runCommand(cmd, currentCwd);
        isRunning = false;

        try {
            var data = JSON.parse(resultStr);
            if (data.cwd) currentCwd = data.cwd;
            if (data.stdout) appendLines(data.stdout);
            if (data.stderr) {
                var errParts = data.stderr.split("\n");
                for (var i = 0; i < errParts.length; i++) {
                    if (errParts[i]) appendLine(errParts[i]);
                }
            }
        } catch(e) {
            appendLine("Error: " + (resultStr || "Unknown error"));
        }

        cmdInput.forceActiveFocus();
    }
}
