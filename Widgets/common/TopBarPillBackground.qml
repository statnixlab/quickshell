import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services

Item {
    id: root

    property color fillColor: BlurService.backgroundColor(Appearance.colors.colLayer0)
    property real cornerRadius: height / 2
    property real shadowPadding: Sizes.barShadowBuffer
    property bool shadowCached: true
    property bool shadowEnabled: true
    readonly property string contextualEdge: findContextEdge(root.parent)

    function findContextEdge(item) {
        let current = item;
        while (current !== null && current !== undefined) {
            if (current.popupEdge !== undefined)
                return current.popupEdge;
            current = current.parent;
        }
        return "top";
    }

    Rectangle {
        id: shadowSource

        anchors.fill: parent
        color: root.fillColor
        radius: root.cornerRadius
        antialiasing: true
        visible: false
    }

    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        visible: root.shadowEnabled
        radius: 16
        samples: 32
        transparentBorder: true
        color: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
        horizontalOffset: root.contextualEdge === "left" ? 3 : root.contextualEdge === "right" ? -3 : 0
        verticalOffset: root.contextualEdge === "top" ? 3 : root.contextualEdge === "bottom" ? -3 : 0
        cached: root.shadowCached
    }

    ShaderEffect {
        // Keep the smooth physical-pixel fringe outside the content clip.
        x: -1
        y: -1
        width: parent.width + 2
        height: parent.height + 2
        property vector2d resolution: Qt.vector2d(width, height)
        property color fillColor: root.fillColor
        property real cornerRadius: root.cornerRadius
        fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/common/qsb/rounded_panel.frag.qsb")
    }
}
