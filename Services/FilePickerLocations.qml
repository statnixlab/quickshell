pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var volumes: []
    property string errorMessage: ""

    function refresh() {
        if (!scan.running) {
            root.errorMessage = "";
            scan.running = true;
        }
    }

    function mountedLocations(devices) {
        const result = [];
        function visit(device) {
            for (const path of device.mountpoints || []) {
                if (typeof path !== "string" || !(path.startsWith("/mnt/") || path.startsWith("/media/")
                                                  || path.startsWith("/run/media/")))
                    continue;
                if (result.some(item => item.path === path))
                    continue;
                result.push({
                                path: path,
                                label: device.label || path.split("/").pop() || device.name
                            });
            }
            for (const child of device.children || [])
                visit(child);
        }
        for (const device of devices)
            visit(device);
        return result.sort((a, b) => a.label.localeCompare(b.label));
    }

    Process {
        id: scan
        command: ["lsblk", "--json", "--tree", "--output", "NAME,LABEL,MOUNTPOINTS"]
        stdout: StdioCollector {
            id: output
        }
        onExited: exitCode => {
            try {
                if (exitCode !== 0)
                    throw new Error("lsblk failed");
                const data = JSON.parse(output.text);
                if (!Array.isArray(data.blockdevices))
                    throw new Error("Invalid device list");
                root.volumes = root.mountedLocations(data.blockdevices);
            } catch (error) {
                root.volumes = [];
                root.errorMessage = qsTr("Could not list drives.");
                console.warn("FilePickerLocations:", error);
            }
        }
    }
}
