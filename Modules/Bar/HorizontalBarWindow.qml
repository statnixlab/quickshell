import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import qs.Common
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    required property var modelData

    readonly property bool detectedAutoHidden: MaximizedWindowService.coversScreen(root.modelData)
    property bool heldAutoHidden: detectedAutoHidden
    readonly property bool autoHidden: LaunchpadService.chromeHold ? heldAutoHidden : detectedAutoHidden
    readonly property bool showContents: !autoHidden || MaximizedWindowService.revealed(root.modelData)
    visible: root.showContents

    onDetectedAutoHiddenChanged: {
        if (!LaunchpadService.chromeHold)
            heldAutoHidden = detectedAutoHidden;
    }
    Connections {
        target: LaunchpadService
        function onChromeHoldChanged() {
            root.heldAutoHidden = root.detectedAutoHidden;
        }
    }

    property var edgeSensor: BarEdgeTrigger {
        screen: root.modelData
        edge: root.edge
        visible: root.autoHidden && root.edge !== "top"
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                hideDelay.stop();
                MaximizedWindowService.setHovered(root.modelData, "bar", true);
            } else {
                hideDelay.restart();
            }
        }
    }

    Timer {
        id: hideDelay
        interval: 500
        onTriggered: MaximizedWindowService.setHovered(root.modelData, "bar", false)
    }

    Component.onDestruction: MaximizedWindowService.setHovered(root.modelData, "bar", false)

    required property string edge
    readonly property real visualThickness: Sizes.barVisualThickness
    readonly property real outerEdgeMargin: PersonalizationConfig.barEdgeMargin
    // Shadow pixels need surface space, but must not reserve desktop space.
    readonly property real surfaceThickness: outerEdgeMargin + visualThickness + Sizes.barShadowBuffer
    readonly property real exclusiveThickness: Math.max(0, outerEdgeMargin + visualThickness
                                                        + PersonalizationConfig.barExclusiveZoneOffset)
    readonly property real lengthPadding: Math.min(PersonalizationConfig.barLengthPadding, Math.max(0, (width
                                                                                                        - content.minimumLength)
                                                                                                    / 2))

    implicitHeight: surfaceThickness
    color: "transparent"
    // Revealing the bar in overview must not push maximized previews down.
    exclusiveZone: PersonalizationConfig.barOverlay || root.autoHidden || (Niri.inOverview
                                                                           && MaximizedWindowService.hasMaximizedWindow(
                                                                               root.modelData)) ? 0 :
                                                                                                  exclusiveThickness
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-bar-horizontal"
    WlrLayershell.exclusionMode: ExclusionMode.Normal

    BarAxis {
        id: axis

        edge: root.edge
    }

    anchors {
        left: true
        right: true
        top: axis.isTop
        bottom: axis.isBottom
    }

    Item {
        id: visualBand
        visible: root.showContents

        x: root.lengthPadding
        y: axis.isTop ? root.outerEdgeMargin : Sizes.barShadowBuffer
        width: Math.max(0, parent.width - 2 * root.lengthPadding)
        height: root.visualThickness

        HorizontalBarContent {
            id: content

            anchors.fill: parent
            screen: root.modelData
            axis: axis
        }
    }

    // wl_region blur outlines are integer logical pixels. On HiDPI outputs
    // they add a stepped second edge beneath the antialiased translucent pills.
    // Explicitly opt out rather than leaving a compositor layer rule in control.
    BackgroundEffect.blurRegion: Region {}

    mask: Region {
        Region {
            item: root.autoHidden ? visualBand : null
        }

        Region {
            item: root.autoHidden ? null : content.leadingInputRegionItem
        }

        Region {
            item: root.autoHidden ? null : content.trailingInputRegionItem
        }
    }
}
