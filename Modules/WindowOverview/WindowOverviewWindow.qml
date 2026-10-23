pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import Clavis.Keyboard
import qs.Common
import qs.Services
import qs.Modules.Dock
import qs.Widgets.common

PanelWindow {
    id: root
    required property var targetScreen
    required property double initialWindowId
    required property int initialStep
    required property bool commitOnMetaRelease
    signal dismissed
    screen: targetScreen
    color: Appearance.colors.colSurfaceContainer
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.namespace: "clavis-window-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var windows: []
    property string previewConsumer: ""
    property int selected: 0
    readonly property real gap: 18
    // Choose the largest cards that fit every window without scrolling.
    readonly property var grid: {
        const count = Math.max(1, windows.length);
        let best = {
            columns: 1,
            rows: count,
            cardWidth: 0
        };
        for (let columns = 1; columns <= count; ++columns) {
            const rows = Math.ceil(count / columns);
            const availableHeight = (gridArea.height - (rows - 1) * gap) / rows;
            const widthByHeight = availableHeight >= 138 ? (availableHeight - 38) * 1.6 : availableHeight
                                                           * 160 / 138;
            const cardWidth = Math.max(1, Math.min(560, widthByHeight, (gridArea.width - (columns - 1) * gap)
                                                   / columns));
            if (cardWidth > best.cardWidth)
                best = {
                    columns: columns,
                    rows: rows,
                    cardWidth: cardWidth
                };
        }
        return best;
    }
    readonly property real cardHeight: grid.cardWidth >= 160 ? grid.cardWidth / 1.6 + 38 : grid.cardWidth
                                                               * 138 / 160

    function syncWindows() {
        const selectedId = windows[selected] ? windows[selected].id : null;
        windows = Niri.searchWindows("").sort((a, b) => a.id - b.id);
        const retained = windows.findIndex(window => window.id === selectedId);
        selected = retained >= 0 ? retained : Math.max(0, Math.min(selected, windows.length - 1));
        if (previewConsumer)
            WindowPreviewService.setTargets(previewConsumer, windows.map(window => String(window.id)));
    }
    function activate(index) {
        const window = windows[index];
        if (!window || DockService.focusWindow(window.id, screen ? screen.name : ""))
            dismissed();
    }
    function moveSelection(delta) {
        if (windows.length)
            selected = (selected + delta + windows.length) % windows.length;
    }
    function previewCount() {
        return windows.filter(window => {
            const frame = WindowPreviewService.frameFor(window.id);
            return frame && frame.hasFrame;
        }).length;
    }
    Component.onCompleted: {
        previewConsumer = WindowPreviewService.createConsumer();
        syncWindows();
        selected = Math.max(0, windows.findIndex(window => window.id === initialWindowId));
        moveSelection(initialStep);
        Qt.callLater(() => keyboard.forceActiveFocus());
    }
    Component.onDestruction: WindowPreviewService.release(previewConsumer)
    Connections {
        target: Niri
        function onWindowsChanged() {
            root.syncWindows();
        }
    }

    // Query only modifier state while this overlay owns keyboard focus. This
    // also catches a quick Win release before the layer surface was mapped.
    ShortcutRecorder {
        id: modifierState
        enabled: false
    }
    Timer {
        property int startupSamples: 0
        property bool sawMeta: false
        interval: 20
        repeat: true
        running: root.commitOnMetaRelease && keyboard.Window.active
        onRunningChanged: {
            startupSamples = 0;
            sawMeta = false;
        }
        onTriggered: {
            const metaHeld = !!(modifierState.currentModifiers() & Qt.MetaModifier);
            sawMeta = sawMeta || metaHeld;
            // Allow the initial Wayland enter/modifiers events to settle when
            // Win was released before this surface acquired keyboard focus.
            if (!metaHeld && (sawMeta || ++startupSamples >= 9))
                root.activate(root.selected);
        }
    }

    Image {
        anchors.fill: parent
        source: WallpaperService.wallpaperForScreen(root.screen ? root.screen.name : "")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: Appearance.applyAlpha(Appearance.colors.colSurfaceContainer, 0.88)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }
    Item {
        id: keyboard
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.dismissed();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.activate(root.selected);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                root.moveSelection(event.modifiers & Qt.ShiftModifier ? -1 : 1);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                root.moveSelection(-1);
            else if (event.key === Qt.Key_Down)
                root.moveSelection(root.grid.columns);
            else if (event.key === Qt.Key_Up)
                root.moveSelection(-root.grid.columns);
            else
                return;
            event.accepted = true;
        }
        Text {
            x: 40
            y: 24
            text: qsTranslate("ShortcutMap", "Windows")
            font.family: Fonts.ui
            font.pixelSize: 22
            color: Appearance.colors.colOnSurface
        }
        IconButton {
            focusPolicy: Qt.NoFocus
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            iconName: "close"
            accessibleName: qsTranslate("ShortcutMap", "Close")
            onClicked: root.dismissed()
        }
        Item {
            id: gridArea
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: 40
            anchors.topMargin: 82
            anchors.bottomMargin: 38
            Repeater {
                model: root.windows
                delegate: DockWindowCard {
                    id: card
                    required property int index
                    required property var modelData
                    readonly property int row: Math.floor(index / root.grid.columns)
                    readonly property int rowCount: Math.min(root.grid.columns, root.windows.length - row
                                                             * root.grid.columns)

                    x: (gridArea.width - rowCount * width - (rowCount - 1) * root.gap) / 2 + (index
                                                                                              % root.grid.columns)
                       * (width + root.gap)
                    y: (gridArea.height - root.grid.rows * root.cardHeight - (root.grid.rows - 1) * root.gap)
                       / 2 + row * (root.cardHeight + root.gap)
                    width: root.grid.cardWidth
                    windowData: modelData
                    focusPolicy: Qt.NoFocus
                    applicationName: modelData.appName || modelData.appId
                    applicationIcon: modelData.iconPath || ""
                    showThumbnail: true
                    capture: {
                        const revision = WindowPreviewService.revision;
                        return WindowPreviewService.captureFor(modelData.id);
                    }
                    previewFrame: {
                        const revision = WindowPreviewService.revision;
                        return WindowPreviewService.frameFor(modelData.id);
                    }
                    onActivated: root.activate(index)
                    onCloseRequested: DockService.closeWindow(modelData.id)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 10
                        border.width: root.selected === card.index ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }
}
