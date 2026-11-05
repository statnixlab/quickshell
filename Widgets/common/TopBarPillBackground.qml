pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property color fillColor: BlurService.backgroundColor(Appearance.colors.colLayer0)
    property real cornerRadius: height / 2
    property real shadowPadding: 24
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

    Item {
        x: -root.shadowPadding
        y: -root.shadowPadding
        width: root.width + 2 * root.shadowPadding
        height: root.height + 2 * root.shadowPadding
        // Match Keystone: compose an opaque surface and its shadow, then apply
        // the background alpha once so the shadow cannot darken the interior.
        opacity: root.fillColor.a
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: root.shadowEnabled
            shadowBlur: 1
            blurMax: 16
            shadowColor: Appearance.colors.colShadow
            shadowHorizontalOffset: root.contextualEdge === "left" ? 4 : root.contextualEdge === "right" ? -4 :
                                                                                                           0

            shadowVerticalOffset: root.contextualEdge === "top" ? 4 : root.contextualEdge === "bottom" ? -4 :
                                                                                                         0

            autoPaddingEnabled: true
        }

        ShaderEffect {
            // Keep the smooth physical-pixel fringe outside the content clip.
            x: root.shadowPadding - 1
            y: root.shadowPadding - 1
            width: root.width + 2
            height: root.height + 2
            property vector2d resolution: Qt.vector2d(width, height)
            property color fillColor: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 1)
            property real cornerRadius: root.cornerRadius
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/common/qsb/rounded_panel.frag.qsb")
        }
    }
}
