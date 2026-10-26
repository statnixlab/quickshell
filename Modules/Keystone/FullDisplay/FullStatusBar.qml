pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    // Reserve equal space on both sides so changing module sizes never
    // pushes the clock away from the main island's geometric centre.
    readonly property real contentLength: PersonalizationConfig.keystoneCompactLength + 2 * (Math.max(
                                                                                                 leadingLane.contentExtent,
                                                                                                 trailingLane.contentExtent)
                                                                                             + PersonalizationConfig.keystoneInsetPadding
                                                                                             + 12)

    signal clockClicked(int button)
    signal mediaRequested

    HoverHandler {
        id: mainHover
    }

    ClockContent {
        id: clock
        anchors.centerIn: parent
        width: root.vertical ? PersonalizationConfig.keystoneThickness :
                               PersonalizationConfig.keystoneCompactLength
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
        readonly property var displayItems: {
            const result = [];
            for (let index = 0; index < items.length; ++index) {
                const current = items[index];
                const next = items[index + 1];
                const metricPair = (current === "cpuTemperature" && next === "memoryUsage") || (current
                                                                                                === "memoryUsage"
                                                                                                && next
                                                                                                === "cpuTemperature");
                if (!root.vertical && metricPair) {
                    result.push("cpuMemory");
                    ++index;
                } else {
                    result.push(current);
                }
            }
            return result;
        }
        readonly property real contentExtent: root.vertical ? itemsLayout.implicitHeight :
                                                              itemsLayout.implicitWidth

        GridLayout {
            id: itemsLayout
            x: root.vertical ? (lane.width - width) / 2 : lane.trailing ? Math.max(0, lane.width - width) : 0
            y: root.vertical ? (lane.trailing ? Math.max(0, lane.height - height) : 0) : (lane.height - height)
                               / 2
            columns: root.vertical ? 1 : Math.max(1, lane.displayItems.length)
            rowSpacing: PersonalizationConfig.keystoneItemSpacing
            columnSpacing: PersonalizationConfig.keystoneItemSpacing

            Repeater {
                model: lane.displayItems
                delegate: Loader {
                    id: statusLoader
                    required property string modelData
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
                            screenName: root.screen ? root.screen.name : ""
                            vertical: root.vertical
                            backgroundVisible: false
                        }
                    }

                    Component {
                        id: tray
                        Tray {
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
                            vertical: root.vertical
                            maximumTitleWidth: root.vertical ? 120 : 180
                            backgroundVisible: false
                        }
                    }

                    Component {
                        id: systemMonitor
                        SysMonitor {
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
