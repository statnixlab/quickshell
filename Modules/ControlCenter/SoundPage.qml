pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.audio
import qs.Widgets.common

StyledFlickable {
    id: root
    property bool presentationActive: false

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    function deviceOptions(nodes) {
        return nodes.map(node => ({
            label: Volume.nodeDisplayName(node),
            value: Volume.nodeId(node)
        }));
    }

        function nodeById(nodes, id) {
        return nodes.find(node => Volume.nodeId(node) === id) || null;
    }

        Component.onCompleted: AudioCardService.refresh()
        onPresentationActiveChanged: if (presentationActive)
        AudioCardService.refresh()

        ColumnLayout {
        id: contentColumn
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
        Layout.fillWidth: true
        visible: !Volume.ready || Volume.lastError !== "" || AudioCardService.error !== ""
        tone: Volume.ready ? "error" : "info"
        message: !Volume.ready ? qsTr("Connecting to PipeWire…") : Volume.lastError || AudioCardService.error
    }

        SettingsSection {
        id: outputSection
        Layout.fillWidth: true
        title: outputAnchor.title
        iconName: "volume_up"
        SettingsSearchAnchor {
        id: outputAnchor
        target: outputSection
        declaration:
        '{"id":"general.sound.section.output","route":"general.sound","title":"Output","context":"SoundPage","icon":"volume_up","aliases":["speaker","headphones","volume","audio output"]}'
    }

        SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Output device")
        trailing: SearchSelectMenuField {
        objectName: "soundOutputField"
        implicitWidth: 260
        implicitHeight: 40
        enabled: Volume.ready && Volume.outputDevices.length > 0
        options: root.deviceOptions(Volume.outputDevices)
        value: Volume.nodeId(Volume.sink)
        placeholder: qsTr("No output device")
        onAccepted: value => Volume.setDefaultOutput(root.nodeById(Volume.outputDevices, value))
    }
    }

        VolumeSlider {
        Layout.fillWidth: true
        visible: Volume.outputAvailable
        title: qsTr("Volume")
        iconName: Volume.nodeIconName(Volume.sink)
        volume: Volume.sinkVolume
        muted: Volume.sinkMuted
        available: Volume.outputAvailable
        onVolumeMoved: value => Volume.setSinkVolume(value)
    }

        SettingsRow {
        Layout.fillWidth: true
        visible: Volume.outputAvailable
        title: qsTr("Mute output")
        trailing: StyledSwitch {
        checked: Volume.sinkMuted
        Accessible.name: qsTr("Mute output")
        onToggled: if (checked !== Volume.sinkMuted)
        Volume.toggleSinkMute()
    }
    }
    }

        SettingsSection {
        id: inputSection
        Layout.fillWidth: true
        title: inputAnchor.title
        iconName: "mic"
        SettingsSearchAnchor {
        id: inputAnchor
        target: inputSection
        declaration:
        '{"id":"general.sound.section.input","route":"general.sound","title":"Input","context":"SoundPage","icon":"mic","aliases":["microphone","mic","recording"]}'
    }

        SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Input device")
        trailing: SearchSelectMenuField {
        objectName: "soundInputField"
        implicitWidth: 260
        implicitHeight: 40
        enabled: Volume.ready && Volume.inputDevices.length > 0
        options: root.deviceOptions(Volume.inputDevices)
        value: Volume.nodeId(Volume.source)
        placeholder: qsTr("No input device")
        onAccepted: value => Volume.setDefaultInput(root.nodeById(Volume.inputDevices, value))
    }
    }

        VolumeSlider {
        Layout.fillWidth: true
        visible: Volume.inputAvailable
        title: qsTr("Input volume")
        iconName: Volume.sourceMuted ? "mic_off" : "mic"
        volume: Volume.sourceVolume
        muted: Volume.sourceMuted
        available: Volume.inputAvailable
        onVolumeMoved: value => Volume.setSourceVolume(value)
    }

        SettingsRow {
        Layout.fillWidth: true
        visible: Volume.inputAvailable
        title: qsTr("Mute microphone")
        trailing: StyledSwitch {
        checked: Volume.sourceMuted
        Accessible.name: qsTr("Mute microphone")
        onToggled: if (checked !== Volume.sourceMuted)
        Volume.toggleSourceMute()
    }
    }
    }

        SettingsSection {
        id: appsSection
        Layout.fillWidth: true
        title: appsAnchor.title
        iconName: "apps"
        SettingsSearchAnchor {
        id: appsAnchor
        target: appsSection
        declaration:
        '{"id":"general.sound.section.applications","route":"general.sound","title":"Application volume","context":"SoundPage","icon":"apps","aliases":["mixer","app volume","per application"]}'
    }

        Repeater {
        model: Volume.playbackStreams

        ApplicationVolumeRow {
        required property var modelData
        Layout.fillWidth: true
        title: Volume.applicationDisplayName(modelData)
        iconSource: Volume.applicationIconSource(modelData)
        volume: Volume.nodeVolume(modelData)
        muted: Volume.nodeMuted(modelData)
        onVolumeMoved: value => Volume.setNodeVolume(modelData, value)
        onMuteRequested: Volume.toggleNodeMute(modelData)
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        visible: Volume.playbackStreams.length === 0
        iconName: "music_off"
        title: qsTr("No active application audio")
    }
    }

        SettingsSection {
        id: cardsSection
        Layout.fillWidth: true
        title: cardsAnchor.title
        iconName: "graphic_eq"
        supportingText: qsTr(
        "Choose how each sound device is used, for example HDMI output or a Bluetooth headset mode.")
        SettingsSearchAnchor {
        id: cardsAnchor
        target: cardsSection
        declaration:
        '{"id":"general.sound.section.profiles","route":"general.sound","title":"Device profiles","context":"SoundPage","icon":"graphic_eq","aliases":["profile","hdmi","a2dp","headset mode","sound card"]}'
    }

        Repeater {
        model: AudioCardService.cards

        SettingsRow {
        id: cardRow
        required property var modelData
        Layout.fillWidth: true
        iconName: AudioCardService.cardIcon(modelData)
        title: AudioCardService.cardName(modelData)
        trailing: SearchSelectMenuField {
        implicitWidth: 260
        implicitHeight: 40
        enabled: !AudioCardService.busy
        options: AudioCardService.profileOptions(cardRow.modelData)
        value: cardRow.modelData.active_profile || ""
        onAccepted: value => AudioCardService.setProfile(cardRow.modelData, value)
    }
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        visible: AudioCardService.loaded && AudioCardService.cards.length === 0
        title: qsTr("No configurable sound devices")
    }

        SettingsActionRow {
        Layout.fillWidth: true
        iconName: "tune"
        text: qsTr("Advanced mixer")
        description: qsTr("Open PulseAudio Volume Control")
        onClicked: Volume.openMixer()
    }
    }
    }
    }
