pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Sound card profiles (for example HDMI outputs or Bluetooth headset modes) through pactl.
Singleton {
    id: root

    property var cards: []
    property string error: ""
    property bool loaded: false
    readonly property bool busy: listProcess.running || setProcess.running
    property bool refreshPending: false

    function cardName(card) {
        const properties = card.properties || {};
        return properties["device.description"] || properties["device.product.name"] || card.name;
    }

    function cardIcon(card) {
        const properties = card.properties || {};
        if (String(card.name).startsWith("bluez_card."))
            return "bluetooth";
        if (properties["device.bus"] === "usb")
            return "usb";
        const profiles = Object.keys(card.profiles || {}).filter(name => name !== "off");
        return profiles.length > 0 && profiles.every(name => name.indexOf("hdmi") >= 0) ? "tv" : "speaker";
    }

    // Offer usable profiles plus the active one, so a card can always show its current state.
    function profileOptions(card) {
        const options = [];
        const profiles = card.profiles || {};
        Object.keys(profiles).forEach(name => {
            const profile = profiles[name];
            if (profile.available === false && name !== card.active_profile)
                return;
            options.push({
                             label: profile.description || name,
                             value: name,
                             priority: profile.priority || 0
                         });
        });
        return options.sort((left, right) => (left.value === "off") - (right.value === "off")
                || right.priority - left.priority);
    }

        function refresh() {
        if (listProcess.running) {
        refreshPending = true;
        return;
    }
        listProcess.running = true;
    }

        function setProfile(card, profile) {
        if (!card || !profile || setProcess.running || profile === card.active_profile)
        return;
        error = "";
        setProcess.command = ["pactl", "set-card-profile", card.name, profile];
        setProcess.running = true;
    }

        // Cards appear and disappear with Bluetooth and USB devices; follow PipeWire node changes.
        Connections {
        target: Volume
        function onOutputDevicesChanged() {
        refreshDebounce.restart();
    }
        function onInputDevicesChanged() {
        refreshDebounce.restart();
    }
    }

        Timer {
        id: refreshDebounce
        interval: 500
        onTriggered: if (root.loaded)
        root.refresh()
    }

        Process {
        id: listProcess
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
        id: listResult
    }
        stderr: StdioCollector {
        id: listError
    }
        onExited: code => {
        try {
        if (code !== 0)
        throw new Error(listError.text.trim() || qsTr("Unable to read sound cards"));
        root.cards = JSON.parse(listResult.text).filter(card => Object.keys(card.profiles || {}).length > 1);
        root.loaded = true;
    } catch (e) {
        root.error = String(e.message || e);
    }
        if (root.refreshPending) {
        root.refreshPending = false;
        Qt.callLater(root.refresh);
    }
    }
    }

        Process {
        id: setProcess
        stderr: StdioCollector {
        id: setError
    }
        onExited: code => {
        if (code !== 0)
        root.error = setError.text.trim() || qsTr("Unable to change the sound card profile");
        root.refresh();
    }
    }
    }
