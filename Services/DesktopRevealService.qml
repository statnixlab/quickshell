pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri

// "Click wallpaper to reveal desktop", like macOS: the floating windows of the
// active workspace scatter to the left and right screen edges, leaving thin
// strips visible. They come back only when the wallpaper is clicked again, or
// when one of them is clicked (its strip), which also focuses that window.
// Scrolling or keyboard focus changes among tiled windows leave them aside.
// Tiled windows stay where niri's layout puts them.
//
// Window geometry is not tracked by the niri plugin, so it is queried once per
// action. Moves are relative, so restoring needs no knowledge of niri's
// absolute coordinate origin: delta = saved position - current position.
Singleton {
    id: root

    property bool enabled: true
    readonly property bool active: Object.keys(saved).length > 0
    // window id -> {x, y} in workspace-view coordinates before revealing.
    property var saved: ({})
    property real outputWidth: 0
    property real outputHeight: 0
    property string outputName: ""
    // Where each hidden window's strip is: [{id, side, y, height}] in output
    // coordinates. The strip layer covers these, so hovering a strip does not
    // trigger niri's focus-follows-mouse, and a click picks the window.
    property var strips: []
    // Width of the strip layer on each edge; covers the visible part of the
    // windows even where niri keeps a little more of them on screen.
    readonly property real stripLayerWidth: Math.max(Math.round(outputWidth * stripShare), 80)
    property string pending: ""
    property double revealedAt: 0
    property double workspaceId: 0
    // Focus when the windows moved aside. The niri plugin also emits its
    // focus signals for unrelated window updates (such as these moves), so
    // only a real change of focused window or workspace restores.
    property double focusedAtReveal: 0

    // Strip left on screen, as a share of the output width (about 67 px on
    // a 1920 px wide logical output, similar to macOS).
    readonly property real stripShare: 0.035
    // Band of the screen height over which the strips on one edge fan out.
    // The top bar and the Dock cover the edges above and below it.
    readonly property real fanTop: 0.18
    readonly property real fanBottom: 0.82

    // Target positions that scatter windows like macOS: by horizontal order,
    // the left half goes to the left edge and the right half to the right
    // edge; on each edge the windows keep their vertical order and spread
    // evenly over the fan band, so their strips do not sit on top of each
    // other. Identical positions are ordered by window id.
    function scatter(items) {
        const byX = items.slice().sort((a, b) => (a.cx - b.cx) || (a.id - b.id));
        let leftCount = Math.floor(byX.length / 2);
        // An odd middle window goes to the side its centre is on.
        if (byX.length % 2 === 1 && byX[leftCount].cx < outputWidth / 2)
            leftCount++;
        const strip = Math.round(outputWidth * stripShare);
        const targets = {};
        const place = (side, onEdge) => {
            onEdge.sort((a, b) => (a.cy - b.cy) || (a.id - b.id));
            const top = outputHeight * fanTop;
            const span = outputHeight * (fanBottom - fanTop);
            onEdge.forEach((item, index) => {
                const cy = top + span * (index + 1) / (onEdge.length + 1);
                targets[item.id] = {
                    side: side,
                    x: side === "left" ? strip - item.width : outputWidth - strip,
                    y: Math.round(cy - item.height / 2),
                    height: item.height
                };
            });
        };
        place("left", byX.slice(0, leftCount));
        place("right", byX.slice(leftCount));
        return targets;
    }

    function toggle(screen) {
        if (active)
            restore();
        else
            reveal(screen);
    }

    function reveal(screen) {
        if (!enabled || !Niri.connected || Niri.inOverview || query.running || !screen)
            return false;
        const workspace = Niri.activeWorkspaceForOutput(screen.name);
        if (!workspace || !workspace.id)
            return false;
        outputWidth = screen.width;
        outputHeight = screen.height;
        outputName = screen.name;
        workspaceId = workspace.id;
        pending = "reveal";
        query.running = true;
        return true;
    }

    // focusId: the hidden window that was clicked; it keeps focus once back.
    property double focusAfterRestore: 0

    function restore(focusId) {
        if (!active || query.running)
            return false;
        focusAfterRestore = focusId || 0;
        pending = "restore";
        query.running = true;
        return true;
    }

    // The hidden window whose strip on `side` is under y (output coordinates):
    // the one whose band contains y and whose centre is nearest.
    function stripAt(side, y) {
        let best = null;
        for (const strip of strips) {
            if (strip.side !== side || y < strip.y || y > strip.y + strip.height)
                continue;
            const distance = Math.abs(strip.y + strip.height / 2 - y);
            if (!best || distance < best.distance)
                best = {
                    id: strip.id,
                    distance: distance
                };
        }
        return best ? best.id : 0;
    }

    function moveBy(id, dx, dy) {
        if (Math.abs(dx) < 1 && Math.abs(dy) < 1)
            return;
        const signed = value => (value >= 0 ? "+" : "") + Math.round(value);
        Quickshell.execDetached(["niri", "msg", "action", "move-floating-window", "--id", String(id), "--x="
                                 + signed(dx), "--y=" + signed(dy)]);
    }

    function apply(text) {
        let windows = [];
        try {
            windows = JSON.parse(text);
        } catch (error) {
            console.warn("DesktopReveal: cannot read niri windows:", error);
            pending = "";
            return;
        }
        const geometry = window => {
            const layout = window.layout || {};
            const pos = layout.tile_pos_in_workspace_view;
            const size = layout.window_size;
            return pos && size ? {
                                     x: pos[0],
                                     y: pos[1],
                                     width: size[0],
                                     height: size[1]
                                 } : null;
        };
        if (pending === "reveal") {
            const next = {};
            const items = [];
            for (const window of windows) {
                if (window.workspace_id !== workspaceId || !window.is_floating || window.is_minimized)
                    continue;
                const g = geometry(window);
                if (!g)
                    continue;
                next[window.id] = {
                    x: g.x,
                    y: g.y
                };
                items.push({
                               id: window.id,
                               x: g.x,
                               y: g.y,
                               width: g.width,
                               height: g.height,
                               cx: g.x + g.width / 2,
                               cy: g.y + g.height / 2
                           });
            }
            const targets = scatter(items);
            const placed = [];
            for (const item of items) {
                const target = targets[item.id];
                moveBy(item.id, target.x - item.x, target.y - item.y);
                placed.push({
                                id: item.id,
                                side: target.side,
                                y: Math.max(0, target.y),
                                height: target.height
                            });
            }
            strips = placed;
            saved = next;
            revealedAt = Date.now();
            focusedAtReveal = Niri.focusedWindow.id || 0;
            // Clicking the strip of the window that already has focus would not
            // change focus; hand focus to the tiling layer so every strip can.
            if (next[focusedAtReveal])
                Quickshell.execDetached(["niri", "msg", "action", "focus-tiling"]);
        } else if (pending === "restore") {
            for (const window of windows) {
                const original = saved[window.id];
                const g = original && window.is_floating ? geometry(window) : null;
                if (g)
                    moveBy(window.id, original.x - g.x, original.y - g.y);
            }
            saved = ({});
            strips = [];
            if (focusAfterRestore)
                Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(
                                             focusAfterRestore)]);
            focusAfterRestore = 0;
        }
        pending = "";
    }

    Process {
        id: query
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("DesktopReveal: niri msg windows failed:", exitCode);
                root.pending = "";
            }
        }
    }

    Connections {
        target: Niri
        // Only a hidden window gaining focus means its strip was clicked
        // (or it was chosen on purpose). Focus moving among tiled windows,
        // e.g. by scrolling, does not bring the windows back.
        function onFocusedWindowChanged() {
            if (!root.active)
                return;
            const id = Niri.focusedWindow.id || 0;
            // The focus-tiling hand-over right after revealing is not a click.
            if (Date.now() - root.revealedAt < 600) {
                root.focusedAtReveal = id;
                return;
            }
            if (id !== root.focusedAtReveal && root.saved[id])
                root.restore(id);
            root.focusedAtReveal = id;
        }
    }
}
