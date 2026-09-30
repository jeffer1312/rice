pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Gives each connected monitor its own block of workspaces.
 *
 * Hyprland's Lua parser rejects `hyprctl keyword` ("keyword can't work with non-legacy
 * parsers. Use eval."), so rules are pushed through `hyprctl eval` instead. Re-applies
 * itself when a monitor is plugged/unplugged, so the layout follows the environment
 * without anyone editing custom/rules.lua by hand.
 */
Singleton {
    id: root

    // Every workspace in 1..lastWorkspace always gets a rule. Rules added via eval cannot be
    // removed one by one, so covering the whole span means a range change overwrites the old
    // rules instead of leaving stale ones pointing at the wrong monitor.
    readonly property int lastWorkspace: 30

    function load() {
        // dummy to force init
    }

    // The bar draws a fixed window of `shown` workspaces around whatever is active, bucketed
    // from workspace 1 (see modules/ii/bar/Workspaces.qml: floor((active - 1) / shown)). Any
    // other block size and two monitors end up drawing the same numbers, so the block size is
    // not ours to choose: it IS the bar's.
    readonly property int perMonitor: Config.options.bar.workspaces.shown

    // All monitors of one machine form one shortcut group (workspaceGroupSize): Super+N
    // buckets from workspace 1 in spans of groupSpan. A firstWorkspace off a span boundary
    // (e.g. 5 with span 8) puts the ranges out of phase with both the shortcuts and the bar,
    // so it snaps to 1 + k*span (1, 9, 17...). k>0 is the multi-PC scheme: PC2 takes span 2.
    readonly property int groupSpan: root.perMonitor * Math.max(1, root.monitors.length)
    readonly property int firstWorkspace: 1 + Math.max(0, Math.round((Config.options.workspaceRules.firstWorkspace - 1) / root.groupSpan)) * root.groupSpan

    readonly property var monitors: (HyprlandData.monitors ?? []).slice().sort((a, b) => (a.x - b.x) || (a.y - b.y))

    /**
     * Monitor name -> block index. Always a permutation: every monitor gets exactly one block
     * and no block is shared, so ranges can never silently overlap. Saved picks are honoured
     * first; whoever is left fills the free blocks in left-to-right order.
     */
    readonly property var assignment: {
        let taken = {};
        let result = {};
        for (const monitor of root.monitors) {
            const saved = Config.options.workspaceRules.blocks.find(entry => entry.monitor === monitor.name);
            if (saved && saved.block >= 0 && saved.block < root.monitors.length && !taken[saved.block]) {
                taken[saved.block] = true;
                result[monitor.name] = saved.block;
            }
        }
        let free = [];
        for (let block = 0; block < root.monitors.length; block++) {
            if (!taken[block])
                free.push(block);
        }
        for (const monitor of root.monitors) {
            if (result[monitor.name] === undefined)
                result[monitor.name] = free.shift();
        }
        return result;
    }

    // Moving a monitor onto a taken block swaps it with the monitor that had it, which keeps
    // the assignment a permutation instead of leaving a hole plus a collision.
    function setBlock(monitorName, block) {
        const current = root.assignment;
        let next = Object.assign({}, current);
        const displaced = Object.keys(current).find(name => name !== monitorName && current[name] === block);
        if (displaced !== undefined)
            next[displaced] = current[monitorName];
        next[monitorName] = block;
        Config.options.workspaceRules.blocks = Object.keys(next).map(name => ({
                    "monitor": name,
                    "block": next[name]
                }));
    }

    function startOfBlock(block) {
        return root.firstWorkspace + block * root.perMonitor;
    }

    // [{ name, description, start, end }], left to right. Drives the Control Center list.
    readonly property var ranges: root.monitors.map(monitor => {
        const start = root.startOfBlock(root.assignment[monitor.name]);
        return {
            name: monitor.name,
            description: monitor.description,
            start: start,
            end: start + root.perMonitor - 1
        };
    })

    // Workspace number -> monitor name. Workspaces outside every block still get an owner, so
    // shrinking or moving a block can't leave an old rule behind pointing at a monitor the
    // user moved away from.
    readonly property var owners: {
        if (!Config.options.workspaceRules.bindToMonitors || root.monitors.length === 0)
            return ({});
        let owner = {};
        for (let workspace = 1; workspace <= root.lastWorkspace; workspace++) {
            owner[workspace] = root.monitors[0].name;
        }
        for (const range of root.ranges) {
            for (let workspace = Math.max(1, range.start); workspace <= Math.min(range.end, root.lastWorkspace); workspace++) {
                owner[workspace] = range.name;
            }
        }
        return owner;
    }

    readonly property string luaRules: {
        if (Object.keys(root.owners).length === 0)
            return "";
        const firstOfEachMonitor = root.ranges.map(range => range.start);
        // Super+<number> resolves through workspace_in_group() in hyprland/lib/init.lua, which
        // buckets by the `workspaceGroupSize` Lua global. The group spans ALL monitors of this
        // machine (perMonitor * count), so the number keys stay absolute: Super+2 always means
        // workspace 2 on its own monitor, from whichever screen you press it — per-monitor
        // grouping would silently remap Super+2 to "2nd workspace of the current screen".
        // eval shares the config's Lua state, so assigning the global takes effect at once; it
        // rides along with the rules so every re-apply path realigns it too.
        let statements = [`workspaceGroupSize = ${root.groupSpan}`, `workspaceFirst = ${root.firstWorkspace}`];
        for (let workspace = 1; workspace <= root.lastWorkspace; workspace++) {
            // default=true makes the monitor land on the first workspace of its block when it connects
            statements.push(`hl.workspace_rule({workspace="${workspace}",monitor="${root.owners[workspace]}",default=${firstOfEachMonitor.includes(workspace)}})`);
        }
        return statements.join(" ");
    }

    // A workspace rule only decides where a workspace *opens*, so whatever is already on screen
    // stays put — including everything that existed before the ranges were set up.
    function targetFor(workspaceId) {
        return root.owners[workspaceId] ?? root.monitors[0]?.name;
    }
    function inSpan(workspaceId) {
        return workspaceId >= root.firstWorkspace && workspaceId < root.firstWorkspace + root.groupSpan;
    }

    // In range but on the wrong monitor: the workspace itself moves.
    readonly property var misplaced: Object.keys(root.owners).length === 0 ? [] : (HyprlandData.workspaces ?? []).filter(workspace => root.inSpan(workspace.id) && workspace.monitor !== root.targetFor(workspace.id))

    // Outside the reachable span entirely (leftovers of an environment with more monitors, or
    // from before the cap existed): no shortcut or scroll can ever land there again, so moving
    // the workspace isn't enough — its windows get pulled into the range of the monitor
    // they're sitting on.
    readonly property var strandedWorkspaces: Object.keys(root.owners).length === 0 ? [] : (HyprlandData.workspaces ?? []).filter(workspace => workspace.id >= 1 && workspace.id < 100 && !root.inSpan(workspace.id) && workspace.windows > 0)

    readonly property int pendingCount: root.misplaced.length + root.strandedWorkspaces.length

    // Re-assert the rules, drag misplaced workspaces onto the monitor they belong to and pull
    // stranded windows back into range. `hyprctl dispatch` only takes one expression, so the
    // moves go through eval instead.
    function applyNow() {
        root.apply(true);
        if (root.pendingCount === 0)
            return;
        let statements = root.misplaced.map(workspace => `hl.dispatch(hl.dsp.workspace.move({workspace=${workspace.id},monitor="${root.targetFor(workspace.id)}"}))`);
        for (const workspace of root.strandedWorkspaces) {
            const parking = root.ranges.find(range => range.name === workspace.monitor)?.start ?? root.firstWorkspace;
            statements.push(`local wins = hl.get_workspace_windows(${workspace.id}) for _, w in ipairs(wins) do hl.dispatch(hl.dsp.window.move({ window = w, workspace = ${parking}, follow = false })) end`);
        }
        // A monitor left sitting on an out-of-span workspace keeps drawing numbers like 21-24
        // in the bar; bring each one home to the start of its range.
        for (const monitor of (HyprlandData.monitors ?? [])) {
            if (!root.inSpan(monitor.activeWorkspace?.id ?? 0)) {
                const home = root.ranges.find(range => range.name === monitor.name)?.start ?? root.firstWorkspace;
                statements.push(`hl.dispatch(hl.dsp.focus({ workspace = ${home} }))`);
            }
        }
        moveProc.command = ["hyprctl", "eval", statements.join(" ")];
        moveProc.running = true;
    }

    property string appliedRules: ""

    function apply(force) {
        if (root.luaRules.length === 0)
            return;
        if (!force && root.luaRules === root.appliedRules)
            return;
        root.appliedRules = root.luaRules;
        applyProc.command = ["hyprctl", "eval", root.luaRules];
        applyProc.running = true;
    }

    onLuaRulesChanged: {
        if (root.luaRules.length === 0) {
            if (root.appliedRules.length > 0) { // Turned off: a reload is the only way to drop eval'd rules
                root.appliedRules = "";
                reloadProc.running = true;
            }
            return;
        }
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 400 // The spin boxes fire on every step
        onTriggered: root.apply(false)
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // A reload (Settings rewrites monitors.lua, or the user runs hyprctl reload)
            // wipes every rule added via eval, so put them back.
            if (event.name === "configreloaded")
                root.apply(true);
        }
    }

    Process {
        id: applyProc
    }

    Process {
        id: moveProc
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}
