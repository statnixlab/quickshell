import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property string edge
    required property string dragMimeType
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
