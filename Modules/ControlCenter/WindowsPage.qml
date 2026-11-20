pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root
    property bool presentationActive: false
    readonly property var windows: NiriConfigService.windowsOptions
    readonly property var personal: windows.personal || ({})
    readonly property var external: windows.external || ({})
    readonly property bool editable: NiriConfigService.ready("windows")
    readonly property var widthOptions: {
        const options = [
                  {
                      label: qsTr("Chosen by the application"),
                      value: "0"
                  },
                  {
                      label: qsTr("One third"),
                      value: "0.33333"
                  },
                  {
                      label: qsTr("Half"),
                      value: "0.5"
                  },
                  {
                      label: qsTr("Two thirds"),
                      value: "0.66667"
                  },
                  {
                      label: qsTr("Full width"),
                      value: "1"
                  }
              ];
        const current = String(windows.defaultColumnWidth);
        if (!options.some(option => option.value === current))
            options.push({
                             label: qsTr("%1% of the screen").arg(Math.round(windows.defaultColumnWidth
                                                                             * 100)),
                             value: current
                         });
        return options;
    }

    component SwitchRow: SettingsRow {
        id: switchRow
        property bool checked: false
        property bool switchEnabled: root.editable
        signal toggled(bool checked)
        Layout.fillWidth: true
        trailing: StyledSwitch {
            checked: switchRow.checked
            enabled: switchRow.switchEnabled
            Accessible.name: switchRow.title
            onToggled: switchRow.toggled(checked)
        }
    }

    component PersonalSwitch: SwitchRow {
        id: personalSwitch
        required property string flag
        checked: root.personal[flag] === true
        onToggled: checked => NiriConfigService.setPersonalLayoutFlag(personalSwitch.flag, checked)
    }

    component CornerSwitch: SwitchRow {
        id: cornerSwitch
        required property string corner
        readonly property var corners: root.windows.hotCorners || ["top-left"]
        checked: corners.indexOf(corner) >= 0
        onToggled: checked => {
            const next = cornerSwitch.corners.filter(entry => entry !== cornerSwitch.corner);
            if (checked)
                next.push(cornerSwitch.corner);
            NiriConfigService.setWindowsOptions({
                                                    hotCorners: next
                                                });
        }
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

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
            message: NiriConfigService.busy || NiriConfigService.pendingWindowsOptions !== null ? qsTr(
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
            title: qsTr("Enable window management settings")
            description: qsTr(
                             "Clavis takes over window layout, decorations and focus behavior, starting from your current values.")
            integrationState: NiriConfigService.state("windows")
            busy: NiriConfigService.busy
            blocked: NiriConfigService.busy
            onSetupRequested: NiriConfigService.setup("windows")
        }

        SettingsSection {
            id: layoutSection
            Layout.fillWidth: true
            title: layoutAnchor.title
            iconName: "view_column"
            SettingsSearchAnchor {
                id: layoutAnchor
                target: layoutSection
                declaration:
                    '{"id":"general.windows.section.layout","route":"general.windows","title":"Window layout","context":"WindowsPage","icon":"view_column","aliases":["gaps","column width","center column","tiling"]}'
            }

            GeneralSliderSetting {
                objectName: "windowsGapsSetting"
                enabled: root.editable
                title: qsTr("Gaps between windows")
                from: 0
                to: 32
                stepSize: 1
                suffix: qsTr(" px")
                value: root.windows.gaps
                onMoved: value => NiriConfigService.setWindowsOptions({
                                                                          gaps: Math.round(value)
                                                                      })
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("New window width")
                trailing: SearchSelectMenuField {
                    objectName: "windowsColumnWidthField"
                    implicitWidth: 220
                    implicitHeight: 40
                    enabled: root.editable
                    options: root.widthOptions
                    value: String(root.windows.defaultColumnWidth)
                    onAccepted: value => NiriConfigService.setWindowsOptions({
                                                                                 defaultColumnWidth: Number(
                                                                                                         value)
                                                                             })
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Center the focused column")
                trailing: SearchSelectMenuField {
                    objectName: "windowsCenterField"
                    implicitWidth: 220
                    implicitHeight: 40
                    enabled: root.editable
                    options: [
                        {
                            label: qsTr("Never"),
                            value: "never"
                        },
                        {
                            label: qsTr("When it does not fit"),
                            value: "on-overflow"
                        },
                        {
                            label: qsTr("Always"),
                            value: "always"
                        }
                    ]
                    value: root.windows.centerFocusedColumn
                    onAccepted: value => NiriConfigService.setWindowsOptions({
                                                                                 centerFocusedColumn: value
                                                                             })
                }
            }

            SwitchRow {
                title: qsTr("Center a single column")
                supportingText: qsTr("When a workspace has only one column")
                checked: root.windows.alwaysCenterSingleColumn
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              alwaysCenterSingleColumn:
                                                                              checked
                                                                          })
            }

            SwitchRow {
                title: qsTr("Empty workspace above the first")
                checked: root.windows.emptyWorkspaceAboveFirst
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              emptyWorkspaceAboveFirst:
                                                                              checked
                                                                          })
            }
        }

        SettingsSection {
            id: decorationSection
            Layout.fillWidth: true
            title: decorationAnchor.title
            iconName: "select_window"
            SettingsSearchAnchor {
                id: decorationAnchor
                target: decorationSection
                declaration:
                    '{"id":"general.windows.section.decorations","route":"general.windows","title":"Window decorations","context":"WindowsPage","icon":"select_window","aliases":["focus ring","border","shadow","outline"]}'
            }

            SwitchRow {
                title: qsTr("Focus ring")
                supportingText: qsTr("Outline drawn around the focused window")
                checked: root.windows.focusRing
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              focusRing: checked
                                                                          })
            }

            GeneralSliderSetting {
                objectName: "windowsFocusRingWidthSetting"
                visible: root.windows.focusRing
                enabled: root.editable
                title: qsTr("Focus ring width")
                from: 1
                to: 16
                stepSize: 1
                suffix: qsTr(" px")
                value: root.windows.focusRingWidth
                onMoved: value => NiriConfigService.setWindowsOptions({
                                                                          focusRingWidth: Math.round(value)
                                                                      })
            }

            SwitchRow {
                title: qsTr("Border")
                supportingText: qsTr("Border around every window, which takes up layout space")
                checked: root.windows.border
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              border: checked
                                                                          })
            }

            GeneralSliderSetting {
                objectName: "windowsBorderWidthSetting"
                visible: root.windows.border
                enabled: root.editable
                title: qsTr("Border width")
                from: 1
                to: 16
                stepSize: 1
                suffix: qsTr(" px")
                value: root.windows.borderWidth
                onMoved: value => NiriConfigService.setWindowsOptions({
                                                                          borderWidth: Math.round(value)
                                                                      })
            }

            SwitchRow {
                title: qsTr("Window shadows")
                checked: root.windows.shadow
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              shadow: checked
                                                                          })
            }
        }

        SettingsSection {
            id: focusSection
            Layout.fillWidth: true
            title: focusAnchor.title
            iconName: "ads_click"
            SettingsSearchAnchor {
                id: focusAnchor
                target: focusSection
                declaration:
                    '{"id":"general.windows.section.focus","route":"general.windows","title":"Focus behavior","context":"WindowsPage","icon":"ads_click","aliases":["focus follows mouse","warp","back and forth"]}'
            }

            SwitchRow {
                title: qsTr("Focus follows the mouse")
                supportingText: root.external.focusFollowsMouse ? qsTr(
                                                                      "Turned on in another configuration file") :
                                                                  qsTr("Focus windows by moving the pointer over them")
                checked: root.windows.focusFollowsMouse
                switchEnabled: root.editable && !root.external.focusFollowsMouse
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              focusFollowsMouse: checked
                                                                          })
            }

            SwitchRow {
                title: qsTr("Move the pointer to the focused window")
                supportingText: root.external.warpMouseToFocus ? qsTr(
                                                                     "Turned on in another configuration file") :
                                                                 qsTr("When focus changes with the keyboard")
                checked: root.windows.warpMouseToFocus
                switchEnabled: root.editable && !root.external.warpMouseToFocus
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              warpMouseToFocus: checked
                                                                          })
            }

            SwitchRow {
                title: qsTr("Switch back to the previous workspace")
                supportingText: qsTr("Choosing the current workspace again returns to the previous one")
                checked: root.windows.workspaceBackAndForth
                onToggled: checked => NiriConfigService.setWindowsOptions({
                                                                              workspaceBackAndForth: checked
                                                                          })
            }
        }

        SettingsSection {
            id: overviewSection
            Layout.fillWidth: true
            title: overviewAnchor.title
            iconName: "overview"
            supportingText: qsTr(
                                "Move the pointer into a chosen screen corner to open or close the overview.")
            SettingsSearchAnchor {
                id: overviewAnchor
                target: overviewSection
                declaration:
                    '{"id":"general.windows.section.overview","route":"general.windows","title":"Overview and hot corners","context":"WindowsPage","icon":"overview","aliases":["hot corner","overview zoom","expose"]}'
            }

            CornerSwitch {
                corner: "top-left"
                title: qsTr("Top-left corner")
            }

            CornerSwitch {
                corner: "top-right"
                title: qsTr("Top-right corner")
            }

            CornerSwitch {
                corner: "bottom-left"
                title: qsTr("Bottom-left corner")
            }

            CornerSwitch {
                corner: "bottom-right"
                title: qsTr("Bottom-right corner")
            }

            GeneralSliderSetting {
                objectName: "windowsOverviewZoomSetting"
                enabled: root.editable
                title: qsTr("Workspace size in the overview")
                from: 10
                to: 75
                stepSize: 5
                suffix: "%"
                value: Math.round(root.windows.overviewZoom * 100)
                onMoved: value => NiriConfigService.setWindowsOptions({
                                                                          overviewZoom: value / 100
                                                                      })
            }
        }

        SettingsSection {
            id: floatingSection
            Layout.fillWidth: true
            visible: root.windows.personalSupported === true
            title: floatingAnchor.title
            iconName: "dashboard_customize"
            supportingText: qsTr("Provided by this computer's customized niri")
            SettingsSearchAnchor {
                id: floatingAnchor
                target: floatingSection
                declaration:
                    '{"id":"general.windows.section.floating","route":"general.windows","title":"Floating windows and title bars","context":"WindowsPage","icon":"dashboard_customize","aliases":["floating","snap","remember layout","title bar","double click","maximize"]}'
            }

            PersonalSwitch {
                flag: "remember-window-layout"
                title: qsTr("Remember each application's window layout")
                supportingText: qsTr("New windows reopen floating or tiled with their last size")
            }

            PersonalSwitch {
                flag: "floating-windows-follow-focus"
                title: qsTr("Lower floating windows behind tiled windows")
                supportingText: qsTr("Activating a tiled window lowers raised floating windows")
            }

            PersonalSwitch {
                flag: "floating-windows-follow-parent"
                title: qsTr("Keep dialogs with their parent window")
            }

            PersonalSwitch {
                flag: "floating-windows-match-tiling-top"
                title: qsTr("Keep floating windows below the bar")
                supportingText: qsTr("Floating windows share the top edge of tiled windows")
            }

            PersonalSwitch {
                flag: "floating-windows-edge-snap"
                title: qsTr("Snap to half the screen at the edges")
                supportingText: qsTr("Drop a floating window at the left or right edge to tile it")
            }

            PersonalSwitch {
                flag: "floating-windows-detach-on-mod-drag"
                title: qsTr("Detach tiled windows by dragging with Mod")
                supportingText: qsTr("Hold Shift as well to keep the normal tiling drag")
            }

            PersonalSwitch {
                flag: "floating-windows-restore-normal-size"
                title: qsTr("Restore the previous floating size")
                supportingText: qsTr("When a tiled window becomes floating again")
            }

            PersonalSwitch {
                flag: "titlebar-double-click-to-column"
                title: qsTr("Double-click a title bar to expand the column")
                supportingText: qsTr("The maximize button still fills the screen")
            }

            PersonalSwitch {
                flag: "client-maximize-to-column"
                title: qsTr("Maximize requests expand the column")
                supportingText: qsTr("Applies to maximize buttons of tiled windows")
            }
        }
    }
}
