import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Services

// A geometry-clipped background uses Niri's antialiased rounding shader.
// Do not attach a wl_region: integer region scanlines bypass that smooth clip.
PanelWindow {
    id: root

    required property Item sourceItem
    required property var targetScreen
    property string edge: "top"
    property bool attached: false
    property bool active: true
    readonly property var sourceWindow: sourceItem ? sourceItem.Window.window : null
    property point sourcePosition: Qt.point(0, 0)
    property bool positionReady: false

    function updatePosition() {
        if (!sourceWindow || !sourceItem || sourceItem.width <= 0 || sourceItem.height <= 0)
            return;
        sourcePosition = sourceItem.mapToItem(sourceWindow.contentItem, 0, 0);
        positionReady = true;
        requestFrame();
    }

    function requestFrame() {
        // This window has no painted content. Commit geometry changes even
        // when the scene graph otherwise has no new damage to draw.
        const window = root.contentItem.Window.window;
        if (window && window.visible)
            window.update();
    }

    onSourceWindowChanged: Qt.callLater(updatePosition)
    onImplicitWidthChanged: Qt.callLater(updatePosition)
    onImplicitHeightChanged: Qt.callLater(updatePosition)
    onVisibleChanged: Qt.callLater(updatePosition)
    Component.onCompleted: Qt.callLater(updatePosition)

    TransformWatcher {
        a: root.sourceWindow ? root.sourceWindow.contentItem : null
        b: root.sourceItem
        onTransformChanged: root.updatePosition()
    }

    screen: targetScreen
    visible: active && BlurService.enabled && positionReady && sourceWindow && sourceWindow.visible
             && sourceItem.visible && sourceItem.width > 0 && sourceItem.height > 0
    color: "transparent"
    implicitWidth: Math.max(1, Math.floor(sourceItem.width))
    implicitHeight: Math.max(1, Math.floor(sourceItem.height))
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "clavis-keystone-backdrop-" + (attached ? edge : "pill")
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.ceil(root.sourcePosition.y)
        left: Math.ceil(root.sourcePosition.x)
    }
    mask: Region {}
}
