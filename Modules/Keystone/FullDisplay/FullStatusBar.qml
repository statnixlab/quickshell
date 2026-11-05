pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Modules.Keystone.ClockContent
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.Tray
import qs.Modules.Bar.Media
import qs.Modules.Bar.SysMonitor

Item {
    id: root

    required property var screen
    required property string edge
    readonly property string popupEdge: edge
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool clockHovered: clockHover.hovered
    readonly property bool hovered: mainHover.hovered
    readonly property alias clockItem: clock
    readonly property real clockLength: root.vertical ? PersonalizationConfig.keystoneCompactLength : Math.min(
                                                            PersonalizationConfig.keystoneCompactLength,
                                                            clock.preferredHorizontalWidth)
    readonly property var bar: BarLayoutService.barFor(root.screen, root.edge)
    readonly property real availableLength: !root.vertical && root.bar ? Math.max(
                                                                             PersonalizationConfig.keystoneCompactLength,
                                                                             root.screen.width - 2 * (
                                                                                 root.bar.horizontalInset
                                                                                 + Math.max(
                                                                                     root.bar.minimumLeadingWidth,
                                                                                     root.bar.minimumTrailingWidth)
                                                                                 + BarLayoutService.clearance)) :
                                                                         (root.vertical ? root.screen.height :
                                                                                          root.screen.width)
    // Reserve equal space on both sides so changing module sizes never
    // pushes the clock away from the main island's geometric centre.
    readonly property real preferredLength: root.clockLength + 2 * (Math.max(leadingLane.preferredExtent,
                                                                             trailingLane.preferredExtent)
                                                                    + PersonalizationConfig.keystoneInsetPadding
                                                                    + 12)
    readonly property real contentLength: root.vertical ? preferredLength : Math.min(preferredLength,
                                                                                     availableLength)

    Component.onCompleted: BarLayoutService.registerKeystone(root)
    Component.onDestruction: BarLayoutService.unregisterKeystone(root)

    signal clockClicked(int button)
    signal mediaRequested

    HoverHandler {
        id: mainHover
    }

    ClockContent {
        id: clock
        anchors.centerIn: parent
        width: root.vertical ? PersonalizationConfig.keystoneThickness : root.clockLength
        height: root.vertical ? PersonalizationConfig.keystoneCompactLength :
                                PersonalizationConfig.keystoneThickness
        edge: root.edge
        player: MediaManager.active

        HoverHandler {
            id: clockHover
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => root.clockClicked(mouse.button)
        }
    }

    StatusLane {
        id: leadingLane
        items: PersonalizationConfig.keystoneFullLeading
        x: root.vertical ? 0 : PersonalizationConfig.keystoneInsetPadding
        y: root.vertical ? PersonalizationConfig.keystoneInsetPadding : 0
        width: root.vertical ? root.width : Math.max(0, clock.x - PersonalizationConfig.keystoneInsetPadding
                                                     - 12)
        height: root.vertical ? Math.max(0, clock.y - PersonalizationConfig.keystoneInsetPadding - 12) :
                                root.height

    }

    StatusLane {
        id: trailingLane
        items: PersonalizationConfig.keystoneFullTrailing
        x: root.vertical ? 0 : clock.x + clock.width + 12
        y: root.vertical ? clock.y + clock.height + 12 : 0
        width: root.vertical ? root.width : Math.max(0, root.width - x
                                                     - PersonalizationConfig.keystoneInsetPadding)
        height: root.vertical ? Math.max(0, root.height - y - PersonalizationConfig.keystoneInsetPadding) :
                                root.height
        trailing: true
    }

    component StatusLane: Item {
        id: lane
        required property var items
        property bool trailing: false
        property int itemRevision: 0
        // This width stays independent of media's allocated width. Otherwise
        // shrinking the title feeds back into the island's own size request.
        readonly property real preferredExtent: root.vertical ? itemsLayout.implicitHeight : measuredWidth(
                                                                    false)
        readonly property real nonMediaExtent: measuredWidth(true)
        readonly property real mediaAvailableWidth: Math.max(0, lane.width - nonMediaExtent)
        clip: !root.vertical

        function measuredWidth(excludeMedia) {
            const revision = lane.itemRevision;
            let extent = Math.max(0, statusItems.count - 1) * PersonalizationConfig.keystoneItemSpacing;
            for (let index = 0; index < statusItems.count; ++index) {
                const loader = statusItems.itemAt(index);
                if (!loader || !loader.item)
                    continue;
                if (loader.modelData === "media") {
                    if (!excludeMedia)
                        extent += loader.item.preferredHorizontalWidth;
                } else {
                    extent += loader.item.implicitWidth;
                }
            }
            return extent;
        }
        readonly property var displayItems: {
            const result = [];
            for (let index = 0; index < items.length; ++index) {
                const current = items[index];
                const next = items[index + 1];
                const metricPair = (current === "cpuTemperature" && next === "memoryUsage") || (current
                                                                                                === "memoryUsage"
                                                                                                && next
                                                                                                === "cpuTemperature");
                if (!root.vertical && metricPair && PersonalizationConfig.keystoneThickness >= 36) {
                    result.push("cpuMemory");
                    ++index;
                } else {
                    result.push(current);
                }
            }
            return result;
        }

        GridLayout {
            id: itemsLayout
            x: root.vertical ? (lane.width - width) / 2 : lane.trailing ? 0 : Math.max(0, lane.width - width)
            y: root.vertical ? (lane.trailing ? Math.max(0, lane.height - height) : 0) : (lane.height - height)
                               / 2
            columns: root.vertical ? 1 : Math.max(1, lane.displayItems.length)
            rowSpacing: PersonalizationConfig.keystoneItemSpacing
            columnSpacing: PersonalizationConfig.keystoneItemSpacing

            Repeater {
                id: statusItems
                model: lane.displayItems
                onItemAdded: lane.itemRevision += 1
                onItemRemoved: lane.itemRevision += 1
                delegate: Loader {
                    id: statusLoader
                    required property string modelData
                    onItemChanged: lane.itemRevision += 1
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.vertical ? root.width : implicitWidth
                    sourceComponent: modelData === "cpuMemory" ? metricStack : ["networkSpeed",
                                                                                "cpuTemperature",
                                                                                "memoryUsage"].indexOf(
                                                                     modelData) >= 0 ? metricStatus :
                                                                                       modelData === "tray"
                                                                                       ? tray : modelData
                                                                                         === "workspaces"
                                                                                         ? workspaces :
                                                                                           modelData
                                                                                           === "media"
                                                                                           ? media : modelData
                                                                                             === "systemMonitor"
                                                                                             ? systemMonitor :
                                                                                               status

                    Component {
                        id: workspaces
                        Workspaces {
                            contentThickness: PersonalizationConfig.keystoneThickness
                            dotSize: Sizes.keystoneIconSize * 0.6
                            activeLength: Sizes.keystoneIconSize * 1.6
                            screenName: root.screen ? root.screen.name : ""
                            vertical: root.vertical
                            backgroundVisible: false
                        }
                    }

                    Component {
                        id: tray
                        Tray {
                            contentThickness: PersonalizationConfig.keystoneThickness
                            iconSize: Sizes.keystoneIconSize
                            screen: root.screen
                            edge: root.edge
                            vertical: root.vertical
                            barVisualItem: root
                            backgroundVisible: false
                        }
                    }

                    Component {
                        id: media
                        MediaBar {
                            contentThickness: PersonalizationConfig.keystoneThickness
                            controlSize: Sizes.keystoneControlSize
                            iconSize: Sizes.keystoneIconSize
                            vertical: root.vertical
                            maximumTitleWidth: root.vertical ? 120 : 180
                            availableWidth: root.vertical ? Infinity : lane.mediaAvailableWidth
                            backgroundVisible: false
                        }
                    }

                    Component {
                        id: systemMonitor
                        SysMonitor {
                            contentThickness: PersonalizationConfig.keystoneThickness
                            controlSize: Sizes.keystoneControlSize
                            iconSize: Sizes.keystoneIconSize * 0.75
                            showValues: PersonalizationConfig.keystoneFullShowMonitorValues
                            vertical: root.vertical
                            ownerId: "keystone-long:" + String(root.screen ? root.screen.name : "default") + (
                                         lane.trailing ? ":trailing" : ":leading")
                            backgroundVisible: false
                        }
                    }

                    Component {
                        id: metricStack
                        Item {
                            implicitWidth: Math.max(cpuMetric.implicitWidth, memoryMetric.implicitWidth)
                            implicitHeight: cpuMetric.implicitHeight + memoryMetric.implicitHeight

                            Column {
                                anchors.fill: parent
                                spacing: 0

                                FullMetricItem {
                                    id: cpuMetric
                                    width: parent.width
                                    metric: "cpuTemperature"
                                    screen: root.screen
                                    compact: true
                                }

                                FullMetricItem {
                                    id: memoryMetric
                                    width: parent.width
                                    metric: "memoryUsage"
                                    screen: root.screen
                                    compact: true
                                }
                            }
                        }
                    }

                    Component {
                        id: metricStatus
                        FullMetricItem {
                            metric: statusLoader.modelData
                            screen: root.screen
                            vertical: root.vertical
                        }
                    }

                    Component {
                        id: status
                        FullStatusItem {
                            maximumNameWidth: root.vertical ? 96 : 160
                            itemId: statusLoader.modelData
                            edge: root.edge
                            ownerId: "keystone-long:" + String(root.screen ? root.screen.name : "default") + (
                                         lane.trailing ? ":trailing" : ":leading")
                            screen: root.screen
                            onMediaRequested: root.mediaRequested()
                        }
                    }
                }
            }
        }
    }
}
