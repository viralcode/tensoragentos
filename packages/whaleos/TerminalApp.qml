import QtQuick
import QtQuick.Layouts
import "api.js" as API

Rectangle {
    id: terminalApp
    anchors.fill: parent
    color: "#0a0a0a"

    property var outputLines: ["Welcome to Whale OS Terminal", "Type a command and press Enter", ""]
    property bool isRunning: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Terminal Output ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0a"

            Flickable {
                id: termFlick
                anchors.fill: parent
                anchors.margins: 12
                contentHeight: termOutput.height
                clip: true

                Text {
                    id: termOutput
                    width: parent.width
                    text: outputLines.join("\n")
                    color: "#22c55e"
                    font.pixelSize: 13
                    font.family: "monospace"
                    wrapMode: Text.WrapAnywhere
                    lineHeight: 1.4
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
            height: 40
            color: "#111111"

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: root.borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Prompt
                Text {
                    text: "ainux@whale:~$"
                    font.pixelSize: 13
                    font.family: "monospace"
                    color: root.accentBlue
                }

                // Input
                TextInput {
                    id: cmdInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#22c55e"
                    font.pixelSize: 13
                    font.family: "monospace"
                    clip: true
                    focus: true

                    Keys.onReturnPressed: executeCommand()
                    Keys.onUpPressed: {
                        // TODO: command history
                    }
                }
            }
        }
    }

    function executeCommand() {
        var cmd = cmdInput.text.trim();
        if (!cmd || isRunning) return;

        // Add command to output
        var lines = outputLines.slice();
        lines.push("ainux@whale:~$ " + cmd);
        outputLines = lines;
        cmdInput.text = "";
        isRunning = true;

        // Handle built-in commands
        if (cmd === "clear") {
            outputLines = [""];
            isRunning = false;
            return;
        }

        if (cmd === "help") {
            var lines2 = outputLines.slice();
            lines2.push("Available commands:");
            lines2.push("  clear     - Clear terminal");
            lines2.push("  help      - Show this help");
            lines2.push("  <any>     - Execute via Whale AI exec tool");
            lines2.push("");
            outputLines = lines2;
            isRunning = false;
            return;
        }

        // Execute via OpenWhale exec tool
        var body = JSON.stringify({ tool: "exec", args: { command: cmd } });
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:7777/api/tools/execute");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isRunning = false;
                var lines3 = outputLines.slice();
                try {
                    var data = JSON.parse(xhr.responseText);
                    if (data.result) {
                        var resultLines = data.result.split("\n");
                        for (var i = 0; i < resultLines.length; i++) {
                            lines3.push(resultLines[i]);
                        }
                    } else if (data.error) {
                        lines3.push("Error: " + data.error);
                    }
                } catch(e) {
                    lines3.push("Error: " + xhr.responseText);
                }
                lines3.push("");
                outputLines = lines3;
            }
        };
        xhr.send(body);
    }
}
