pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Clavis.Niri
import qs.Services

// A transparent, input-only surface on the background layer of each screen.
// Clicks reach it only where no window or desktop card covers the wallpaper.
Item {
    id: root

    Variants {
        model: DesktopRevealService.enabled && Niri.connected ? Quickshell.screens : []

        PanelWindow {
            id: catcher
            required property var modelData

            screen: modelData
            color: "transparent"
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "clavis-desktop-reveal"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: DesktopRevealService.toggle(catcher.modelData)
            }
        }
    }

    // While windows are aside: a transparent layer over their strips on the
    // left and right edges. It takes the pointer instead of the windows, so
    // niri's focus-follows-mouse does not focus a strip the pointer passes
    // over; clicking a strip restores the windows and focuses that one.
    Variants {
        model: DesktopRevealService.active ? Quickshell.screens.filter(output => output.name
                                                                                 === DesktopRevealService.outputName) :
                                             []

        PanelWindow {
            id: stripLayer
            required property var modelData

            // Vertical extent of the strips on one edge, in output coordinates.
            function band(side) {
                let top = -1;
                let bottom = -1;
                for (const strip of DesktopRevealService.strips) {
                    if (strip.side !== side)
                        continue;
                    top = top < 0 ? strip.y : Math.min(top, strip.y);
                    bottom = Math.max(bottom, Math.min(stripLayer.height, strip.y + strip.height));
                }
                return top < 0 ? {
                                     y: 0,
                                     height: 0
                                 } : {
                    y: top,
                    height: bottom - top
                };
            }

            screen: modelData
            color: "transparent"
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "clavis-desktop-reveal-strips"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                Region {
                    item: leftBand
                }
                Region {
                    item: rightBand
                }
            }

            DesktopRevealStripBand {
                id: leftBand
                side: "left"
                panel: stripLayer
            }
            DesktopRevealStripBand {
                id: rightBand
                side: "right"
                panel: stripLayer
            }
        }
    }

    IpcHandler {
        target: "desktop-reveal"
        function toggle(): bool {
            const screen = Quickshell.screens.find(output => output.name === Niri.currentOutput)
                  || Quickshell.screens[0];
            if (DesktopRevealService.active)
                return DesktopRevealService.restore();
            return DesktopRevealService.reveal(screen);
        }
        function restore(): bool {
            return DesktopRevealService.restore();
        }
        function setEnabled(enabled: bool): void {
            UiPreferences.setDesktopRevealEnabled(enabled);
        }
        function status(): string {
            return JSON.stringify({
                                      enabled: DesktopRevealService.enabled,
                                      active: DesktopRevealService.active,
                                      windows: Object.keys(DesktopRevealService.saved)
                                  });
        }
    }
}
