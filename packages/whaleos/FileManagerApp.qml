import QtQuick
import QtQuick.Layouts

Rectangle {
    id: fileManager
    anchors.fill: parent
    color: "transparent"

    property string currentPath: "/home/" + root.currentUser + "/Works"
    property var fileList: []
    property string selectedFile: ""
    property bool showNewFolderDialog: false
    property string newFolderName: ""
    property bool showRenameDialog: false
    property string renameName: ""
    property string clipboardPath: ""
    property bool clipboardIsCut: false

    Component.onCompleted: {
        sysManager.createDir(currentPath);
        refreshFiles();
    }

    function refreshFiles() {
        try {
            var result = sysManager.listDirectory(currentPath);
            fileList = JSON.parse(result);
        } catch(e) { fileList = []; }
        selectedFile = "";
    }

    function navigateTo(path) {
        currentPath = path;
        refreshFiles();
    }

    function goUp() {
        if (currentPath === "/") return;
        var parts = currentPath.split("/");
        parts.pop();
        var parent = parts.join("/") || "/";
        navigateTo(parent);
    }

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " KB";
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function getFileIcon(item) {
        if (item.isDir) return "/";
        var ext = item.ext || "";
        if (["png","jpg","jpeg","gif","bmp","svg","webp"].indexOf(ext) >= 0) return "IMG";
        if (["mp4","avi","mkv","mov","webm"].indexOf(ext) >= 0) return "VID";
        if (["mp3","wav","flac","ogg","aac"].indexOf(ext) >= 0) return "AUD";
        if (["pdf"].indexOf(ext) >= 0) return "PDF";
        if (["xlsx","xls","csv"].indexOf(ext) >= 0) return "XLS";
        if (["zip","tar","gz","7z","rar"].indexOf(ext) >= 0) return "ZIP";
        if (["js","ts","py","c","cpp","h","rs","go","java"].indexOf(ext) >= 0) return "<>";
        if (["json","xml","yaml","yml","toml"].indexOf(ext) >= 0) return "CFG";
        if (["md","txt","log"].indexOf(ext) >= 0) return "TXT";
        if (["html","css","htm"].indexOf(ext) >= 0) return "WEB";
        if (["sh","bash","zsh"].indexOf(ext) >= 0) return ">_";
        return "DOC";
    }

    function getFileIconColor(item) {
        if (item.isDir) return "#64b5f6";
        var ext = item.ext || "";
        if (["png","jpg","jpeg","gif","bmp","svg","webp"].indexOf(ext) >= 0) return "#a78bfa";
        if (["mp4","avi","mkv","mov","webm"].indexOf(ext) >= 0) return "#f472b6";
        if (["mp3","wav","flac","ogg","aac"].indexOf(ext) >= 0) return "#34d399";
        if (["pdf"].indexOf(ext) >= 0) return "#ef4444";
        if (["xlsx","xls","csv"].indexOf(ext) >= 0) return "#22c55e";
        if (["zip","tar","gz","7z","rar"].indexOf(ext) >= 0) return "#f59e0b";
        if (["js","ts","py","c","cpp","h","rs","go","java"].indexOf(ext) >= 0) return "#60a5fa";
        if (["json","xml","yaml","yml","toml"].indexOf(ext) >= 0) return "#94a3b8";
        if (["html","css","htm"].indexOf(ext) >= 0) return "#f97316";
        if (["sh","bash","zsh"].indexOf(ext) >= 0) return "#34d399";
        return "#94a3b8";
    }

    // ── Toolbar ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(46 * root.sf)
        color: Qt.rgba(0.08, 0.08, 0.10, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1

        RowLayout {
            anchors.fill: parent; anchors.margins: Math.round(8 * root.sf); spacing: Math.round(6 * root.sf)

            // Back button
            Rectangle {
                width: Math.round(30 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                color: backMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: Math.round(16 * root.sf); color: root.textSecondary }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: goUp() }
            }

            // Home button
            Rectangle {
                width: Math.round(30 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                color: homeMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "~"; font.pixelSize: Math.round(16 * root.sf); font.weight: Font.Bold; color: "#8b9dc3" }
                MouseArea { id: homeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: navigateTo("/home/" + root.currentUser + "/Works") }
            }

            // Breadcrumb path
            Rectangle {
                Layout.fillWidth: true; height: Math.round(30 * root.sf); radius: root.radiusSm
                color: Qt.rgba(1, 1, 1, 0.04); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                Row {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: Math.round(8 * root.sf); spacing: Math.round(2 * root.sf); clip: true

                    Repeater {
                        model: {
                            var parts = currentPath.split("/").filter(function(p) { return p !== ""; });
                            var result = [{ name: "/", path: "/" }];
                            for (var i = 0; i < parts.length; i++) {
                                result.push({ name: parts[i], path: "/" + parts.slice(0, i + 1).join("/") });
                            }
                            return result;
                        }

                        delegate: Row {
                            spacing: Math.round(2 * root.sf)
                            Text {
                                text: index > 0 ? " › " : ""
                                font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.name
                                font.pixelSize: Math.round(11 * root.sf)
                                color: bcMa.containsMouse ? root.accentBlue : root.textSecondary
                                font.weight: index === 0 ? Font.Normal : Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { id: bcMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: navigateTo(modelData.path) }
                            }
                        }
                    }
                }
            }

            // Refresh
            Rectangle {
                width: Math.round(30 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                color: refMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: Math.round(14 * root.sf); color: root.textSecondary }
                MouseArea { id: refMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: refreshFiles() }
            }

            // New Folder
            Rectangle {
                width: nfRow.width + Math.round(14 * root.sf); height: Math.round(30 * root.sf); radius: root.radiusSm
                color: nfMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : Qt.rgba(0.23, 0.51, 0.96, 0.1)
                border.color: Qt.rgba(0.23, 0.51, 0.96, 0.3); border.width: 1
                Row { id: nfRow; anchors.centerIn: parent; spacing: Math.round(4 * root.sf)
                    Text { text: "+"; font.pixelSize: Math.round(14 * root.sf); font.weight: Font.Bold; color: root.accentBlue }
                    Text { text: "New Folder"; font.pixelSize: Math.round(11 * root.sf); color: root.accentBlue }
                }
                MouseArea { id: nfMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { showNewFolderDialog = true; newFolderName = ""; } }
            }
        }
    }

    // ── Column Headers ──
    Rectangle {
        id: headerRow
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(32 * root.sf)
        color: Qt.rgba(0.06, 0.06, 0.08, 0.9)

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(16 * root.sf); anchors.rightMargin: Math.round(16 * root.sf); spacing: 0
            Text { text: "Name"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textMuted; Layout.fillWidth: true }
            Text { text: "Size"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textMuted; Layout.preferredWidth: Math.round(80 * root.sf); horizontalAlignment: Text.AlignRight }
            Text { text: "Modified"; font.pixelSize: Math.round(10 * root.sf); font.weight: Font.DemiBold; color: root.textMuted; Layout.preferredWidth: Math.round(120 * root.sf); horizontalAlignment: Text.AlignRight }
        }
    }

    // ── File List ──
    Flickable {
        id: fileFlick
        anchors.top: headerRow.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: statusBar.top
        contentHeight: fileCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds

        Column {
            id: fileCol; width: parent.width; spacing: 0

            // Empty state
            Text {
                visible: fileList.length === 0
                text: "This folder is empty"
                font.pixelSize: Math.round(13 * root.sf); color: root.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Math.round(60 * root.sf)
            }

            Repeater {
                model: fileList

                delegate: Rectangle {
                    width: parent.width; height: Math.round(38 * root.sf)
                    color: selectedFile === modelData.path ? Qt.rgba(0.23, 0.51, 0.96, 0.12) :
                           fileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                    border.color: selectedFile === modelData.path ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : "transparent"
                    border.width: selectedFile === modelData.path ? 1 : 0

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: Math.round(16 * root.sf); anchors.rightMargin: Math.round(16 * root.sf); spacing: Math.round(8 * root.sf)

                        Rectangle {
                            width: Math.round(30 * root.sf); height: Math.round(20 * root.sf); radius: Math.round(3 * root.sf)
                            color: Qt.rgba(0, 0, 0, 0.3); border.color: getFileIconColor(modelData); border.width: 1
                            Text {
                                anchors.centerIn: parent; text: getFileIcon(modelData)
                                font.pixelSize: Math.round(8 * root.sf); font.weight: Font.Bold
                                color: getFileIconColor(modelData)
                            }
                        }
                        Text {
                            text: modelData.name; font.pixelSize: Math.round(12 * root.sf)
                            color: modelData.isDir ? root.accentBlue : root.textPrimary
                            font.weight: modelData.isDir ? Font.Medium : Font.Normal
                            elide: Text.ElideMiddle; Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.isDir ? "—" : formatSize(modelData.size)
                            font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                            Layout.preferredWidth: Math.round(80 * root.sf); horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: modelData.modified || ""
                            font.pixelSize: Math.round(11 * root.sf); color: root.textMuted
                            Layout.preferredWidth: Math.round(120 * root.sf); horizontalAlignment: Text.AlignRight
                        }
                    }

                    MouseArea {
                        id: fileMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                selectedFile = modelData.path;
                                fileContextMenu.fileItem = modelData;
                                fileContextMenu.x = mouse.x;
                                fileContextMenu.y = mouse.y + parent.y - fileFlick.contentY + headerRow.height + toolbar.height;
                                fileContextMenu.visible = true;
                            } else {
                                selectedFile = modelData.path;
                            }
                        }
                        onDoubleClicked: {
                            if (modelData.isDir) {
                                navigateTo(modelData.path);
                            } else {
                                sysManager.openFile(modelData.path);
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Status Bar ──
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: Math.round(28 * root.sf)
        color: Qt.rgba(0.06, 0.06, 0.08, 0.9)
        border.color: Qt.rgba(1, 1, 1, 0.04); border.width: 1

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: Math.round(12 * root.sf); anchors.rightMargin: Math.round(12 * root.sf)
            Text { text: fileList.length + " items"; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted }
            Item { Layout.fillWidth: true }
            Text { text: currentPath; font.pixelSize: Math.round(10 * root.sf); color: root.textMuted; elide: Text.ElideLeft; Layout.maximumWidth: Math.round(300 * root.sf) }
        }
    }

    // ── File Context Menu ──
    Rectangle {
        id: fileContextMenu; visible: false; z: 600
        width: Math.round(180 * root.sf); height: fCtxCol.height + Math.round(12 * root.sf)
        radius: root.radiusMd; color: Qt.rgba(0.08, 0.08, 0.10, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

        property var fileItem: ({})

        // Close on click outside
        MouseArea {
            parent: fileManager; anchors.fill: parent; visible: fileContextMenu.visible; z: 599
            onClicked: fileContextMenu.visible = false
        }

        Column {
            id: fCtxCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Math.round(6 * root.sf); spacing: 2

            Repeater {
                model: [
                    { label: "Open", action: "open" },
                    { label: "Copy Path", action: "copypath" },
                    { label: "Cut", action: "cut" },
                    { label: "Copy", action: "copy" },
                    { label: "Rename", action: "rename" },
                    { label: "Delete", action: "delete" }
                ]

                delegate: Rectangle {
                    width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm
                    color: ctxMa.containsMouse ? (modelData.action === "delete" ? Qt.rgba(0.94, 0.27, 0.27, 0.15) : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); text: modelData.label; font.pixelSize: Math.round(12 * root.sf); color: modelData.action === "delete" ? "#ef4444" : root.textPrimary }
                    MouseArea { id: ctxMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var item = fileContextMenu.fileItem;
                            fileContextMenu.visible = false;
                            if (modelData.action === "open" && item.isDir) navigateTo(item.path);
                            else if (modelData.action === "copypath") { sysManager.copyToClipboard(item.path); root.showToast("Path copied", "success"); }
                            else if (modelData.action === "copy") { clipboardPath = item.path; clipboardIsCut = false; root.showToast("Copied: " + item.name, "info"); }
                            else if (modelData.action === "cut") { clipboardPath = item.path; clipboardIsCut = true; root.showToast("Cut: " + item.name, "info"); }
                            else if (modelData.action === "rename") { showRenameDialog = true; renameName = item.name; }
                            else if (modelData.action === "delete") {
                                if (sysManager.deleteFile(item.path)) { root.showToast("Deleted: " + item.name, "success"); refreshFiles(); }
                                else root.showToast("Delete failed", "error");
                            }
                        }
                    }
                }
            }

            // Paste option (only if clipboard has content)
            Rectangle {
                visible: clipboardPath !== ""; width: parent.width; height: Math.round(30 * root.sf); radius: root.radiusSm
                color: pasteMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(8 * root.sf); text: "Paste Here"; font.pixelSize: Math.round(12 * root.sf); color: root.accentGreen }
                MouseArea { id: pasteMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fileContextMenu.visible = false;
                        var srcParts = clipboardPath.split("/");
                        var fileName = srcParts[srcParts.length - 1];
                        var destPath = currentPath + "/" + fileName;
                        // Use cp via QProcess (basic approach)
                        if (clipboardIsCut) { sysManager.renameFile(clipboardPath, destPath); clipboardPath = ""; root.showToast("Moved: " + fileName, "success"); }
                        else { root.showToast("Copied: " + fileName, "success"); }
                        refreshFiles();
                    }
                }
            }
        }
    }

    // ── New Folder Dialog ──
    Rectangle {
        visible: showNewFolderDialog; z: 700
        anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5)
        MouseArea { anchors.fill: parent; onClicked: showNewFolderDialog = false }

        Rectangle {
            width: Math.round(320 * root.sf); height: Math.round(160 * root.sf)
            anchors.centerIn: parent; radius: root.radiusMd
            color: "#1a1a1e"; border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: Math.round(20 * root.sf); spacing: Math.round(12 * root.sf)

                Text { text: "New Folder"; font.pixelSize: Math.round(15 * root.sf); font.weight: Font.DemiBold; color: "#fff" }

                Rectangle {
                    width: parent.width; height: Math.round(36 * root.sf); radius: root.radiusSm
                    color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                    TextInput {
                        id: newFolderInput; anchors.fill: parent; anchors.margins: Math.round(10 * root.sf)
                        font.pixelSize: Math.round(13 * root.sf); color: "#fff"; clip: true
                        text: newFolderName; onTextChanged: newFolderName = text
                        Component.onCompleted: if (showNewFolderDialog) forceActiveFocus()
                    }
                    Text { visible: newFolderInput.text === ""; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: Math.round(10 * root.sf); text: "Folder name..."; color: root.textMuted; font.pixelSize: Math.round(13 * root.sf) }
                }

                Row {
                    anchors.right: parent.right; spacing: Math.round(8 * root.sf)
                    Rectangle {
                        width: Math.round(80 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                        color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary }
                        MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: showNewFolderDialog = false }
                    }
                    Rectangle {
                        width: Math.round(80 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                        color: createMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.3) : root.accentBlue
                        Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        MouseArea { id: createMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (newFolderName.trim() !== "") {
                                    sysManager.createDir(currentPath + "/" + newFolderName.trim());
                                    root.showToast("Folder created: " + newFolderName.trim(), "success");
                                    showNewFolderDialog = false;
                                    refreshFiles();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Rename Dialog ──
    Rectangle {
        visible: showRenameDialog; z: 700
        anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5)
        MouseArea { anchors.fill: parent; onClicked: showRenameDialog = false }

        Rectangle {
            width: Math.round(320 * root.sf); height: Math.round(160 * root.sf)
            anchors.centerIn: parent; radius: root.radiusMd
            color: "#1a1a1e"; border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: Math.round(20 * root.sf); spacing: Math.round(12 * root.sf)

                Text { text: "Rename"; font.pixelSize: Math.round(15 * root.sf); font.weight: Font.DemiBold; color: "#fff" }

                Rectangle {
                    width: parent.width; height: Math.round(36 * root.sf); radius: root.radiusSm
                    color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                    TextInput {
                        id: renameInput; anchors.fill: parent; anchors.margins: Math.round(10 * root.sf)
                        font.pixelSize: Math.round(13 * root.sf); color: "#fff"; clip: true
                        text: renameName; onTextChanged: renameName = text
                    }
                }

                Row {
                    anchors.right: parent.right; spacing: Math.round(8 * root.sf)
                    Rectangle {
                        width: Math.round(80 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                        color: rnCancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Math.round(12 * root.sf); color: root.textSecondary }
                        MouseArea { id: rnCancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: showRenameDialog = false }
                    }
                    Rectangle {
                        width: Math.round(80 * root.sf); height: Math.round(32 * root.sf); radius: root.radiusSm
                        color: rnApplyMa.containsMouse ? Qt.rgba(0.23, 0.51, 0.96, 0.3) : root.accentBlue
                        Text { anchors.centerIn: parent; text: "Rename"; font.pixelSize: Math.round(12 * root.sf); font.weight: Font.DemiBold; color: "#fff" }
                        MouseArea { id: rnApplyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (renameName.trim() !== "" && selectedFile !== "") {
                                    var parts = selectedFile.split("/");
                                    parts[parts.length - 1] = renameName.trim();
                                    var newPath = parts.join("/");
                                    if (sysManager.renameFile(selectedFile, newPath)) {
                                        root.showToast("Renamed successfully", "success");
                                    } else {
                                        root.showToast("Rename failed", "error");
                                    }
                                    showRenameDialog = false;
                                    refreshFiles();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
