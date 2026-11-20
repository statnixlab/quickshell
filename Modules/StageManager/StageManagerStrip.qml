pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import Clavis.WindowPreview
import qs.Common
import qs.Components
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
    // Window being dragged out of the strip, and the pointer in window coordinates.
    property var dragWindow: null
    property point dragPoint: Qt.point(0, 0)
    readonly property bool dragging: dragWindow !== null
    // Past the strip: releasing moves the window into the current stage.
    readonly property bool dropArmed: dragging && dragPoint.x > stripWidth

    function finishDrag(position, accepted) {
        const window = dragWindow;
        dragWindow = null;
        if (accepted && window && position.x > stripWidth) {
            StageManagerService.moveWindowToActive(window.id, outputName);
            conceal();
        } else if (!stripHover.hovered && revealed) {
            hideTimer.restart();
        }
    }

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
        dragWindow = null;
        if (StageManagerService.requestedOutput === outputName)
            StageManagerService.requestedOutput = "";
        revealed = false;
        syncStages();
    }

    screen: targetScreen
    visible: revealed || content.x > -content.width
    color: "transparent"
    // The surface spans the screen so a dragged window can follow the pointer
    // anywhere; only the strip itself takes input outside a drag.
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    mask: Region {
        item: root.dragging ? fullArea : content
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

    Item {
        id: fullArea
        anchors.fill: parent
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
                else if (root.revealed && !root.dragging)
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
                        draggedWindowId: root.dragWindow ? root.dragWindow.id : null
                        onWindowDragStarted: (window, position) => {
                            hideTimer.stop();
                            root.dragPoint = position;
                            root.dragWindow = window;
                        }
                        onWindowDragMoved: position => root.dragPoint = position
                        onWindowDragFinished: position => root.finishDrag(position, true)
                        onWindowDragCanceled: root.finishDrag(root.dragPoint, false)
                    }
                }
            }
        }
    }

    // The dragged window's live thumbnail following the pointer.
    Item {
        id: dragGhost
        z: 10
        visible: root.dragging
        readonly property WindowPreviewFrame frame: {
            const revision = WindowPreviewService.revision;
            return root.dragWindow ? WindowPreviewService.frameFor(root.dragWindow.id) : null;
        }
        readonly property bool hasFrame: !!frame && frame.hasFrame
        readonly property real aspect: hasFrame && frame.sourceSize.height > 0 ? frame.sourceSize.width
                                                                                 / frame.sourceSize.height :
                                                                                 1.6
        width: 240
        height: width / aspect
        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
        scale: root.dropArmed ? 1.15 : 0.92

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            clip: true
            color: Appearance.colors.colSurfaceContainerHigh
            border.width: root.dropArmed ? 2 : 1
            border.color: root.dropArmed ? Appearance.colors.colPrimary : Appearance.applyAlpha(
                                               Appearance.colors.colOnSurface, 0.15)

            CaptureImage {
                anchors.fill: parent
                frame: dragGhost.frame
                visible: dragGhost.hasFrame
            }
            ThemeIcon {
                anchors.centerIn: parent
                width: 56
                height: 56
                visible: !dragGhost.hasFrame
                iconSource: root.dragWindow ? ApplicationService.iconSource(root.dragWindow.iconPath
                                                                            || root.dragWindow.appId) : ""
                sourceSize: Qt.size(112, 112)
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
