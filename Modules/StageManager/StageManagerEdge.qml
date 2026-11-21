pragma ComponentBehavior: Bound
import QtQuick
import qs.Modules.Dock
import qs.Services

// One screen edge of Stage Manager: its strip, the edge trigger and the dwell
// timer. Only the middle half of the edge reacts, keeping the corners free for
// hot corners and the bar. The pointer must rest there for the configured
// delay: passing over the edge while moving, scrolling or dragging a
// scrollbar does not open the strip.
Item {
    id: root

    required property var targetScreen
    // "left": other stages; "right": windows of the current stage.
    required property string edge

    StageManagerStrip {
        id: strip
        targetScreen: root.targetScreen
        edge: root.edge
    }
    DockEdgeTrigger {
        id: trigger
        screen: root.targetScreen
        edge: root.edge
        dragMimeType: "application/x-clavis-stage"
        activeLength: root.targetScreen.height * 0.5
        onHoveredChanged: hovered ? dwell.restart() : dwell.stop()
    }
    Timer {
        id: dwell
        interval: UiPreferences.stageManagerRevealDelay
        onTriggered: {
            if (trigger.hovered)
                strip.reveal();
        }
    }
}
