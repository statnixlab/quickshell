import QtQuick

// Press-and-move turns a click target into a drag source for one window
// in the Stage Manager strip; a plain click still emits tapped().
MouseArea {
    id: area
    property var windowData: null
    // false: only clicks; pressing and moving never starts a drag.
    property bool dragEnabled: true
    property bool dragging: false
    property point pressPoint

    signal tapped
    signal dragStarted(point position)
    signal dragMoved(point position)
    signal dragFinished(point position)
    signal dragCanceled

    preventStealing: dragging
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    onPressed: mouse => {
        pressPoint = Qt.point(mouse.x, mouse.y);
        dragging = false;
    }
    onPositionChanged: mouse => {
        if (!pressed || !windowData || !dragEnabled)
            return;
        if (!dragging) {
            if (Math.abs(mouse.x - pressPoint.x) < 8 && Math.abs(mouse.y - pressPoint.y) < 8)
                return;
            dragging = true;
            dragStarted(mapToItem(null, mouse.x, mouse.y));
        }
        dragMoved(mapToItem(null, mouse.x, mouse.y));
    }
    onReleased: mouse => {
        if (dragging) {
            dragging = false;
            dragFinished(mapToItem(null, mouse.x, mouse.y));
        } else if (containsMouse) {
            tapped();
        }
    }
    onCanceled: {
        if (dragging) {
            dragging = false;
            dragCanceled();
        }
    }
}
