pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// System time zone and clock synchronization through timedatectl (polkit asks for authorization).
Singleton {
    id: root

    property string timezone: ""
    property bool ntp: false
    property bool canNtp: false
    property bool ntpSynchronized: false
    property bool localRtc: false
    property var timezones: []
    property string error: ""
    property bool loaded: false
    readonly property bool busy: showProcess.running || setProcess.running

    function refresh() {
        if (!showProcess.running)
            showProcess.running = true;
        if (timezones.length === 0 && !zonesProcess.running)
            zonesProcess.running = true;
    }

    function run(args) {
        if (setProcess.running)
            return;
        error = "";
        setProcess.command = ["timedatectl"].concat(args);
        setProcess.running = true;
    }

    function setTimezone(zone) {
        if (zone && zone !== timezone && timezones.indexOf(zone) >= 0)
            run(["set-timezone", zone]);
    }

    function setNtp(enabled) {
        run(["set-ntp", enabled ? "true" : "false"]);
    }

    function setLocalRtc(enabled) {
        run(["set-local-rtc", enabled ? "true" : "false"]);
    }

    Process {
        id: showProcess
        command: ["timedatectl", "show"]
        stdout: StdioCollector {
            id: showResult
        }
        onExited: code => {
            if (code !== 0) {
                root.error = qsTr("Unable to read the system time settings");
                return;
            }
            const values = {};
            showResult.text.split("\n").forEach(line => {
                const separator = line.indexOf("=");
                if (separator > 0)
                    values[line.slice(0, separator)] = line.slice(separator + 1);
            });
            root.timezone = values.Timezone || "";
            root.ntp = values.NTP === "yes";
            root.canNtp = values.CanNTP === "yes";
            root.ntpSynchronized = values.NTPSynchronized === "yes";
            root.localRtc = values.LocalRTC === "yes";
            root.loaded = true;
        }
    }

    Process {
        id: zonesProcess
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            id: zonesResult
        }
        onExited: code => {
            if (code === 0)
                root.timezones = zonesResult.text.split("\n").filter(zone => zone !== "");
        }
    }

    Process {
        id: setProcess
        stderr: StdioCollector {
            id: setError
        }
        onExited: code => {
            // A dismissed authorization dialog is not an error worth reporting.
            const message = setError.text.trim();
            if (code !== 0 && message.indexOf("canceled") < 0 && message.indexOf("cancelled") < 0)
                root.error = message || qsTr("Unable to change the system time settings");
            root.refresh();
        }
    }
}
