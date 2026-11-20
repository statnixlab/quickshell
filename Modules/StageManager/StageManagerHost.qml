pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Modules.Dock
import qs.Services

Item {
    id: root

    Variants {
        model: StageManagerService.enabled && Niri.connected ? Quickshell.screens : []

        Item {
            id: perScreen
            required property var modelData

            StageManagerStrip {
                id: strip
                targetScreen: perScreen.modelData
            }
            // Only the middle of the edge reacts, keeping the corners free
            // for hot corners and the bar.
            DockEdgeTrigger {
                screen: perScreen.modelData
                edge: "left"
                dragMimeType: "application/x-clavis-stage"
                activeLength: perScreen.modelData.height * 0.6
                onActivated: strip.reveal()
            }
        }
    }

    IpcHandler {
        target: "stage-manager"
        function toggle(): bool {
            if (StageManagerService.requestedOutput !== "") {
                StageManagerService.dismiss();
                return true;
            }
            return StageManagerService.request("");
        }
        function open(): bool {
            return StageManagerService.request("");
        }
        function close(): void {
            StageManagerService.dismiss();
        }
        function setEnabled(enabled: bool): void {
            StageManagerService.enabled = enabled;
        }
        function status(): string {
            return JSON.stringify({
                                      enabled: StageManagerService.enabled,
                                      stages: StageManagerService.stagesForOutput(Niri.currentOutput).map(
                                                  stage => ({
                                                      id: stage.id,
                                                      index: stage.index,
                                                      windows: stage.windows.length
                                                  }))
        });
    }
}
}
