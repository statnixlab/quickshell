pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Services

Item {
    id: root
    property bool opened: false
    property var targetScreen: null
    property double initialWindowId: 0
    property int initialStep: 0
    property bool commitOnMetaRelease: false

    function open() {
        if (!Niri.connected || WindowPreviewService.suspended)
            return;
        targetScreen = Quickshell.screens.find(output => output.name === Niri.currentOutput)
                || Quickshell.screens[0] || null;
        if (!targetScreen)
            return;
        initialWindowId = Niri.focusedWindow.id || 0;
        if (Niri.inOverview)
            Niri.toggleOverview();
        if (LaunchpadService.visible)
            LaunchpadService.close();
        opened = true;
    }
    function close() {
        opened = false;
        commitOnMetaRelease = false;
        initialStep = 0;
    }
    function cycle(step) {
        commitOnMetaRelease = true;
        const window = overview.item as WindowOverviewWindow;
        if (opened && window)
            window.moveSelection(step);
        else {
            initialStep = step;
            open();
        }
    }
    function toggle() {
        if (opened)
            close();
        else
            open();
    }

    Connections {
        target: WindowPreviewService
        function onSuspendedChanged() {
            if (WindowPreviewService.suspended)
                root.close();
        }
    }
    Connections {
        target: Niri
        function onConnectedChanged() {
            if (!Niri.connected)
                root.close();
        }
    }

    LazyLoader {
        id: overview
        active: root.opened
        WindowOverviewWindow {
            targetScreen: root.targetScreen
            initialWindowId: root.initialWindowId
            initialStep: root.initialStep
            commitOnMetaRelease: root.commitOnMetaRelease
            onDismissed: root.close()
        }
    }

    IpcHandler {
        target: "window-overview"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
        function next(): void {
            root.cycle(1);
        }
        function previous(): void {
            root.cycle(-1);
        }
        function status(): string {
            const window = overview.item as WindowOverviewWindow;
            return JSON.stringify({
                                      opened: root.opened,
                                      windows: window ? window.windows.length : 0,
                                      previews: window ? window.previewCount() : 0,
                                      selected: window && window.windows[window.selected]
                                      ? window.windows[window.selected].id : 0,
                                      captures: WindowPreviewService.captureCount
                                  });
        }
    }
}
