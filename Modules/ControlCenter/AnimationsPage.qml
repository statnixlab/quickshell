pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root
    property bool presentationActive: false
    readonly property var animations: NiriConfigService.animationOptions
    readonly property bool editable: NiriConfigService.ready("animations")
    readonly property var speedOptions: {
        const options = [
                  {
                      label: qsTr("Very fast"),
                      value: "0.5"
                  },
                  {
                      label: qsTr("Fast"),
                      value: "0.75"
                  },
                  {
                      label: qsTr("Normal"),
                      value: "1"
                  },
                  {
                      label: qsTr("Slow"),
                      value: "1.5"
                  },
                  {
                      label: qsTr("Very slow"),
                      value: "2"
                  }
              ];
        const current = String(animations.slowdown);
        if (!options.some(option => option.value === current))
            options.push({
                             label: qsTr("Custom (%1×)").arg(animations.slowdown),
                             value: current
                         });
        return options;
    }

    signal sectionRequested(string section)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    component AnimationSwitch: SettingsRow {
        id: animationRow
        required property string animation
        readonly property bool external: (root.animations.external || []).indexOf(animation) >= 0
        Layout.fillWidth: true
        supportingText: external ? qsTr("Turned off in another configuration file") : ""
        trailing: StyledSwitch {
            checked: (root.animations.disabled || []).indexOf(animationRow.animation) < 0
            enabled: root.editable && root.animations.enabled && !animationRow.external
            Accessible.name: animationRow.title
            onToggled: NiriConfigService.setAnimationEnabled(animationRow.animation, checked)
        }
    }

    Component.onCompleted: NiriConfigService.refresh()
    onPresentationActiveChanged: if (presentationActive)
                                     NiriConfigService.refresh()

    ColumnLayout {
        id: contentColumn
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            message: NiriConfigService.busy || NiriConfigService.pendingAnimationOptions !== null ? qsTr(
                                                                                                        "Saving…") :
                                                                                                    qsTr("Changes are saved and applied automatically")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NiriConfigService.error !== "" || NiriConfigService.readError !== ""
            tone: "error"
            message: NiriConfigService.error || NiriConfigService.readError
        }

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Enable animation settings")
            description: qsTr(
                             "Clavis takes over the animation switch and speed, starting from your current values.")
            integrationState: NiriConfigService.state("animations")
            busy: NiriConfigService.busy
            blocked: NiriConfigService.busy
            onSetupRequested: NiriConfigService.setup("animations")
        }

        SettingsSection {
            id: generalSection
            Layout.fillWidth: true
            title: generalAnchor.title
            iconName: "animation"
            SettingsSearchAnchor {
                id: generalAnchor
                target: generalSection
                declaration:
                    '{"id":"general.animations.section.general","route":"general.animations","title":"Animation speed","context":"AnimationsPage","icon":"animation","aliases":["slowdown","reduce motion","turn off animations"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Animations")
                supportingText: qsTr("Turn off to switch windows and workspaces instantly")
                trailing: StyledSwitch {
                    objectName: "animationsSwitch"
                    checked: root.animations.enabled
                    enabled: root.editable
                    Accessible.name: qsTr("Animations")
                    onToggled: NiriConfigService.setAnimationOptions({
                                                                         enabled: checked
                                                                     })
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Speed")
                trailing: SearchSelectMenuField {
                    objectName: "animationSpeedField"
                    implicitWidth: 200
                    implicitHeight: 40
                    enabled: root.editable && root.animations.enabled
                    options: root.speedOptions
                    value: String(root.animations.slowdown)
                    onAccepted: value => NiriConfigService.setAnimationOptions({
                                                                                   slowdown: Number(value)
                                                                               })
                }
            }
        }

        SettingsSection {
            id: itemsSection
            Layout.fillWidth: true
            title: itemsAnchor.title
            iconName: "motion_photos_on"
            SettingsSearchAnchor {
                id: itemsAnchor
                target: itemsSection
                declaration:
                    '{"id":"general.animations.section.items","route":"general.animations","title":"Individual animations","context":"AnimationsPage","icon":"motion_photos_on","aliases":["window open","window close","workspace switch"]}'
            }

            AnimationSwitch {
                animation: "window-open"
                title: qsTr("Opening windows")
            }

            AnimationSwitch {
                animation: "window-close"
                title: qsTr("Closing windows")
            }

            AnimationSwitch {
                animation: "workspace-switch"
                title: qsTr("Switching workspaces")
            }

            AnimationSwitch {
                animation: "horizontal-view-movement"
                title: qsTr("Scrolling between columns")
            }

            AnimationSwitch {
                animation: "window-movement"
                title: qsTr("Moving windows")
            }

            AnimationSwitch {
                animation: "window-resize"
                title: qsTr("Resizing windows")
            }

            AnimationSwitch {
                animation: "overview-open-close"
                title: qsTr("Opening the overview")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "minimize"
                text: qsTr("Minimize animation")
                description: qsTr("Choose Genie or Scale in the Dock settings")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("dock")
            }
        }
    }
}
