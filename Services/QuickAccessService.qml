pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string filePath: Paths.configHome + "/quick-access.json"
    readonly property string bookmarksPath: Paths.xdgConfigHome + "/gtk-3.0/bookmarks"
    property var savedFolders: []
    property var bookmarks: []
    readonly property var folders: {
        const urls = root.bookmarks.map(item => item.url);
        return urls.concat(root.savedFolders.filter(url => urls.indexOf(url) < 0));
    }
    property bool storeReady: false
    property bool ready: false
    property bool writable: false
    property string errorMessage: ""
    property string bookmarkError: ""

    function bookmarkUrl(value) {
        const url = String(value || "");
        if (url.startsWith("file:"))
            return root.localUrl(url);
        return /^(smb|sftp|ftp|ftps|dav|davs|afp|nfs|mtp|gphoto2):\/\/[^\s\u0000]+$/.test(url) ? url : "";
    }

    function parseBookmarks(text) {
        const entries = [];
        for (const line of text.split(/\r?\n/)) {
            const match = /^(\S+)(?:[ \t]+(.*))?$/.exec(line);
            if (!match)
                continue;
            const url = root.bookmarkUrl(match[1]);
            if (url && !entries.some(item => item.url === url))
                entries.push({
                                 url: url,
                                 label: match[2] || ""
                             });
        }
        return entries;
    }

    function isBookmark(url) {
        return root.bookmarks.some(item => item.url === url);
    }

    function refreshBookmarks() {
        bookmarkFile.reload();
    }

    function localUrl(value) {
        const url = String(value || "");
        if (!url.startsWith("file:///"))
            return "";
        try {
            const path = decodeURIComponent(url.slice(7)).replace(/\/+$/, "") || "/";
            if (path.indexOf("\u0000") >= 0)
                return "";
            return "file://" + path.split("/").map(part => encodeURIComponent(part)).join("/");
        } catch (error) {
            return "";
        }
    }

    function folderPath(url) {
        const path = url.startsWith("file://") ? url.slice(7) : url;
        try {
            return decodeURIComponent(path);
        } catch (error) {
            return path;
        }
    }

    function folderName(url) {
        const bookmark = root.bookmarks.find(item => item.url === url);
        if (bookmark && bookmark.label)
            return bookmark.label;
        const path = folderPath(url).replace(/\/+$/, "") || "/";
        return path === "/" ? "/" : path.slice(path.lastIndexOf("/") + 1);
    }

    function save() {
        if (!root.ready || !root.writable)
            return;
        root.errorMessage = "";
        folderFile.setText(JSON.stringify({
                                              schemaVersion: 1,
                                              folders: root.savedFolders
                                          }, null, 2));
    }

    function addFolder(value) {
        if (!root.ready || !root.writable)
            return false;
        const url = localUrl(value);
        if (!url) {
            root.errorMessage = qsTr("Choose a local folder.");
            return false;
        }
        if (root.folders.indexOf(url) >= 0) {
            root.errorMessage = qsTr("This folder is already in Quick access.");
            return false;
        }
        root.savedFolders = [...root.savedFolders, url];
        root.save();
        return true;
    }

    function removeFolder(url) {
        if (!root.ready || !root.writable)
            return;
        root.savedFolders = root.savedFolders.filter(item => item !== url);
        root.save();
    }

    function openFolder(url) {
        const target = bookmarkUrl(url);
        root.errorMessage = "";
        if (target && Qt.openUrlExternally(target))
            return true;
        root.errorMessage = qsTr("Could not open this folder.");
        return false;
    }

    Process {
        command: ["mkdir", "-p", Paths.configHome]
        running: true
        onExited: exitCode => {
            if (exitCode === 0)
                root.storeReady = true;
            else {
                root.ready = true;
                root.errorMessage = qsTr("Could not prepare Quick access storage.");
            }
        }
    }

    FileView {
        id: folderFile
        path: root.storeReady ? root.filePath : ""
        atomicWrites: true
        watchChanges: false
        onLoaded: {
            if (root.ready)
                return;
            try {
                const data = JSON.parse(folderFile.text());
                if (data.schemaVersion !== 1 || !Array.isArray(data.folders))
                    throw new Error("Invalid quick access data");
                const folders = [];
                for (const value of data.folders) {
                    const url = root.localUrl(value);
                    if (!url)
                        throw new Error("Invalid folder URL");
                    if (folders.indexOf(url) < 0)
                        folders.push(url);
                }
                root.savedFolders = folders;
                root.writable = true;
            } catch (error) {
                root.errorMessage = qsTr("Could not read saved folders. The saved file has been preserved.");
            }
            root.ready = true;
        }
        onLoadFailed: error => {
            if (!root.storeReady || root.ready)
                return;
            root.writable = error === FileViewError.FileNotFound;
            if (!root.writable)
                root.errorMessage = qsTr("Could not read saved folders. The saved file has been preserved.");
            root.ready = true;
        }
        onSaveFailed: error => {
            root.errorMessage = qsTr("Could not save folders. Changes may be lost after restarting.");
            console.warn("QuickAccessService: save failed:", error);
        }
    }

    Timer {
        id: bookmarkReload
        interval: 80
        onTriggered: bookmarkFile.reload()
    }

    FileView {
        id: bookmarkFile
        path: root.bookmarksPath
        watchChanges: true
        onFileChanged: bookmarkReload.restart()
        onLoaded: {
            root.bookmarks = root.parseBookmarks(bookmarkFile.text());
            root.bookmarkError = "";
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.bookmarks = [];
                root.bookmarkError = "";
            } else {
                root.bookmarkError = qsTr("Could not read file manager bookmarks.");
            }
        }
    }
}
