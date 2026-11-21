import QtQuick
import qs.Services

// One edge's strip area on the desktop-reveal strip layer `panel`: covers the
// strips of the windows moved to that edge and picks one on click.
MouseArea {
    required property string side
    required property var panel
    readonly property var extent: panel.band(side)
    x: side === "left" ? 0 : panel.width - width
    y: extent.y
    width: extent.height > 0 ? DesktopRevealService.stripLayerWidth : 0
    height: extent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => DesktopRevealService.restore(DesktopRevealService.stripAt(side, y + mouse.y))
}
