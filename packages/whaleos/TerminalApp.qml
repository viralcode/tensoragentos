import QtQuick
import QtQuick.Layouts

Rectangle {
    id: terminalApp
    anchors.fill: parent
    color: "#0a0a0a"

    property var outputLines: []
    property bool isRunning: false
    property string currentCwd: ""
    property var cmdHistory: []
    property int historyIndex: -1
    property string savedInput: ""
    property string activeCommandId: ""

    Component.onCompleted: {
        // Dynamically resolve the user's home directory
        try {
            var result = JSON.parse(sysManager.runCommand("echo $HOME", ""));
            currentCwd = (result.stdout || "").trim() || "/home";
        } catch(e) {
            currentCwd = "/home";
        }
        appendLine("TensorAgent OS — Terminal");
        appendLine("System shell access. Type commands and press Enter.");
        appendLine("Type 'help' for available shortcuts.");
        appendLine("");
        cmdInput.forceActiveFocus();
    }

    // ════════════════════════════════════════════════
    // ── Async Command Signal Handlers
    // ════════════════════════════════════════════════

    Connections {
        target: sysManager

        function onCommandOutput(cmdId, data) {
            if (cmdId !== activeCommandId) return;
            appendLines(data);
        }

        function onCommandError(cmdId, data) {
            if (cmdId !== activeCommandId) return;
            var parts = data.split("\n");
            for (var i = 0; i < parts.length; i++) {
                if (parts[i]) appendLine(parts[i]);
            }
        }

        function onCommandFinished(cmdId, exitCode, cwd) {
            if (cmdId !== activeCommandId) return;
            activeCommandId = "";
            isRunning = false;
            if (cwd) currentCwd = cwd;

            if (exitCode === 124) {
                appendLine("bash: command timed out (use SSH for long-running tasks)");
            }

            cmdInput.forceActiveFocus();
        }
    }

    // ════════════════════════════════════════════════
    // ── Helpers
    // ════════════════════════════════════════════════

    function getPrompt() {
        var dir = currentCwd;
        // Replace home dir with ~ for display
        try {
            var home = JSON.parse(sysManager.runCommand("echo $HOME", "")).stdout.trim();
            if (home && dir.indexOf(home) === 0) {
                dir = "~" + dir.substring(home.length);
            }
        } catch(e) {
            dir = dir.replace(/^\/home\/[^/]+/, "~");
        }
        var user = root.currentUser || "user";
        return user + "@tensoragent:" + dir + "$ ";
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
                        if (modelData.indexOf("@tensoragent:") > 0) return "#60a5fa";
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
                                activeCommandId = "";
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

            // ── Busy indicator while command runs ──
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
                    text: "running..."
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

    // ════════════════════════════════════════════════
    // ── Command History Navigation
    // ════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════
    // ── Interactive Command Detection
    // ════════════════════════════════════════════════

    property var interactiveCommands: ["cat", "less", "more", "head", "tail", "grep", "sort",
                                       "top", "htop", "vim", "vi", "nano", "emacs", "pico",
                                       "python", "python3", "node", "irb", "ruby", "bash", "sh",
                                       "ssh", "ftp", "sftp", "telnet", "nc", "netcat",
                                       "read", "watch", "journalctl", "man", "info"]

    function isInteractiveStdin(cmd) {
        var parts = cmd.trim().split(/\s+/);
        var base = parts[0].split("/").pop();
        if (interactiveCommands.indexOf(base) >= 0) {
            var hasFileArg = false;
            for (var i = 1; i < parts.length; i++) {
                if (!parts[i].startsWith("-") && parts[i] !== "") {
                    hasFileArg = true; break;
                }
            }
            if (cmd.indexOf("-f") >= 0 || cmd.indexOf("--follow") >= 0
                || (cmd.indexOf("--no-pager") < 0 && base === "journalctl")) {
                return !cmd.includes("--no-pager");
            }
            return !hasFileArg;
        }
        return false;
    }

    // ════════════════════════════════════════════════
    // ── Command Execution (Async)
    // ════════════════════════════════════════════════

    function executeCommand() {
        var cmd = cmdInput.text.trim();
        cmdInput.text = "";
        historyIndex = -1;

        appendLine(getPrompt() + cmd);

        if (!cmd) return;

        // Add to history
        if (cmdHistory.length === 0 || cmdHistory[cmdHistory.length - 1] !== cmd) {
            var hist = cmdHistory.slice();
            hist.push(cmd);
            if (hist.length > 100) hist = hist.slice(hist.length - 100);
            cmdHistory = hist;
        }

        // Built-in commands
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
            appendLine("TensorAgent OS Terminal — Available shortcuts:");
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
            appendLine("Note: Interactive/pager commands need arguments (e.g. 'cat file.txt')");
            appendLine("");
            return;
        }

        // ── Stdin-blocking protection ──
        if (isInteractiveStdin(cmd)) {
            var base = cmd.trim().split(/\s+/)[0].split("/").pop();
            appendLine("bash: " + base + ": requires a file argument in this terminal");
            appendLine("Tip: Use '" + base + " <filename>' or pipe input: 'echo text | " + base + "'");
            cmdInput.forceActiveFocus();
            return;
        }

        // ── Handle 'cd' locally (synchronous, instant) ──
        if (cmd.trim().startsWith("cd ") || cmd.trim() === "cd") {
            var cdResult = sysManager.runCommand(cmd + " && pwd", currentCwd);
            try {
                var d = JSON.parse(cdResult);
                if (d.exitCode === 0 && d.stdout) {
                    currentCwd = d.stdout.trim();
                } else if (d.stderr) {
                    appendLine(d.stderr.trim());
                }
            } catch(e) {}
            cmdInput.forceActiveFocus();
            return;
        }

        // ── Async execution: non-blocking, streams output in real-time ──
        isRunning = true;
        var safeCmd = "timeout 30s bash -c " + JSON.stringify(cmd) + " < /dev/null 2>&1";
        activeCommandId = sysManager.runCommandAsync(safeCmd, currentCwd);
    }
}
