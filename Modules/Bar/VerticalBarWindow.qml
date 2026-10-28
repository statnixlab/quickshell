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
        visible: root.autoHidden
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
    readonly property real lengthPadding: Math.min(PersonalizationConfig.barLengthPadding, Math.max(0, (height
                                                                                                        - content.minimumLength)
                                                                                                    / 2))

    implicitWidth: surfaceThickness
    color: "transparent"
    // Revealing the bar in overview must not push maximized previews sideways.
    exclusiveZone: PersonalizationConfig.barOverlay || root.autoHidden || (Niri.inOverview
                                                                           && MaximizedWindowService.hasMaximizedWindow(
                                                                               root.modelData)) ? 0 :
                                                                                                  exclusiveThickness
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-bar-vertical"
    WlrLayershell.exclusionMode: ExclusionMode.Normal

    BarAxis {
        id: axis

        edge: root.edge
    }

    anchors {
        top: true
        bottom: true
        left: axis.isLeft
        right: axis.isRight
    }

    Item {
        id: visualBand
        visible: root.showContents

        x: axis.isLeft ? root.outerEdgeMargin : Sizes.barShadowBuffer
        y: root.lengthPadding
        width: root.visualThickness
        height: Math.max(0, parent.height - 2 * root.lengthPadding)

        VerticalBarContent {
            id: content

            anchors.fill: parent
            screen: root.modelData
            axis: axis
            surfaceOffset: Qt.point(axis.isLeft ? 0 : root.modelData.width - root.width, 0)
        }
    }

    // Separate geometry-clipped surfaces provide smooth blur for each pill.
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
