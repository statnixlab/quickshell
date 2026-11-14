import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Widgets.common
import "./notifications"
import "./infoTools"

StyledFlickable {
    id: root

    signal imageSelectionRequested(bool forAvatar)
    signal bannerColorRequested

    property string screenName: ""
    property bool foreground: false
    readonly property bool isForeground: root.foreground

    contentWidth: width
    contentHeight: Math.max(height, contentLayout.implicitHeight)

    onIsForegroundChanged: {
        if (isForeground) {
            NotificationManager.hideAllPopups();
            NotificationManager.markAllRead();
            Time.refreshNow();
        }
    }

    ColumnLayout {
        id: contentLayout

        width: root.width
        height: root.contentHeight
        spacing: 12

        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: implicitHeight
        }

        InfoToolDrawer {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            active: root.isForeground
        }
    }
}
