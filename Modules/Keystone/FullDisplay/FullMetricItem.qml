import QtQuick
import QtQuick.Window
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    required property string metric
    required property var screen
    property bool vertical: false
    property bool compact: false
    readonly property bool inlineNetwork: !vertical && PersonalizationConfig.keystoneThickness < 36
    readonly property bool compactContent: compact || (!vertical && PersonalizationConfig.keystoneThickness
                                                       >= 36)
    readonly property real valueFontSize: compactContent ? 11 : 12
    readonly property real iconTextSpacing: 2
    readonly property real speedRowWidth: metricIconSize + iconTextSpacing + speedMetrics.width
    readonly property real metricIconSize: compactContent ? Math.min(Sizes.keystoneIconSize * 0.7, (
                                                                         PersonalizationConfig.keystoneThickness
                                                                         - 2) / 2) : Sizes.keystoneIconSize
                                                            * 0.9
    readonly property string consumerId: "keystone-metric:" + String(root)
    readonly property bool networkSpeed: metric === "networkSpeed"
    readonly property bool cpuTemperature: metric === "cpuTemperature"
    readonly property string moduleName: networkSpeed ? "network" : cpuTemperature ? "cpu" : "memory"
    readonly property bool monitoringActive: visible && (!root.Window.window || root.Window.window.visible)
    readonly property bool dataReady: SystemMonitorService.state === "ready"
    readonly property var cpu: SystemMonitorService.cpu || ({})
    readonly property var memory: SystemMonitorService.memory || ({})
    readonly property var network: SystemMonitorService.network || ({})
    // Follow the default interface; summing physical and tunnel interfaces
    // would count proxy/VPN traffic twice.
    readonly property var activeNetwork: (network.interfaces || []).find(entry => entry.name
                                                                                  === network.defaultInterface)
                                         || ({})
    readonly property real temperature: Format.isNumber(cpu.packageTemperatureCelsius)
                                        ? cpu.packageTemperatureCelsius : Format.isNumber(
                                              cpu.temperatureCelsius) ? cpu.temperatureCelsius : NaN
    readonly property string label: networkSpeed ? qsTranslate("PersonalizationConfig", "Network speed") :
                                                   cpuTemperature ? qsTranslate("PersonalizationConfig",
                                                                                "CPU temperature") :
                                                                    qsTranslate("PersonalizationConfig",
                                                                                "Memory usage")
    readonly property string downloadText: Format.bytesPerSecond(dataReady
                                                                 ? activeNetwork.downloadBytesPerSecond :
                                                                   undefined)
    readonly property string uploadText: Format.bytesPerSecond(dataReady ? activeNetwork.uploadBytesPerSecond :
                                                                           undefined)
    readonly property string valueText: cpuTemperature ? Format.temperature(dataReady ? temperature :
                                                                                        undefined,
                                                                            UiPreferences.systemTemperatureUnit
                                                                            === "fahrenheit") : Format.percent(
                                                             dataReady ? memory.usagePercent : undefined, 0)
    readonly property string tooltipText: !dataReady ? label + "\n" + SystemMonitorService.statusText :
                                                       networkSpeed ? qsTr("Download: %1\nUpload: %2").arg(
                                                                          downloadText).arg(uploadText) :
                                                                      cpuTemperature ? qsTr(
                                                                                           "CPU temperature: %1").arg(
                                                                                           valueText) : qsTr(
                                                                                           "Memory: %1 / %2 (%3)").arg(
                                                                                           Format.bytes(
                                                                                               memory.usedBytes)).arg(
                                                                                           Format.bytes(
                                                                                               memory.totalBytes)).arg(
                                                                                           valueText)

    function syncConsumer() {
        SystemMonitorService.setConsumerModules(consumerId, monitoringActive ? [moduleName] : []);
    }

    onMonitoringActiveChanged: syncConsumer()
    onModuleNameChanged: syncConsumer()
    Component.onCompleted: syncConsumer()
    Component.onDestruction: SystemMonitorService.clearConsumer(consumerId)

    // Reserve the same width between samples so changing rates do not move the clock.
    implicitWidth: networkSpeed ? speedRowWidth * (inlineNetwork ? 2 : 1) + (inlineNetwork ? 8 : 0) + 3 :
                                  valueMetrics.width + metricIconSize + iconTextSpacing + 3
    implicitHeight: compact ? Math.max(17, metricIconSize) : vertical ? Math.max(34, networkSpeed
                                                                                 ? networkLayout.implicitHeight :
                                                                                   0) : PersonalizationConfig.keystoneThickness

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: tooltipText
    Accessible.onPressAction: root.openDetails()

    function openDetails() {
        if (networkSpeed) {
            WidgetState.quickSettingsScreenName = screen ? screen.name : "";
            WidgetState.quickSettingsView = "network";
            WidgetState.quickSettingsOpen = true;
        } else {
            WidgetState.sidebarScreenName = screen ? screen.name : "";
            WidgetState.dashboardSidebarView = "info";
            WidgetState.dashboardSidebarOpen = true;
        }
    }

    TextMetrics {
        id: speedMetrics
        font.family: Fonts.numeric
        font.pixelSize: root.valueFontSize
        text: "999.9 MiB/s"
    }

    TextMetrics {
        id: valueMetrics
        font.family: Fonts.numeric
        font.pixelSize: root.valueFontSize
        text: root.compact || root.cpuTemperature ? "100 °F" : "100%"
    }

    Grid {
        id: networkLayout
        anchors.centerIn: parent
        visible: root.networkSpeed
        columns: root.inlineNetwork ? 2 : 1
        columnSpacing: root.inlineNetwork ? 8 : 0
        rowSpacing: 0
        Row {
            spacing: root.iconTextSpacing
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_downward"
                iconSize: root.metricIconSize
                fill: 1
                color: pointer.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: speedMetrics.width
                horizontalAlignment: Text.AlignLeft
                text: root.downloadText
                font.family: Fonts.numeric
                font.pixelSize: root.valueFontSize
                color: pointer.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
            }
        }
        Row {
            spacing: root.iconTextSpacing
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_upward"
                iconSize: root.metricIconSize
                fill: 1
                color: pointer.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: speedMetrics.width
                horizontalAlignment: Text.AlignLeft
                text: root.uploadText
                font.family: Fonts.numeric
                font.pixelSize: root.valueFontSize
                color: pointer.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
            }
        }
    }

    Row {
        anchors.centerIn: parent
        visible: !root.networkSpeed
        spacing: root.iconTextSpacing
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.cpuTemperature ? "thermostat" : "memory_alt"
            iconSize: root.metricIconSize
            fill: 1
            color: pointer.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: valueMetrics.width
            horizontalAlignment: Text.AlignLeft
            text: root.valueText
            font.family: Fonts.numeric
            font.pixelSize: root.valueFontSize
            color: pointer.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDetails()
    }

    PopupToolTip {
        extraVisibleCondition: pointer.containsMouse
        text: root.tooltipText
        textFormat: Text.PlainText
    }
}
