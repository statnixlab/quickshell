pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import Clavis.WindowPreview
import qs.Common
import qs.Components
import qs.Services

// Stage Manager strip for one output. The left one lists the inactive stages,
// the right one every window of the current stage. It slides in when the
// pointer reaches its screen edge and slides out shortly after it leaves.
PanelWindow {
    id: root

    required property var targetScreen
    // "left": other stages; "right": windows of the current stage.
    property string edge: "left"
    readonly property bool rightEdge: edge === "right"
    property bool revealed: false
    property var stages: []
    property string previewConsumer: ""
    readonly property string outputName: targetScreen ? targetScreen.name : ""
    readonly property real stripWidth: 252
    // Window being dragged out of the strip, and the pointer in window coordinates.
    property var dragWindow: null
    property point dragPoint: Qt.point(0, 0)
    readonly property bool dragging: dragWindow !== null
    // Past the strip: releasing moves the window into the current stage.
    readonly property bool dropArmed: dragging && root.outsideStrip(dragPoint)

    function outsideStrip(position) {
        return rightEdge ? position.x < width - stripWidth : position.x > stripWidth;
    }

    function finishDrag(position, accepted) {
        const window = dragWindow;
        dragWindow = null;
        if (accepted && window && outsideStrip(position)) {
            StageManagerService.moveWindowToActive(window.id, outputName);
            conceal();
        } else if (!stripHover.hovered && revealed) {
            hideTimer.restart();
        }
    }

    function syncStages() {
        stages = rightEdge ? StageManagerService.currentStageWindows(outputName) :
                             StageManagerService.stagesForOutput(outputName);
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
        // Only clear a request addressed to this strip: the other edge's
        // strip conceals itself on the same notification.
        if (StageManagerService.requestedOutput === outputName && StageManagerService.requestedEdge === edge)
            StageManagerService.requestedOutput = "";
        revealed = false;
        syncStages();
    }

    screen: targetScreen
    // Slide progress: 0 shown, 1 fully off-screen. Animating this instead of
    // x keeps the right strip from sliding across the screen when the
    // surface's width is first set as it maps.
    property real hiddenAmount: revealed ? 0 : 1
    Behavior on hiddenAmount {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    visible: revealed || hiddenAmount < 1
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
        function onFocusedWindowChanged() {
            if (root.rightEdge)
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
            if (StageManagerService.requestedOutput === root.outputName && StageManagerService.requestedEdge
                    === root.edge && !root.revealed)
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
        x: root.rightEdge ? root.width - width + root.hiddenAmount * width : -root.hiddenAmount * width

        HoverHandler {
            id: stripHover
            onHoveredChanged: {
                if (hovered)
                    hideTimer.stop();
                else if (root.revealed && !root.dragging)
                    hideTimer.restart();
            }
        }

        Flickable {
            id: list
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 48
            anchors.bottomMargin: 48
            contentHeight: column.height
            // Clip only while scrolling, so card shadows and tilted edges are not cut.
            clip: interactive
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
                        mirrored: root.rightEdge
                        emphasizeFocus: root.rightEdge && root.stages.length > 1
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
