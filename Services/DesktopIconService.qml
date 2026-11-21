pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Files
import qs.Common
import qs.Services

// Files in the XDG desktop directory (~/Desktop, ~/桌面, ...) shown as icons on
// the wallpaper. Shortcuts are symbolic links in that directory, so they also
// appear in file managers and survive a shell restart without extra state.
Singleton {
    id: root

    readonly property string filePath: Paths.configHome + "/desktop-icons.json"
    readonly property url desktopUrl: StandardPaths.writableLocation(StandardPaths.DesktopLocation)
    readonly property string desktopPath: root.localPath(root.desktopUrl)
    readonly property var sortOrders: ["name", "modified", "kind", "size"]

    property bool enabled: true
    property string sort: "name"
    property bool ready: false
    property bool writable: false
    property string error: ""
    property bool _storeReady: false

    function localPath(value) {
        let path = String(value || "");
        if (path.startsWith("file://"))
            path = path.substring("file://".length);
        try {
            return decodeURIComponent(path);
        } catch (error) {
            return path;
        }
    }

    function fileUrl(path) {
        return "file://" + String(path).split("/").map(component => encodeURIComponent(component)).join("/");
    }

    function baseName(path) {
        const trimmed = String(path || "").replace(/\/+$/, "");
        return trimmed.substring(trimmed.lastIndexOf("/") + 1);
    }

    function parentPath(path) {
        const trimmed = String(path || "").replace(/\/+$/, "");
        return trimmed.substring(0, trimmed.lastIndexOf("/")) || "/";
    }

    function isOnDesktop(url) {
        return root.desktopPath !== "" && root.parentPath(root.localPath(url)) === root.desktopPath;
    }

    function setEnabled(value) {
        if (root.enabled === !!value)
            return;
        root.enabled = !!value;
        root.save();
    }

    function setSort(value) {
        if (root.sortOrders.indexOf(value) < 0 || root.sort === value)
            return;
        root.sort = value;
        root.save();
    }

    // The launcher a .desktop file on the desktop starts, if it names an
    // installed application; its icon then replaces the generic MIME icon.
    function applicationFor(info) {
        const name = String(info && info.name || "");
        if (!name.endsWith(".desktop"))
            return null;
        return ApplicationService.findById(name) || null;
    }

    function open(info) {
        if (!info || !info.url)
            return false;
        if (!DesktopFiles.info(info.url).available) {
            root.error = qsTr("This file or folder is unavailable.");
            return false;
        }
        // A launcher runs its application, like on other desktops; anything
        // else opens with its default handler (folders in the file manager).
        if (String(info.name || "").endsWith(".desktop") && !info.isDirectory)
            return ApplicationService.launchCommand(["gio", "launch", root.localPath(info.url)]);
        return ApplicationService.openUrl(info.url);
    }

    function reveal(info) {
        if (info && info.url)
            FileActionService.run("reveal", root.localPath(info.url));
    }

    function openDesktopFolder() {
        if (root.desktopPath !== "")
            ApplicationService.openUrl(root.fileUrl(root.desktopPath));
    }

    function moveToTrash(urls) {
        const list = Array.from(urls || []).filter(url => !!url);
        return list.length > 0 && DesktopFiles.moveToTrash(list);
    }

    // A free name in the desktop directory: "name", then "name (2)", ...
    function shortcutPath(name, taken) {
        const dot = name.lastIndexOf(".");
        const stem = dot > 0 ? name.substring(0, dot) : name;
        const suffix = dot > 0 ? name.substring(dot) : "";
        for (let index = 1; index < 1000; index++) {
            const candidate = root.desktopPath + "/" + (index === 1 ? name : stem + " (" + index + ")"
                                                                      + suffix);
            const existing = DesktopFiles.info(root.fileUrl(candidate));
            if (!existing.available && !existing.isLink && taken.indexOf(candidate) < 0)
                return candidate;
        }
        return "";
    }

    // Creates a symbolic link on the desktop for each local file or folder
    // that is not already there. Returns how many links were requested.
    function createShortcuts(urls) {
        if (root.desktopPath === "")
            return 0;
        const taken = [];
        for (const url of Array.from(urls || [])) {
            const info = DesktopFiles.info(String(url));
            const name = root.baseName(info.path);
            if (!name || !info.available || info.path === root.desktopPath || root.isOnDesktop(info.url))
                continue;
            const target = root.shortcutPath(name, taken);
            if (!target)
                continue;
            taken.push(target);
            linkProcess.createObject(root, {
                                         source: info.path,
                                         target
                                     });
        }
        return taken.length;
    }

    function addShortcut(path) {
        const value = String(path || "");
        if (!value.startsWith("/"))
            return false;
        return root.createShortcuts([root.fileUrl(value.replace(/\/+$/, "") || "/")]) > 0;
    }

    function save() {
        if (!root.ready || !root.writable)
            return;
        configFile.setText(JSON.stringify({
                                              schemaVersion: 1,
                                              enabled: root.enabled,
                                              sort: root.sort
                                          }, null, 2));
    }

    function loaded(text, canWrite, error) {
        if (text !== "") {
            try {
                const config = JSON.parse(text);
                if (config && config.schemaVersion === 1) {
                    if (typeof config.enabled === "boolean")
                        root.enabled = config.enabled;
                    if (root.sortOrders.indexOf(config.sort) >= 0)
                        root.sort = config.sort;
                } else {
                    canWrite = false;
                }
            } catch (exception) {
                canWrite = false;
                error = qsTr("Desktop icon settings could not be read. Changes apply to this session only.");
            }
        }
        root.writable = canWrite;
        if (error)
            root.error = error;
        root.ready = true;
    }

    Component {
        id: linkProcess

        Process {
            id: link

            required property string source
            required property string target

            // No -f: an existing name is never replaced.
            command: ["ln", "-s", "--", link.source, link.target]
            running: true
            stderr: StdioCollector {
                id: linkError
            }
            onExited: exitCode => {
                if (exitCode !== 0)
                    root.error = qsTr("The shortcut could not be created.") + (linkError.text.trim() ? "\n"
                                                                                                       + linkError.text.trim(
                                                                                                           ) : "");
                link.destroy();
            }
        }
    }

    Process {
        command: ["mkdir", "-p", Paths.configHome]
        running: true
        onExited: exitCode => {
            if (exitCode === 0)
                root._storeReady = true;
            else
                root.loaded("", false, qsTr(
                                "Desktop icon settings cannot be saved because the configuration directory is unavailable."));
        }
    }

    FileView {
        id: configFile

        path: root._storeReady ? root.filePath : ""
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        onFileChanged: configFile.reload()
        onLoaded: root.loaded(configFile.text(), true, "")
        onLoadFailed: error => {
            if (!root._storeReady)
                return;
            const missing = error === FileViewError.FileNotFound;
            root.loaded("", missing, missing ? "" : qsTr(
                                                   "Desktop icon settings could not be opened. Changes apply to this session only."));
        }
        onSaveFailed: error => {
            root.writable = false;
            root.error = qsTr(
                        "Desktop icon settings could not be saved. Changes apply to this session only.");
        }
    }
}
