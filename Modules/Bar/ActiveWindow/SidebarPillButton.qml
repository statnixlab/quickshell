import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property string viewName: "info"
    property string sidebarIconName: "notifications"
    property color activeColor: Appearance.colors.colSecondaryContainer
    property color activeContentColor: Appearance.colors.colOnSecondaryContainer
    readonly property bool isActive: WidgetState.dashboardSidebarOpen && WidgetState.dashboardSidebarView
                                     === root.viewName
    readonly property int unreadCount: root.viewName === "info" ? DockBadgeService.totalUnread : 0

    function toggleView() {
        if (root.isActive) {
            WidgetState.dashboardSidebarOpen = false;
            return;
        }
        WidgetState.dashboardSidebarView = root.viewName;
        WidgetState.dashboardSidebarOpen = true;
    }

    selected: root.isActive
    iconName: root.sidebarIconName
    containerColor: root.activeColor
    rippleColor: root.activeContentColor
    iconColor: root.activeContentColor
    tooltipText: root.viewName === "drawer" ? qsTr("Drawer") : qsTr("Notification center")
    Accessible.description: root.unreadCount > 0 ? String(root.unreadCount) : ""
    onClicked: root.toggleView()

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        z: 2
        visible: root.unreadCount > 0
        width: Math.min(root.width, Math.max(height, badgeLabel.implicitWidth + 4))
        height: 13
        radius: height / 2
        color: Appearance.colors.colError
        border.width: 1
        border.color: Appearance.colors.colLayer0
        antialiasing: true

        Text {
            id: badgeLabel

            anchors.centerIn: parent
            text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
            textFormat: Text.PlainText
            font.family: Fonts.numeric
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Appearance.colors.colOnError
            Accessible.ignored: true
        }
    }
}
