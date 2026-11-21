pragma Singleton
import QtQuick
import Quickshell
import Clavis.Niri

// Stage Manager: every niri workspace on an output is one "stage". The strip
// lists the inactive stages of that output; activating one focuses its
// workspace, merging moves its windows into the active workspace.
Singleton {
    id: root

    property bool enabled: true
    // Output name whose strip was requested through IPC; "" when none.
    property string requestedOutput: ""
    // Which strip was requested: "left" (other stages) or "right" (current stage).
    property string requestedEdge: "left"
    property int requestRevision: 0
    readonly property int maximumPreviewWindows: 6

    function liveWindows(workspaceId) {
        return Niri.windowsForWorkspace(workspaceId).filter(window => !window.isMinimized).sort((a, b) => {
            if (a.isFloating !== b.isFloating)
                return a.isFloating ? 1 : -1;
            return (a.layoutColumn - b.layoutColumn) || (a.layoutRow - b.layoutRow);
        });
    }

    // Inactive stages of one output, in workspace order, each with its
    // windows ordered so that the workspace's active window comes first.
    // Minimized windows belong to no workspace in niri; each one is shown as
    // its own stage after the workspace stages, on every output.
    function stagesForOutput(outputName) {
        if (!Niri.connected || !outputName)
            return [];
        const workspaceStages = Niri.workspacesForOutput(outputName).filter(workspace =>
        !workspace.isActive).sort((a, b) => a.index - b.index).map(workspace => {
            const windows = liveWindows(workspace.id);
            const active = windows.findIndex(window => window.id === workspace.activeWindowId);
            if (active > 0)
                windows.unshift(windows.splice(active, 1)[0]);
            return {
                id: workspace.id,
                minimized: false,
                windows: windows
            };
        }).filter(stage => stage.windows.length > 0);
        const minimizedStages = Niri.searchWindows("").filter(window => window.isMinimized).sort((a, b)
                                                                                                 => a.id - b.id).map(
                  window => ({
                      id: window.id,
                      minimized: true,
                      windows: [window]
                  }));
        return workspaceStages.concat(minimizedStages);
    }

    // Move every window of a stage into the active stage of the same output.
    function mergeIntoActive(workspaceId, outputName) {
        if (!Niri.connected)
            return false;
        const target = Niri.activeWorkspaceForOutput(outputName);
        if (!target || !target.id || target.id === workspaceId)
            return false;
        const windows = liveWindows(workspaceId);
        for (const window of windows)
            Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", "--window-id",
                                     String(window.id), "--focus", "false", String(target.index)]);
        return windows.length > 0;
    }

    // Move one window into the active stage of an output and focus it. A
    // minimized window is restored onto that output instead.
    function moveWindowToActive(windowId, outputName) {
        if (!Niri.connected)
            return false;
        const window = Niri.windowById(windowId);
        if (!window || !window.id)
            return false;
        if (window.isMinimized)
            return Niri.restoreWindow(windowId, String(outputName || ""));
        const target = Niri.activeWorkspaceForOutput(outputName);
        if (!target || !target.id)
            return false;
        if (window.workspaceId === target.id)
            return Niri.focusWindow(windowId);
        // Move first, then focus, as one sequence so focus lands on the moved window.
        Quickshell.execDetached(["sh", "-c",
                                 'niri msg action move-window-to-workspace --window-id "$1" --focus false "$2" '
                                 + '&& niri msg action focus-window --id "$1"', "sh", String(windowId), String(
                                     target.index)]);
        return true;
    }

    // Windows of the output's active workspace, each as its own one-window
    // stage for the right-edge strip, in layout order (floating last).
    function currentStageWindows(outputName) {
        if (!Niri.connected || !outputName)
            return [];
        const workspace = Niri.activeWorkspaceForOutput(outputName);
        if (!workspace || !workspace.id)
            return [];
        const stages = [];
        for (const window of liveWindows(workspace.id)) {
            stages.push({
                            id: window.id,
                            minimized: false,
                            current: true,
                            focused: window.id === workspace.activeWindowId,
                            windows: [window]
                        });
        }
        return stages;
    }
    function request(outputName, edge) {
        requestedEdge = edge === "right" ? "right" : "left";
        if (!enabled)
            return false;
        const output = String(outputName || Niri.currentOutput || "");
        requestedOutput = output;
        requestRevision++;
        return output !== "";
    }
    function dismiss() {
        requestedOutput = "";
        requestRevision++;
    }
}
