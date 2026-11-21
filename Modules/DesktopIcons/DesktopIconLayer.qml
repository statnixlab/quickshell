pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Clavis.Files
import Clavis.Niri
import qs.Common
import qs.Modules.Dock
import qs.Services
import qs.Widgets.common

// Icons for the files in the desktop directory, arranged in columns from the
// top-right corner like on macOS. The layer lives inside the desktop card
// surface below the cards, so cards stay on top and keep their input.
//
// While shown it takes input over the whole screen: that is what lets files
// be dropped anywhere on the desktop. A plain click on empty space is passed
// on to DesktopRevealService, which would otherwise have received it.
Item {
    id: root

    required property var screen
    readonly property bool primary: PrimaryDisplayService.activePrimary !== "" ? String(screen.name)
                                                                                 === PrimaryDisplayService.activePrimary :
                                                                                 Quickshell.screens.length
                                                                                 > 0 && Quickshell.screens[0]
                                                                                 === screen
    readonly property bool shown: DesktopIconService.ready && DesktopIconService.enabled && primary
                                  && DesktopIconService.desktopPath !== ""
    // Region for the host surface's input mask.
    readonly property Item inputItem: shown ? root : null

    readonly property real cellWidth: 92
    readonly property real cellHeight: 104
    readonly property real cellGap: 4
    readonly property real edgeGap: 16
    readonly property real barInset: PersonalizationConfig.barEnabled ? PersonalizationConfig.barEdgeMargin
                                                                        + PersonalizationConfig.barThickness :
                                                                        0
    readonly property real dockInset: DockService.enabled && !DockService.autoHide ? DockService.iconSize
                                                                                     + 32 : 0
    readonly property real topInset: edgeGap + (PersonalizationConfig.barPosition === "top" ? barInset : 0) + (
                                         DockService.position === "top" ? dockInset : 0)
    readonly property real rightInset: edgeGap + (PersonalizationConfig.barPosition === "right" ? barInset :
                                                                                                  0) + (DockService.position
                                                                                                        === "right"
                                                                                                        ? dockInset :
                                                                                                          0)
    readonly property real bottomInset: edgeGap + (PersonalizationConfig.barPosition === "bottom" ? barInset :
                                                                                                    0) + (DockService.position
                                                                                                          === "bottom"
                                                                                                          ? dockInset :
                                                                                                            0)
    readonly property int rows: Math.max(1, Math.floor((height - topInset - bottomInset + cellGap) / (cellHeight
                                                                                                      + cellGap)))

    property var selectedUrls: []
    property var menuInfo: null
    property point bandStart: Qt.point(0, 0)
    property point bandEnd: Qt.point(0, 0)
    property bool banding: false

    visible: shown

    // Items to keep icons clear of (the desktop cards), in this item's
    // coordinate space or a sibling's with the same origin.
    property var obstacles: []

    // Free cells for the icons: columns from the right edge, top to bottom
    // in each column, like on macOS. Cells under a desktop card are skipped.
    readonly property var cells: {
        const rects = [];
        for (const item of obstacles) {
            if (item && item.visible && item.width > 1 && item.height > 1) {
                const origin = item.mapToItem(root, 0, 0);
                rects.push({
                               x: origin.x - cellGap,
                               y: origin.y - cellGap,
                               right: origin.x + item.width + cellGap,
                               bottom: origin.y + item.height + cellGap
                           });
            }
        }
        const wanted = folder.count;
        const result = [];
        const columns = Math.max(1, Math.floor((width - rightInset - edgeGap + cellGap) / (cellWidth
                                                                                           + cellGap)));
        for (let column = 0; column < columns && result.length < wanted; column++) {
            const x = width - rightInset - cellWidth - column * (cellWidth + cellGap);
            for (let row = 0; row < rows && result.length < wanted; row++) {
                const y = topInset + row * (cellHeight + cellGap);
                const blocked = rects.some(rect => x < rect.right && x + cellWidth > rect.x && y
                                                   < rect.bottom && y + cellHeight > rect.y);
                if (!blocked)
                    result.push(Qt.point(x, y));
            }
        }
        // A desktop with more files than free cells stacks the rest in the
        // last free cell instead of dropping them.
        while (result.length < wanted)
            result.push(result.length > 0 ? result[result.length - 1] : Qt.point(width - rightInset
                                                                                 - cellWidth, topInset));
        return result;
    }

    function isSelected(url) {
        return selectedUrls.indexOf(String(url)) >= 0;
    }

    function select(url, modifiers) {
        const key = String(url);
        if (modifiers & Qt.ControlModifier)
            selectedUrls = isSelected(key) ? selectedUrls.filter(value => value !== key) : selectedUrls.concat(
                                                 [key]);
        else
            selectedUrls = [key];
    }

    function selectedInfos() {
        const result = [];
        for (let index = 0; index < icons.count; index++) {
            const tile = icons.itemAt(index);
            if (tile && isSelected(tile.fileInfo.url))
                result.push(tile.fileInfo);
        }
        return result;
    }

    function updateBandSelection() {
        const left = Math.min(bandStart.x, bandEnd.x);
        const right = Math.max(bandStart.x, bandEnd.x);
        const top = Math.min(bandStart.y, bandEnd.y);
        const bottom = Math.max(bandStart.y, bandEnd.y);
        const next = [];
        for (let index = 0; index < icons.count; index++) {
            const tile = icons.itemAt(index);
            if (tile && tile.x < right && tile.x + tile.width > left && tile.y < bottom && tile.y
                    + tile.height > top)
                next.push(String(tile.fileInfo.url));
        }
        selectedUrls = next;
    }

    function tileAt(x, y) {
        for (let index = 0; index < icons.count; index++) {
            const tile = icons.itemAt(index);
            if (tile && x >= tile.x && x < tile.x + tile.width && y >= tile.y && y < tile.y + tile.height)
                return tile;
        }
        return null;
    }

    function openMenu(menu, x, y) {
        menu.popup(root, x, y);
    }

    // Drop the selection when the files go away (trashed, renamed, ...).
    function pruneSelection() {
        const present = [];
        for (let index = 0; index < icons.count; index++) {
            const tile = icons.itemAt(index);
            if (tile)
                present.push(String(tile.fileInfo.url));
        }
        const next = selectedUrls.filter(url => present.indexOf(url) >= 0);
        if (next.length !== selectedUrls.length)
            selectedUrls = next;
    }

    onShownChanged: {
        if (!shown) {
            selectedUrls = [];
            itemMenu.close();
            desktopMenu.close();
        }
    }

    DockFolderModel {
        id: folder

        folder: root.shown ? DesktopIconService.desktopUrl : ""
        sort: DesktopIconService.sort
        onRevisionChanged: Qt.callLater(root.pruneSelection)
    }

    // Empty desktop: click to deselect (and reveal the desktop), drag to
    // select with a band, right-click for the desktop menu.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            // Icons handle their own presses; this area is only empty space.
            if (root.tileAt(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            root.bandStart = Qt.point(mouse.x, mouse.y);
            root.bandEnd = root.bandStart;
            root.banding = false;
        }
        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton))
                return;
            root.bandEnd = Qt.point(mouse.x, mouse.y);
            if (!root.banding && Math.abs(root.bandEnd.x - root.bandStart.x) + Math.abs(root.bandEnd.y
                                                                                        - root.bandStart.y)
                    > 6)
                root.banding = true;
            if (root.banding)
                root.updateBandSelection();
        }
        onReleased: mouse => {
            const wasBanding = root.banding;
            root.banding = false;
            if (mouse.button === Qt.RightButton) {
                root.selectedUrls = [];
                root.openMenu(desktopMenu, mouse.x, mouse.y);
                return;
            }
            if (wasBanding)
                return;
            root.selectedUrls = [];
            if (DesktopRevealService.enabled && Niri.connected)
                DesktopRevealService.toggle(root.screen);
        }
    }

    Rectangle {
        visible: root.banding
        x: Math.min(root.bandStart.x, root.bandEnd.x)
        y: Math.min(root.bandStart.y, root.bandEnd.y)
        width: Math.abs(root.bandEnd.x - root.bandStart.x)
        height: Math.abs(root.bandEnd.y - root.bandStart.y)
        radius: 4
        color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.18)
        border.width: 1
        border.color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.7)
    }

    Repeater {
        id: icons

        model: root.shown ? folder.model : null

        DesktopIconTile {
            id: tile

            required property int index
            readonly property point cell: root.cells[index] || Qt.point(0, 0)

            x: cell.x
            y: cell.y
            width: root.cellWidth
            height: root.cellHeight
            selected: root.isSelected(fileInfo.url)
            onSelectRequested: modifiers => root.select(fileInfo.url, modifiers)
            onOpenRequested: {
                root.select(fileInfo.url, 0);
                DesktopIconService.open(fileInfo);
            }
            onMenuRequested: (x, y) => {
                if (!tile.selected)
                    root.select(tile.fileInfo.url, 0);
                root.menuInfo = tile.fileInfo;
                const point = tile.mapToItem(root, x, y);
                root.openMenu(itemMenu, point.x, point.y);
            }
        }
    }

    // Files dropped from a file manager become shortcuts (symbolic links);
    // the originals are never moved or copied.
    DropArea {
        id: drop

        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: dragEvent => {
            const urls = Array.from(dragEvent.urls || []);
            if (urls.length === 0 || urls.every(url => DesktopIconService.isOnDesktop(url)))
                dragEvent.accepted = false;
        }
        onDropped: dropEvent => {
            const count = DesktopIconService.createShortcuts(dropEvent.urls);
            if (count > 0) {
                dropEvent.accept(dropEvent.supportedActions & Qt.LinkAction ? Qt.LinkAction : Qt.CopyAction);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: drop.containsDrag
        color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.08)
        border.width: 2
        border.color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.5)
        radius: Appearance.rounding.large
    }

    StyledMenu {
        id: itemMenu

        readonly property var targets: root.selectedInfos()
        readonly property bool single: targets.length <= 1
        readonly property bool allLinks: targets.length > 0 && targets.every(info => !!info.isLink)

        StyledMenuItem {
            text: qsTr("Open")
            onTriggered: {
                for (const info of itemMenu.targets)
                    DesktopIconService.open(info);
            }
        }
        StyledMenuItem {
            text: qsTr("Show in File Manager")
            enabled: itemMenu.single && !!root.menuInfo
            onTriggered: DesktopIconService.reveal(root.menuInfo)
        }
        MenuSeparator {}
        StyledMenuItem {
            text: itemMenu.allLinks ? qsTr("Remove Shortcut") : qsTr("Move to Trash")
            destructive: true
            onTriggered: {
                DesktopIconService.moveToTrash(itemMenu.targets.map(info => info.url));
                root.selectedUrls = [];
            }
        }
    }

    StyledMenu {
        id: desktopMenu

        StyledMenuItem {
            text: qsTr("Sort by Name")
            checkable: true
            checked: DesktopIconService.sort === "name"
            onTriggered: DesktopIconService.setSort("name")
        }
        StyledMenuItem {
            text: qsTr("Sort by Date Modified")
            checkable: true
            checked: DesktopIconService.sort === "modified"
            onTriggered: DesktopIconService.setSort("modified")
        }
        StyledMenuItem {
            text: qsTr("Sort by Kind")
            checkable: true
            checked: DesktopIconService.sort === "kind"
            onTriggered: DesktopIconService.setSort("kind")
        }
        StyledMenuItem {
            text: qsTr("Sort by Size")
            checkable: true
            checked: DesktopIconService.sort === "size"
            onTriggered: DesktopIconService.setSort("size")
        }
        MenuSeparator {}
        StyledMenuItem {
            text: qsTr("Open Desktop Folder")
            onTriggered: DesktopIconService.openDesktopFolder()
        }
        StyledMenuItem {
            text: qsTr("Hide Desktop Icons")
            onTriggered: DesktopIconService.setEnabled(false)
        }
    }
}
