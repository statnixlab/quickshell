import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property bool vertical: false

    implicitHeight: vertical ? buttonRow.implicitHeight + 2 * (root.pillPadding + 2) : root.pillThickness
    implicitWidth: vertical ? root.bandThickness : buttonRow.implicitWidth + 2 * root.pillPadding

    GridLayout {
        id: buttonRow

        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 4
        columns: root.vertical ? 1 : 3

        SidebarPillButton {
            viewName: "info"
            sidebarIconName: "notifications"
            activeColor: Appearance.colors.colSecondary
            activeContentColor: Appearance.colors.colOnSecondary
        }

        SidebarPillButton {
            viewName: "drawer"
            sidebarIconName: "widgets"
            activeColor: Appearance.colors.colTertiary
            activeContentColor: Appearance.colors.colOnTertiary
        }

        SidebarWeatherButton {
            vertical: root.vertical
        }
    }
}
