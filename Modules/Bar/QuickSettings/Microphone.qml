import QtQuick
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null

    implicitHeight: Sizes.barControlCircleSize
    implicitWidth: Sizes.barControlCircleSize

    ArcGauge {
        anchors.centerIn: parent
        width: 28
        height: 28
        scale: root.width / 28

        value: Volume.sourceMuted ? 0 : Volume.sourceVolume
        progressColor: (Volume.sourceMuted || Volume.sourceVolume <= 0) ? Appearance.colors.colError :
                                                                          Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2Hover
        handleColor: Appearance.colors.colOnSurface
        iconColor: (Volume.sourceMuted || Volume.sourceVolume <= 0) ? Appearance.colors.colError :
                                                                      Appearance.colors.colOnSurface
        icon: (Volume.sourceMuted || Volume.sourceVolume <= 0) ? "mic_off" : "mic"
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onWheel: wheel => {
            const step = 0.05;
            let newVol = Volume.sourceVolume;
            if (wheel.angleDelta.y > 0)
                newVol += step;
            else
                newVol -= step;
            Volume.setSourceVolume(newVol);
            wheel.accepted = true;
        }
        onClicked: {
            if (root.screen && root.screen.name)
                WidgetState.quickSettingsScreenName = root.screen.name;
            if (WidgetState.quickSettingsOpen && WidgetState.quickSettingsView === "microphone") {
                WidgetState.quickSettingsOpen = false;
            } else {
                WidgetState.quickSettingsView = "microphone";
                WidgetState.quickSettingsOpen = true;
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: (Volume.sourceMuted ? qsTr("Microphone: muted") : qsTr("Microphone: ") + Math.round(
                                        Volume.sourceVolume * 100) + "%") + qsTr(
                  "\nScroll to adjust; click to open microphone controls")
    }
}
