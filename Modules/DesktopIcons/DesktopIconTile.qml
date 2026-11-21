import QtQuick
import qs.Common
import qs.Modules.Dock
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var fileInfo
    property bool selected: false
    property real iconSize: 52
    readonly property var application: DesktopIconService.applicationFor(fileInfo)
    readonly property var displayInfo: application && application.icon ? Object.assign({}, fileInfo, {
                                                                                           icon: application.icon
                                                                                       }) : fileInfo
    readonly property string displayName: {
        const name = String(fileInfo.name || "");
        if (application && application.name)
            return application.name;
        return name;
    }
    readonly property bool hovered: pointer.hovered
    readonly property alias iconItem: artwork

    signal selectRequested(int modifiers)
    signal openRequested
    signal menuRequested(real x, real y)

    Accessible.role: Accessible.Button
    Accessible.name: displayName
    Accessible.onPressAction: root.openRequested()

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.selected ? Appearance.applyAlpha(Appearance.colors.colPrimary, 0.34) : root.hovered
                               ? Appearance.applyAlpha("#ffffff", 0.14) : "transparent"
        border.width: root.selected ? 1 : 0
        border.color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.7)
    }

    DockFileIcon {
        id: artwork

        width: root.iconSize
        height: width
        x: (root.width - width) / 2
        y: 6
        info: root.displayInfo
    }

    // The label sits on arbitrary wallpaper, so it is white with a soft
    // shadow instead of a themed colour.
    Text {
        x: label.x + 1
        y: label.y + 1
        width: label.width
        height: label.height
        text: label.text
        textFormat: Text.PlainText
        color: Appearance.applyAlpha("#000000", 0.7)
        font: label.font
        horizontalAlignment: label.horizontalAlignment
        elide: label.elide
        wrapMode: label.wrapMode
        maximumLineCount: label.maximumLineCount
    }

    Text {
        id: label

        x: 4
        y: artwork.y + artwork.height + 6
        width: root.width - 8
        height: root.height - y - 4
        text: root.displayName
        textFormat: Text.PlainText
        color: "#ffffff"
        font.family: Fonts.ui
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }

    HoverHandler {
        id: pointer
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onPressedChanged: {
            if (pressed)
                fileDrag.dragged = false;
        }
        onSingleTapped: eventPoint => {
            if (!fileDrag.dragged)
                root.selectRequested(point.modifiers);
        }
        onDoubleTapped: {
            if (!fileDrag.dragged)
                root.openRequested();
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => root.menuRequested(eventPoint.position.x, eventPoint.position.y)
    }

    StyledToolTip {
        text: root.displayName
        textFormat: Text.PlainText
        extraVisibleCondition: root.visible && pointer.hovered && label.truncated && !fileDrag.dragged &&
                               !DockService.fileDragActive
    }

    // Dragging an icon offers its file to other applications and to the
    // Dock, which can pin it.
    DockFileDrag {
        id: fileDrag

        enabled: fileUrl !== ""
        fileUrl: String(root.fileInfo.url || "")
        iconItem: artwork
    }
}
