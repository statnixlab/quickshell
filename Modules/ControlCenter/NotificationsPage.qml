pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root
    property bool presentationActive: false
    // Applications seen in the history plus muted ones, so a mute can always be undone.
    readonly property var applications: {
        const names = Array.from(NotificationManager.appNameList).concat(UiPreferences.notificationMutedApps);
        return names.filter((name, index) => name && names.indexOf(name) === index).sort((left, right)
                                                                                         => left.localeCompare(
                                                                                                right));
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    component SwitchRow: SettingsRow {
        id: switchRow
        property bool checked: false
        signal toggled(bool checked)
        Layout.fillWidth: true
        trailing: StyledSwitch {
            checked: switchRow.checked
            Accessible.name: switchRow.title
            onToggled: switchRow.toggled(checked)
        }
    }

    ColumnLayout {
        id: contentColumn
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        SettingsSection {
            id: dndSection
            Layout.fillWidth: true
            title: dndAnchor.title
            iconName: "do_not_disturb_on"
            SettingsSearchAnchor {
                id: dndAnchor
                target: dndSection
                declaration:
                    '{"id":"general.notifications.section.dnd","route":"general.notifications","title":"Do Not Disturb","context":"NotificationsPage","icon":"do_not_disturb_on","aliases":["dnd","silent","quiet"]}'
            }

            SwitchRow {
                title: qsTr("Do Not Disturb")
                supportingText: qsTr("Hide banners; notifications are still kept in the history")
                checked: UiPreferences.dndEnabled
                onToggled: checked => NotificationManager.setSilent(checked)
            }

            SwitchRow {
                title: qsTr("Allow critical notifications")
                supportingText: qsTr("Critical notifications still show a banner during Do Not Disturb")
                checked: UiPreferences.notificationCriticalBypassDnd
                onToggled: checked => UiPreferences.setNotificationCriticalBypassDnd(checked)
            }
        }

        SettingsSection {
            id: bannerSection
            Layout.fillWidth: true
            title: bannerAnchor.title
            iconName: "notifications"
            SettingsSearchAnchor {
                id: bannerAnchor
                target: bannerSection
                declaration:
                    '{"id":"general.notifications.section.banners","route":"general.notifications","title":"Banners","context":"NotificationsPage","icon":"notifications","aliases":["popup","duration","sound","wechat"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Show banners for")
                supportingText: qsTr("Applications may request a shorter time")
                trailing: SearchSelectMenuField {
                    objectName: "notificationDurationField"
                    implicitWidth: 180
                    implicitHeight: 40
                    options: UiPreferences.notificationPopupDurations.map(seconds => ({
                        label: qsTr("%n second(s)", "", seconds),
                        value: String(seconds)
                    }))
                    value: String(UiPreferences.notificationPopupSeconds)
                    onAccepted: value => UiPreferences.setNotificationPopupSeconds(Number(value))
                }
            }

            SwitchRow {
                title: qsTr("Extra sound for WeChat")
                supportingText: qsTr("Play a sound for new WeChat messages, except during Do Not Disturb")
                checked: UiPreferences.wechatExtraSoundEnabled
                onToggled: checked => UiPreferences.setWechatExtraSoundEnabled(checked)
            }
        }

        SettingsSection {
            id: appsSection
            Layout.fillWidth: true
            title: appsAnchor.title
            iconName: "apps"
            supportingText: qsTr(
                                "Turn off banners for an application; its notifications stay in the history.")
            SettingsSearchAnchor {
                id: appsAnchor
                target: appsSection
                declaration:
                    '{"id":"general.notifications.section.applications","route":"general.notifications","title":"Application notifications","context":"NotificationsPage","icon":"apps","aliases":["mute app","block notifications"]}'
            }

            Repeater {
                model: root.applications

                SwitchRow {
                    id: appRow
                    required property string modelData
                    iconName: "notifications"
                    title: appRow.modelData
                    checked: UiPreferences.notificationMutedApps.indexOf(appRow.modelData) < 0
                    onToggled: checked => UiPreferences.setNotificationAppMuted(appRow.modelData, !checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.applications.length === 0
                title: qsTr("Applications appear here after they send a notification")
            }
        }

        SettingsSection {
            id: historySection
            Layout.fillWidth: true
            title: historyAnchor.title
            iconName: "history"
            SettingsSearchAnchor {
                id: historyAnchor
                target: historySection
                declaration:
                    '{"id":"general.notifications.section.history","route":"general.notifications","title":"Notification history","context":"NotificationsPage","icon":"history","aliases":["clear notifications"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("%n notification(s) in the history", "", NotificationManager.list.length)
                trailing: ActionButton {
                    text: qsTr("Clear all")
                    iconName: "clear_all"
                    enabled: NotificationManager.list.length > 0
                    onClicked: NotificationManager.discardAllNotifications()
                }
            }
        }
    }
}
