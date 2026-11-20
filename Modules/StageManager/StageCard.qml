pragma ComponentBehavior: Bound
import QtQuick
import Clavis.WindowPreview
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// One inactive stage: up to three tilted, stacked window thumbnails with the
// stage's application icons below, like macOS Stage Manager. Hovering an icon
// brings that window to the front of the stack; clicking focuses exactly the
// window at the front.
Item {
    id: root

    required property var stage
    required property bool previewsEnabled
    readonly property var previewWindows: stage.windows.slice(0, StageManagerService.maximumPreviewWindows)
    readonly property int stackDepth: 3
    readonly property bool hovered: pointer.hovered
    // Window index brought to the front by hovering its icon; -1 keeps the
    // stage's own active window in front.
    property int highlightedIndex: -1
    readonly property int frontIndex: highlightedIndex >= 0 && highlightedIndex < previewWindows.length
                                      ? highlightedIndex : 0
    readonly property var frontWindow: previewWindows[frontIndex] || null

    // Window being dragged out of the strip (owned by the strip); its source
    // thumbnail dims while the drag is in progress.
    property var draggedWindowId: null

    signal windowActivated(var windowId)
    signal mergeRequested
    // Dragging a window out of the strip; points are in window coordinates.
    signal windowDragStarted(var window, point position)
    signal windowDragMoved(point position)
    signal windowDragFinished(point position)
    signal windowDragCanceled

    function depthOf(index) {
        if (index === frontIndex)
            return 0;
        return index < frontIndex ? index + 1 : index;
    }

    // Geometry of the front thumbnail (same formula as its card below), so the
    // app icons can sit centred on its bottom edge like macOS Stage Manager.
    readonly property var frontFrame: {
        const revision = WindowPreviewService.revision;
        return previewsEnabled && frontWindow ? WindowPreviewService.frameFor(frontWindow.id) : null;
    }
    readonly property bool frontHasFrame: !!frontFrame && frontFrame.hasFrame
    readonly property real frontAspect: frontHasFrame && frontFrame.sourceSize.height > 0
                                        ? frontFrame.sourceSize.width / frontFrame.sourceSize.height : 1.6
    readonly property real frontWidth: thumbnails.width - 16
    readonly property real frontBottom: (thumbnails.height + Math.min(frontWidth / frontAspect,
                                                                      thumbnails.height)) / 2

    implicitHeight: Math.max(thumbnails.height, iconRow.y + iconRow.height) + titleLabel.height + 10
    Accessible.role: Accessible.Button
    Accessible.name: frontWindow ? String(frontWindow.title || frontWindow.appId || "") : ""

    Item {
        id: thumbnails
        width: parent.width
        height: width * 0.66
        scale: pointer.hovered ? 1.04 : 1
        transformOrigin: Item.Left

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        transform: Rotation {
            origin.x: 0
            origin.y: thumbnails.height / 2
            axis {
                x: 0
                y: 1
                z: 0
            }
            angle: pointer.hovered ? 6 : 16
            Behavior on angle {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Click focuses the front window; dragging carries it out of the strip.
        StageWindowDragArea {
            id: stackDrag
            anchors.fill: parent
            windowData: root.frontWindow
            onTapped: {
                if (root.frontWindow)
                    root.windowActivated(root.frontWindow.id);
            }
            onDragStarted: position => root.windowDragStarted(windowData, position)
            onDragMoved: position => root.windowDragMoved(position)
            onDragFinished: position => root.windowDragFinished(position)
            onDragCanceled: root.windowDragCanceled()
        }

        Repeater {
            model: root.previewWindows

            Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property int depth: root.depthOf(index)
                readonly property WindowPreviewFrame frame: {
                    const revision = WindowPreviewService.revision;
                    return root.previewsEnabled ? WindowPreviewService.frameFor(modelData.id) : null;
                }
                readonly property bool hasFrame: !!frame && frame.hasFrame
                readonly property real aspect: hasFrame && frame.sourceSize.height > 0
                                               ? frame.sourceSize.width / frame.sourceSize.height : 1.6

                width: (thumbnails.width - 16) * (1 - depth * 0.07)
                height: Math.min(width / aspect, thumbnails.height - depth * 8)
                x: depth * 10
                y: (thumbnails.height - height) / 2 - depth * 6
                radius: 10
                clip: true
                color: Appearance.colors.colSurfaceContainerHigh
                border.width: 1
                border.color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.12)
                visible: depth < root.stackDepth
                z: root.stackDepth - depth
                opacity: (1 - depth * 0.12) * (root.draggedWindowId === modelData.id ? 0.35 : 1)

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                CaptureImage {
                    anchors.fill: parent
                    frame: card.frame
                    visible: card.hasFrame
                }
                ThemeIcon {
                    anchors.centerIn: parent
                    width: Math.min(48, parent.height * 0.5)
                    height: width
                    visible: !card.hasFrame
                    iconSource: ApplicationService.iconSource(card.modelData.iconPath || card.modelData.appId)
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        IconButton {
            z: root.stackDepth + 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: 10
            // Restoring a minimized window already brings it here.
            visible: root.hovered && !root.stage.minimized
            controlSize: 28
            iconSize: 18
            iconName: "add"
            variant: "filled"
            tooltipText: qsTr("Move to current stage")
            onClicked: root.mergeRequested()
        }
    }

    Row {
        id: iconRow
        z: 1
        // A minimized window without a saved frame already shows its large
        // icon in the middle of the card; a second small one would repeat it.
        visible: !(root.stage.minimized && !root.frontHasFrame)
        x: (root.frontWidth - width) / 2
        y: root.frontBottom - height / 2
        spacing: -6

        Behavior on y {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: root.previewWindows

            Rectangle {
                id: badge
                required property var modelData
                required property int index
                readonly property bool front: root.highlightedIndex === index
                width: 34
                height: 34
                radius: 10
                z: front ? 1 : 0
                scale: front ? 1.18 : 1
                color: Appearance.colors.colSurfaceContainerHighest
                border.width: front ? 2 : 1
                border.color: front ? Appearance.colors.colPrimary : Appearance.applyAlpha(
                                          Appearance.colors.colOnSurface, 0.1)

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }

                StageWindowDragArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    windowData: badge.modelData
                    onContainsMouseChanged: {
                        if (containsMouse)
                            root.highlightedIndex = badge.index;
                    }
                    onTapped: root.windowActivated(badge.modelData.id)
                    onDragStarted: position => root.windowDragStarted(windowData, position)
                    onDragMoved: position => root.windowDragMoved(position)
                    onDragFinished: position => root.windowDragFinished(position)
                    onDragCanceled: root.windowDragCanceled()
                }

                ThemeIcon {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    iconSource: ApplicationService.iconSource(badge.modelData.iconPath
                                                              || badge.modelData.appId)
                    sourceSize: Qt.size(52, 52)
                    fillMode: Image.PreserveAspectFit
                }
            }
        }
        Rectangle {
            visible: root.stage.windows.length > root.previewWindows.length
            width: moreLabel.implicitWidth + 16
            height: 34
            radius: 10
            color: Appearance.colors.colSurfaceContainerHighest
            border.width: 1
            border.color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.1)
            Text {
                id: moreLabel
                anchors.centerIn: parent
                text: "+" + (root.stage.windows.length - root.previewWindows.length)
                textFormat: Text.PlainText
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
        }
    }

    // Under the icons: the front window's title while hovered; otherwise
    // "Minimized" for a minimized window's stage.
    Text {
        id: titleLabel
        y: Math.max(thumbnails.height, iconRow.y + iconRow.height) + 4
        x: 4
        width: root.frontWidth - 8
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        height: 18
        text: root.hovered && root.frontWindow ? String(root.frontWindow.title || root.frontWindow.appName
                                                        || root.frontWindow.appId || "") :
                                                 root.stage.minimized ?
                                                     // Same wording as the Dock's window cards; reuse their translation.
                                                     qsTranslate("DockWindowCard", "Minimized") : ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Fonts.ui
        font.pixelSize: 12
        color: Appearance.colors.colOnSurface
    }

    HoverHandler {
        id: pointer
        onHoveredChanged: {
            if (!hovered)
                root.highlightedIndex = -1;
        }
    }
}
