pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Monitor order (left to right) and per-monitor RGB full range.
 *
 * Why a generated config file instead of `hyprctl eval` like WorkspaceRules does: once a
 * config rule exists for an output, Hyprland ignores hl.monitor() applied at runtime, so a
 * mode/position pushed through eval is silently dropped. The only thing that sticks is
 * writing config and reloading — which is what scripts/displaylayout.sh does.
 *
 * Order is explicit, not `position = auto-right`, because auto-right chains monitors in an
 * internal order that does not match the physical desk, and two monitors of the SAME model
 * report an identical description to hyprctl — nothing can tell them apart automatically.
 * The user picks the order; the script derives the pixel positions from it, honouring scale.
 *
 * Full range fixes the washed-out picture: i915 with "Broadcast RGB = Automatic" sends
 * limited (16-235) on a CEA mode. A CVT-RB (non-CEA) modeline of the same resolution forces
 * 0-255. The script computes it per monitor with `cvt -r`, so it is not 1080p-only.
 */
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/displaylayout.sh"

    function load() {
        // dummy to force init
    }

    // Connected monitors, left to right as Hyprland currently has them.
    readonly property var monitors: (HyprlandData.monitors ?? []).slice().sort((a, b) => (a.x - b.x) || (a.y - b.y))

    /**
     * Monitors in the saved order. Saved names that aren't plugged in right now are skipped,
     * and anything connected but not in the saved list is appended in its current left-to-right
     * position — so a new monitor shows up instead of vanishing, and another desk with
     * different outputs still gets a sane order without any saved entry matching.
     */
    readonly property var ordered: {
        const saved = Config.options.displayLayout.order ?? [];
        const byName = {};
        for (const m of root.monitors)
            byName[m.name] = m;

        let out = [];
        for (const name of saved) {
            if (byName[name]) {
                out.push(byName[name]);
                delete byName[name];
            }
        }
        for (const m of root.monitors) {
            if (byName[m.name])
                out.push(m);
        }
        return out;
    }

    function isFullRange(name) {
        return (Config.options.displayLayout.fullRange ?? []).includes(name);
    }

    function setFullRange(name, enabled) {
        const cur = (Config.options.displayLayout.fullRange ?? []).slice();
        const at = cur.indexOf(name);
        if (enabled && at < 0)
            cur.push(name);
        else if (!enabled && at >= 0)
            cur.splice(at, 1);
        else
            return;
        Config.options.displayLayout.fullRange = cur;
    }

    function isAbove(name) {
        return (Config.options.displayLayout.above ?? []).includes(name);
    }

    function setAbove(name, enabled) {
        const cur = (Config.options.displayLayout.above ?? []).slice();
        const at = cur.indexOf(name);
        if (enabled && at < 0)
            cur.push(name);
        else if (!enabled && at >= 0)
            cur.splice(at, 1);
        else
            return;
        Config.options.displayLayout.above = cur;
    }

    /**
     * Moves a monitor one slot left (-1) or right (+1). Persists the WHOLE current order, not
     * just the pair, so the saved list stops depending on whatever Hyprland happened to
     * enumerate first.
     */
    function move(name, delta) {
        let names = root.ordered.map(m => m.name);
        const at = names.indexOf(name);
        const to = at + delta;
        if (at < 0 || to < 0 || to >= names.length)
            return;
        names.splice(to, 0, names.splice(at, 1)[0]);
        Config.options.displayLayout.order = names;
    }

    function positionOf(name) {
        const entry = (Config.options.displayLayout.positions ?? []).find(e => e.startsWith(name + "="));
        return entry ? entry.split("=")[1] : "";
    }

    // True once any position has been imported — the arrows and Above stop having an effect
    // then, and the UI needs to say so rather than let them look live.
    readonly property bool usingImportedPositions: (Config.options.displayLayout.positions ?? []).length > 0

    /**
     * Pulls the dragged coordinates out of ~/.config/hypr/monitors.conf, the file nwg-displays
     * writes. Nothing reads that file (hyprland.lua only sources monitors.lua), and the mode it
     * records is a plain "1920x1080@59.72" which loses the full-range modeline — so only the
     * coordinates are taken and this service keeps owning the mode.
     */
    function importFromNwg() {
        nwgProc.buffer = "";
        nwgProc.running = true;
    }

    function clearImportedPositions() {
        Config.options.displayLayout.positions = [];
    }

    // "<output>[:full][:above][:sat=X][:pos=XxY]" per monitor, in order — the script's format.
    readonly property var scriptArgs: root.ordered.map(m => {
        let s = m.name;
        if (root.isFullRange(m.name))
            s += ":full";
        if (root.isAbove(m.name))
            s += ":above";
        const satEntry = (Config.options.displayLayout.saturation ?? []).find(e => e.startsWith(m.name + "="));
        const sat = satEntry ? parseFloat(satEntry.split("=")[1]) : 1;
        if (sat && sat !== 1)
            s += ":sat=" + sat;
        const pos = root.positionOf(m.name);
        if (pos)
            s += ":pos=" + pos;
        return s;
    })

    // Drive off the data, not the click: the settings window and a hand-edited config.json
    // change the same properties, and hanging the trigger on move()/setFullRange() alone left
    // those paths silently doing nothing. apply() dedups against appliedArgs, so the reload it
    // ends with can't feed back into another run.
    onScriptArgsChanged: applyTimer.restart()

    property string appliedArgs: ""

    function apply(force) {
        const args = root.scriptArgs.join(" ");
        if (root.ordered.length === 0)
            return;
        if (!force && args === root.appliedArgs)
            return;
        root.appliedArgs = args;
        // The script writes ~/.config/hypr/fullrange.lua; only a reload makes Hyprland read it.
        applyProc.command = ["bash", "-c", `'${root.scriptPath}' ${args} && hyprctl reload`];
        applyProc.running = true;
    }

    Timer {
        id: applyTimer
        interval: 400 // arrows fire on every click; a reload per click would thrash the outputs
        onTriggered: root.apply(false)
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Plugging or unplugging changes which outputs exist, so the generated file has to
            // be rewritten for the new set. Not on configreloaded: our own apply() ends in a
            // reload, and re-applying there would loop.
            if (event.name === "monitoradded" || event.name === "monitorremoved")
                applyTimer.restart();
        }
    }

    Process {
        id: applyProc
        // Moving outputs reshuffles the open workspaces, and workspace rules only steer new ones.
        onExited: exitCode => {
            if (exitCode === 0)
                settleTimer.restart();
            else
                console.warn("[DisplayLayout] displaylayout.sh/hyprctl reload exited with", exitCode);
        }
    }

    Timer {
        id: settleTimer
        interval: 1000 // shortcut: fixed wait for the reload's events to refresh HyprlandData; raise it if a move gets missed
        onTriggered: WorkspaceRules.applyNow()
    }

    Process {
        id: nwgProc
        property string buffer: ""
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/monitors.conf"]
        stdout: SplitParser {
            // "monitor=eDP-1,1920x1080@60.16,1001x1080,1.25" — name is field 0, position field 2.
            // Resolution and scale are deliberately dropped: the script derives the mode from
            // the monitor's own native resolution and reads the live scale from hyprctl.
            onRead: line => {
                const m = /^monitor\s*=\s*([^,]+),[^,]+,(-?\d+)x(-?\d+)/.exec(line.trim());
                if (m)
                    nwgProc.buffer += (nwgProc.buffer ? " " : "") + `${m[1].trim()}=${m[2]}x${m[3]}`;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 || nwgProc.buffer === "")
                return; // no nwg file yet, or it held nothing parseable — leave the config alone
            Config.options.displayLayout.positions = nwgProc.buffer.split(" ");
        }
    }
}
