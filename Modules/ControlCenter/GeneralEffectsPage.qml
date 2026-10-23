import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    Component.onCompleted: NiriConfigService.refresh()

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Background effects")
            description: qsTr("Create or connect the Clavis X-Ray rules.")
            integrationState: NiriConfigService.state("effects")
            busy: NiriConfigService.busy && NiriConfigService.activeFeature === "effects"
            blocked: NiriConfigService.busy
            error: NiriConfigService.error
            onSetupRequested: NiriConfigService.setup("effects")
        }

        SettingsSection {
            id: searchSection0
            Layout.fillWidth: true
            flat: true
            title: searchAnchor0.title
            SettingsSearchAnchor {
                id: searchAnchor0
                target: searchSection0
                declaration:
                    '{"id":"general.effects.section.background","route":"general.effects","title":"Desktop panels","context":"GeneralEffectsPage","icon":"blur_on","aliases":[]}'
            }
            iconName: "wallpaper"

            GeneralSliderSetting {
                title: qsTr("Panel background opacity")
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                value: PersonalizationConfig.shellBackgroundOpacity * 100
                onMoved: value => PersonalizationConfig.setShellBackgroundOpacity(value / 100)
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                title: qsTr("Panel background blur")

                trailing: StyledSwitch {
                    enabled: BlurService.available
                    checked: PersonalizationConfig.shellBlurEnabled
                    Accessible.name: qsTr("Panel background blur")
                    onToggled: PersonalizationConfig.setShellBlurEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "filter_center_focus"
                title: qsTr("Blur wallpaper only")
                supportingText: BlurService.niriIntegrationReady ? qsTr(
                                                                       "Turning this off also blurs windows and uses more resources") :
                                                                   qsTr("Configure Niri blur integration first")

                trailing: StyledSwitch {
                    enabled: BlurService.available && BlurService.niriIntegrationReady
                    checked: PersonalizationConfig.shellBlurXray
                    Accessible.name: qsTr("Blur wallpaper only")
                    onToggled: PersonalizationConfig.setShellBlurXray(checked)
                }
            }

            GeneralSliderSetting {
                enabled: NiriConfigService.separateBlurSupported && NiriConfigService.effectsSeparated &&
                         !NiriConfigService.panelEffects.blurDisabled
                title: qsTr("Panel blur strength")
                from: 1
                to: 5
                stepSize: 1
                value: NiriConfigService.panelEffects.blurStrength
                onMoved: value => NiriConfigService.setPanelEffects({
                                                                        blurStrength: Math.round(value)
                                                                    })
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: BlurService.lastError !== ""
                tone: "error"
                message: BlurService.lastError
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NiriConfigService.supported && NiriConfigService.revision !== "" &&
                     !NiriConfigService.separateBlurSupported
            tone: "warning"
            message: qsTr(
                         "Log out and back in after updating the compositor to adjust application and panel blur independently.")
        }

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Application effects")
            description: qsTr("Enable transparency and blur controls for application windows.")
            integrationState: NiriConfigService.state("application-effects")
            busy: NiriConfigService.busy && NiriConfigService.activeFeature === "application-effects"
            blocked: NiriConfigService.busy || !NiriConfigService.separateBlurSupported
            error: NiriConfigService.errorFeature === "application-effects" ? NiriConfigService.error : ""
            onSetupRequested: NiriConfigService.setup("application-effects")
        }

        SettingsSection {
            id: applicationEffectsSection
            Layout.fillWidth: true
            flat: true
            title: applicationEffectsAnchor.title
            iconName: "filter_center_focus"

            SettingsSearchAnchor {
                id: applicationEffectsAnchor
                target: applicationEffectsSection
                declaration:
                    '{"id":"general.effects.section.application-effects","route":"general.effects","title":"Application effects","context":"GeneralEffectsPage","icon":"filter_center_focus","aliases":["Transparency","Focused window","Unfocused window","Blur strength"]}'
            }

            GeneralSliderSetting {
                enabled: NiriConfigService.ready("application-effects")
                         && NiriConfigService.separateBlurSupported && NiriConfigService.effectsSeparated
                title: qsTr("Focused window opacity")
                from: 10
                to: 100
                stepSize: 1
                suffix: "%"
                value: NiriConfigService.applicationEffects.focused * 100
                onMoved: value => NiriConfigService.setApplicationEffects({
                                                                              focused: value / 100
                                                                          })
            }

            GeneralSliderSetting {
                enabled: NiriConfigService.ready("application-effects")
                         && NiriConfigService.separateBlurSupported && NiriConfigService.effectsSeparated
                title: qsTr("Unfocused window opacity")
                description: qsTr("Applies to the entire window, including text and images. 100% is opaque.")
                from: 10
                to: 100
                stepSize: 1
                suffix: "%"
                value: NiriConfigService.applicationEffects.unfocused * 100
                onMoved: value => NiriConfigService.setApplicationEffects({
                                                                              unfocused: value / 100
                                                                          })
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                title: qsTr("Application background blur")

                trailing: StyledSwitch {
                    enabled: NiriConfigService.ready("application-effects")
                             && NiriConfigService.separateBlurSupported && NiriConfigService.effectsSeparated
                             && !NiriConfigService.applicationEffects.blurDisabled
                    checked: NiriConfigService.applicationEffects.blurEnabled
                    Accessible.name: qsTr("Application background blur")
                    onToggled: NiriConfigService.setApplicationEffects({
                                                                           blurEnabled: checked
                                                                       })
                }
            }

            GeneralSliderSetting {
                enabled: NiriConfigService.ready("application-effects")
                         && NiriConfigService.separateBlurSupported && NiriConfigService.effectsSeparated &&
                         !NiriConfigService.applicationEffects.blurDisabled
                title: qsTr("Application blur strength")
                from: 1
                to: 5
                stepSize: 1
                value: NiriConfigService.applicationEffects.blurStrength
                onMoved: value => NiriConfigService.setApplicationEffects({
                                                                              blurStrength: Math.round(value)
                                                                          })
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: NiriConfigService.applicationEffects.blurDisabled
                tone: "warning"
                message: qsTr("Blur is disabled in the compositor configuration.")
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: NiriConfigService.errorFeature === "application-effects" && NiriConfigService.error
                         !== ""
                tone: "error"
                message: NiriConfigService.error
            }
        }
    }
}
