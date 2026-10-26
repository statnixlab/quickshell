import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services as Services
import qs.Widgets.common
import "../../../Common/functions/SystemFormat.js" as Format

TopBarPill {
    id: root

    property var screen: null
    property bool vertical: false

    // The network button already animates its width. Follow those frames
    // directly instead of applying a second, lagging size animation.
    animateResize: {
        for (let index = 0; index < componentRepeater.count; ++index) {
            const loader = componentRepeater.itemAt(index);
            if (loader && loader.modelData === "network" && loader.resizing)
                return false;
        }
        return true;
    }

    function componentValue(componentId) {
        if (Services.PersonalizationConfig.barShowNames) {
            if (componentId === "bluetooth")
                return Services.BluetoothService.connectedName || "";
            if (componentId === "network" && root.vertical)
                return Services.NetworkService.activeConnection || "";
        }
        if (!Services.PersonalizationConfig.barShowValues)
            return "";
        switch (componentId) {
        case "volume":
            return Format.percent(Services.Volume.outputAvailable ? Services.Volume.sinkVolume * 100 : undefined,
                                  0);
        case "microphone":
            return Format.percent(Services.Volume.inputAvailable ? Services.Volume.sourceVolume * 100 : undefined,
                                  0);
        case "brightness":
            const monitor = Services.Brightness.getMonitorForScreen(root.screen);
            return Format.percent((monitor ? monitor.brightness : Services.Brightness.brightnessValue) * 100,
                                  0);
        default:
            return "";
        }
    }

    function componentFor(componentId) {
        switch (componentId) {
        case "network":
            return networkComponent;
        case "bluetooth":
            return bluetoothComponent;
        case "brightness":
            return brightnessComponent;
        case "volume":
            return volumeComponent;
        case "microphone":
            return microphoneComponent;
        case "battery":
            return batteryComponent;
        case "settings":
            return settingsComponent;
        case "power":
            return powerComponent;
        default:
            return null;
        }
    }

    implicitHeight: vertical ? layout.implicitHeight + 2 * (root.pillPadding + 2) : root.pillThickness
    implicitWidth: vertical ? root.bandThickness : layout.implicitWidth + 2 * root.pillPadding

    GridLayout {
        id: layout

        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 4
        columns: root.vertical ? 1 : 8

        Repeater {
            id: componentRepeater
            model: Services.PersonalizationConfig.quickSettingsComponents

            GridLayout {
                id: controlGroup
                required property string modelData
                readonly property string valueText: root.componentValue(modelData)
                readonly property bool nameLabel: modelData === "network" || modelData === "bluetooth"
                columns: root.vertical ? 1 : 2
                rowSpacing: 4
                columnSpacing: 6

                Loader {
                    id: componentLoader
                    Layout.alignment: Qt.AlignCenter
                    sourceComponent: root.componentFor(controlGroup.modelData)
                }

                Item {
                    visible: controlGroup.valueText !== ""
                    readonly property bool rotated: root.vertical && controlGroup.nameLabel
                    readonly property real labelWidth: Math.min(120, valueLabel.implicitWidth)
                    implicitWidth: rotated ? valueLabel.implicitHeight : labelWidth
                    implicitHeight: rotated ? labelWidth : valueLabel.implicitHeight
                    Layout.alignment: Qt.AlignCenter
                    Text {
                        id: valueLabel
                        anchors.centerIn: parent
                        width: parent.labelWidth
                        rotation: parent.rotated ? (Services.PersonalizationConfig.barPosition === "right"
                                                    ? 90 : -90) : 0
                        text: controlGroup.valueText
                        textFormat: Text.PlainText
                        font.family: controlGroup.nameLabel ? Fonts.ui : Fonts.numeric
                        font.pixelSize: 12
                        color: Appearance.colors.colOnSurface
                        elide: Text.ElideRight
                    }
                }
                readonly property bool resizing: componentLoader.item && !!componentLoader.item.resizing
            }
        }
    }

    Component {
        id: networkComponent

        Network {
            screen: root.screen
            vertical: root.vertical
        }
    }

    Component {
        id: bluetoothComponent

        BluetoothButton {
            screen: root.screen
        }
    }

    Component {
        id: brightnessComponent

        Brightness {
            screen: root.screen
        }
    }

    Component {
        id: volumeComponent

        Volume {
            screen: root.screen
        }
    }

    Component {
        id: microphoneComponent

        Microphone {
            screen: root.screen
        }
    }

    Component {
        id: batteryComponent

        Battery {
            vertical: root.vertical
        }
    }

    Component {
        id: settingsComponent

        SettingsButton {
            screen: root.screen
        }
    }

    Component {
        id: powerComponent

        PowerButton {
            screen: root.screen
        }
    }
}
