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
        appendLine("");
    }

    function getPrompt() {
        var dir = currentCwd;
        dir = dir.replace("/home/ainux", "~");
        return "ainux@tensoragent:" + dir + "$ ";
    }

    function appendLine(text) {
        var lines = outputLines.slice();
        lines.push(text);
        // Keep buffer reasonable
        if (lines.length > 1000) lines = lines.slice(lines.length - 800);
        outputLines = lines;
    }

    function appendLines(text) {
        if (!text) return;
        var parts = text.split("\n");
        // Remove trailing empty line from split
        if (parts.length > 0 && parts[parts.length - 1] === "") parts.pop();
        for (var i = 0; i < parts.length; i++) {
            appendLine(parts[i]);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Terminal Output ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0a"

            MouseArea {
                anchors.fill: parent
                onClicked: cmdInput.forceActiveFocus()
            }

            Flickable {
                id: termFlick
                anchors.fill: parent
                anchors.margins: 10
                contentHeight: termCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: termCol
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: outputLines
                        Text {
                            width: termCol.width
                            text: modelData
                            color: {
                                // Color code different line types
                                if (modelData.indexOf("ainux@tensoragent:") === 0) return "#60a5fa";
                                if (modelData.indexOf("Error:") === 0 || modelData.indexOf("bash:") === 0) return "#ef4444";
                                if (modelData.indexOf("Permission denied") >= 0) return "#ef4444";
                                return "#d4d4d8";
                            }
                            font.pixelSize: 13
                            font.family: "monospace"
                            wrapMode: Text.WrapAnywhere
                            height: implicitHeight + 2
                        }
                    }
                }

                onContentHeightChanged: {
                    Qt.callLater(function() {
                        termFlick.contentY = Math.max(0, termFlick.contentHeight - termFlick.height);
                    });
                }
            }
        }

        // ── Input Bar ──
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#111111"

            Rectangle {
                anchors.top: parent.top
                width: parent.width; height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 0

                // Prompt
                Text {
                    text: getPrompt()
                    font.pixelSize: 13
                    font.family: "monospace"
                    color: "#60a5fa"
                }

                // Input
                TextInput {
                    id: cmdInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#d4d4d8"
                    selectionColor: "#3b82f6"
                    selectedTextColor: "#ffffff"
                    font.pixelSize: 13
                    font.family: "monospace"
                    clip: true
                    focus: true

                    Keys.onReturnPressed: executeCommand()
                    Keys.onUpPressed: navigateHistory(-1)
                    Keys.onDownPressed: navigateHistory(1)

                    Keys.onPressed: function(event) {
                        // Ctrl+C — cancel running command
                        if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                            if (isRunning) {
                                isRunning = false;
                                appendLine("^C");
                                appendLine("");
                            } else {
                                cmdInput.text = "";
                            }
                            event.accepted = true;
                        }
                        // Ctrl+L — clear screen
                        if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                            outputLines = [""];
                            event.accepted = true;
                        }
                    }
                }

                // Busy indicator
                Text {
                    visible: isRunning
                    text: " ..."
                    font.pixelSize: 13
                    font.family: "monospace"
                    color: "#f59e0b"

                    SequentialAnimation on opacity {
                        running: isRunning
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
            }
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

        // Show the prompt + command in output
        appendLine(getPrompt() + cmd);

        if (!cmd) { appendLine(""); return; }

        // Add to history
        if (cmdHistory.length === 0 || cmdHistory[cmdHistory.length - 1] !== cmd) {
            var hist = cmdHistory.slice();
            hist.push(cmd);
            if (hist.length > 100) hist = hist.slice(hist.length - 100);
            cmdHistory = hist;
        }

        // Built-in: clear
        if (cmd === "clear") {
            outputLines = [""];
            return;
        }

        // Built-in: exit
        if (cmd === "exit") {
            appendLine("Use the close button to close the terminal.");
            appendLine("");
            return;
        }

        isRunning = true;

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:7778/exec");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 20000;

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isRunning = false;
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);

                        // Update working directory
                        if (data.cwd) currentCwd = data.cwd;

                        // Show stdout
                        if (data.stdout) appendLines(data.stdout);

                        // Show stderr in red (it's appended as regular text, colored by the Repeater)
                        if (data.stderr) {
                            var errParts = data.stderr.split("\n");
                            for (var i = 0; i < errParts.length; i++) {
                                if (errParts[i]) appendLine("Error: " + errParts[i]);
                            }
                        }
                    } catch(e) {
                        appendLine("Error: " + (xhr.responseText || "Unknown error"));
                    }
                } else if (xhr.status === 0) {
                    appendLine("Error: Helper service not reachable (port 7778)");
                    appendLine("Start it: node /opt/ainux/whaleos/whaleos-helper.mjs &");
                } else {
                    appendLine("Error: HTTP " + xhr.status);
                }
                appendLine("");
            }
        };

        xhr.ontimeout = function() {
            isRunning = false;
            appendLine("Error: Command timed out (15s limit)");
            appendLine("");
        };

        xhr.send(JSON.stringify({ command: cmd }));
    }
}
