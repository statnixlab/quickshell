pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import qs.Common
import qs.Services

// Left-edge strip of inactive stages for one output. It slides in when the
// pointer reaches the screen edge and slides out shortly after it leaves.
PanelWindow {
    id: root

    required property var targetScreen
    property bool revealed: false
    property var stages: []
    property string previewConsumer: ""
    readonly property string outputName: targetScreen ? targetScreen.name : ""
    readonly property real stripWidth: 236

    function syncStages() {
        stages = StageManagerService.stagesForOutput(outputName);
        if (!previewConsumer)
            return;
        const ids = [];
        if (revealed)
            for (const stage of stages)
                for (const window of stage.windows.slice(0, StageManagerService.maximumPreviewWindows))
                    ids.push(String(window.id));
        WindowPreviewService.setTargets(previewConsumer, ids);
    }
    function reveal() {
        if (!StageManagerService.enabled || Niri.inOverview || LaunchpadService.visible)
            return;
        syncStages();
        if (stages.length === 0)
            return;
        revealed = true;
        syncStages();
        hideTimer.stop();
    }
    function conceal() {
        if (StageManagerService.requestedOutput === outputName)
            StageManagerService.requestedOutput = "";
        revealed = false;
        syncStages();
    }

    screen: targetScreen
    visible: revealed || content.x > -content.width
    color: "transparent"
    implicitWidth: stripWidth
    anchors {
        left: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "clavis-stage-manager"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Component.onCompleted: {
        previewConsumer = WindowPreviewService.createConsumer();
        syncStages();
    }
    Component.onDestruction: WindowPreviewService.release(previewConsumer)

    Connections {
        target: Niri
        function onWindowsChanged() {
            root.syncStages();
        }
        function onWorkspacesChanged() {
            root.syncStages();
        }
        function onFocusedWorkspaceChanged() {
            root.syncStages();
        }
        function onOverviewChanged() {
            if (Niri.inOverview)
                root.conceal();
        }
    }
    Connections {
        target: StageManagerService
        function onRequestRevisionChanged() {
            if (StageManagerService.requestedOutput === root.outputName && !root.revealed)
                root.reveal();
            else
                root.conceal();
        }
        function onEnabledChanged() {
            if (!StageManagerService.enabled)
                root.conceal();
        }
    }

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: root.conceal()
    }

    Item {
        id: content
        width: root.stripWidth
        height: parent.height
        x: root.revealed ? 0 : -width

        Behavior on x {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: stripHover
            onHoveredChanged: {
                if (hovered)
                    hideTimer.stop();
                else if (root.revealed)
                    hideTimer.restart();
            }
        }

        // Soft scrim so thumbnails stay readable over busy windows.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Appearance.applyAlpha(Appearance.m3colors.m3shadow, 0.32)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        Flickable {
            id: list
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            contentHeight: column.height
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column
                width: list.width
                y: Math.max(0, (list.height - height) / 2)
                spacing: 20

                Repeater {
                    model: root.stages

                    StageCard {
                        required property var modelData
                        width: column.width
                        stage: modelData
                        previewsEnabled: root.revealed
                        // Focusing a window also switches to its workspace;
                        // a minimized one is restored onto this output.
                        onWindowActivated: windowId => {
                            DockService.focusWindow(windowId, root.outputName);
                            root.conceal();
                        }
                        onMergeRequested: StageManagerService.mergeIntoActive(modelData.id, root.outputName)
                    }
                }
            }
        }
    }
}
