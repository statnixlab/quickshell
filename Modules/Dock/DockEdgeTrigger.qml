import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property string edge
    required property string dragMimeType
    // Length of the centered stretch that reacts; 0 makes the whole edge react.
    property real activeLength: 0
    readonly property bool horizontal: edge === "bottom"
    readonly property int thickness: 3
    readonly property bool hovered: pointer.hovered
    readonly property bool containsDrag: drop.containsDrag

    signal activated

    // Keep a stable input surface at the physical screen edge. It must not
    // move, resize or unmap when Dock icons animate or a window is minimized.
    implicitWidth: thickness
    implicitHeight: thickness
    anchors.left: horizontal || edge === "left"
    anchors.right: horizontal || edge === "right"
    anchors.top: !horizontal
    anchors.bottom: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clavis-dock-edge-trigger"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Narrow the input region instead of resizing the surface, which must stay put.
    mask: Region {
        item: activeArea
    }

    Item {
        id: activeArea
        readonly property real length: root.activeLength > 0 ? Math.min(root.activeLength, root.horizontal
                                                                        ? root.width : root.height) : (
                                                                   root.horizontal ? root.width : root.height)
        width: root.horizontal ? length : root.width
        height: root.horizontal ? root.height : length
        x: root.horizontal ? (root.width - width) / 2 : 0
        y: root.horizontal ? 0 : (root.height - height) / 2
    }

    HoverHandler {
        id: pointer
        onHoveredChanged: {
            if (hovered)
                root.activated();
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        onEntered: drag => {
            drag.accepted = drag.hasUrls || drag.formats.indexOf(root.dragMimeType) >= 0;
            if (drag.accepted)
                root.activated();
        }
    }
}
