pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property real clearance: 12
    property var bars: []
    property var keystones: []

    function registerBar(item) {
        bars = bars.concat([item]);
    }

    function unregisterBar(item) {
        bars = bars.filter(candidate => candidate !== item);
    }

    function registerKeystone(item) {
        keystones = keystones.concat([item]);
    }

    function unregisterKeystone(item) {
        keystones = keystones.filter(candidate => candidate !== item);
    }

    function matchingPanel(items, screen, edge) {
        if (!screen)
            return null;
        return items.find(item => item && !item.vertical && item.screen && item.screen.name === screen.name
                                  && item.popupEdge === edge) || null;
    }

    function barFor(screen, edge) {
        return matchingPanel(bars, screen, edge);
    }

    function keystoneFor(screen, edge) {
        return matchingPanel(keystones, screen, edge);
    }
}
