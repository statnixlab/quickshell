pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Services

Item {
    id: root

    // Each edge follows its own setting; a disabled edge has no strip and no
    // edge trigger at all.
    Variants {
        model: StageManagerService.enabled && Niri.connected && UiPreferences.stageManagerLeftEnabled
               ? Quickshell.screens : []
        StageManagerEdge {
            required property var modelData
            targetScreen: modelData
            edge: "left"
        }
    }
    Variants {
        model: StageManagerService.enabled && Niri.connected && UiPreferences.stageManagerRightEnabled
               ? Quickshell.screens : []
        StageManagerEdge {
            required property var modelData
            targetScreen: modelData
            edge: "right"
        }
    }

    IpcHandler {
        target: "stage-manager"
        function toggle(): bool {
            if (StageManagerService.requestedOutput !== "" && StageManagerService.requestedEdge === "left") {
                StageManagerService.dismiss();
                return true;
            }
            return StageManagerService.request("");
        }
        function open(): bool {
            return StageManagerService.request("");
        }
        // Right-edge strip with the windows of the current stage.
        function toggleCurrent(): bool {
            if (StageManagerService.requestedOutput !== "" && StageManagerService.requestedEdge === "right") {
                StageManagerService.dismiss();
                return true;
            }
            return StageManagerService.request("", "right");
        }
        function openCurrent(): bool {
            return StageManagerService.request("", "right");
        }
        function close(): void {
            StageManagerService.dismiss();
        }
        function setEnabled(enabled: bool): void {
            StageManagerService.enabled = enabled;
        }
        function status(): string {
            const output = Niri.currentOutput;
            const stages = [];
            for (const stage of StageManagerService.stagesForOutput(output))
                stages.push({
                                id: stage.id,
                                minimized: !!stage.minimized,
                                windows: stage.windows.length
                            });
            const currentWindows = [];
            for (const stage of StageManagerService.currentStageWindows(output))
                currentWindows.push(stage.windows[0].appId);
            return JSON.stringify({
                                      enabled: StageManagerService.enabled,
                                      stages: stages,
                                      currentWindows: currentWindows
                                  });
        }
    }
}
