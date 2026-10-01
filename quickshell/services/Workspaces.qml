pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspaces per monitor, straight from the Hyprland module. Special
// workspaces (scratchpads, negative ids) are left out.
Singleton {
    id: root

    // Emitted when a monitor's workspace changes, with that monitor's name.
    // Driven by Hyprland's events rather than property changes, so the
    // initial load at startup doesn't count as a switch.
    signal switched(string monitor)

    function forMonitor(name: string): var {
        return Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === name).sort((a, b) => a.id - b.id);
    }

    function isActive(w): bool {
        return w !== null && w.monitor?.activeWorkspace === w;
    }

    function isOccupied(w): bool {
        return (w?.toplevels?.values.length ?? 0) > 0;
    }

    // Step to the next or previous workspace on that monitor.
    function step(name: string, delta: int): void {
        const list = root.forMonitor(name);
        if (list.length < 2)
            return;
        const at = list.findIndex(w => root.isActive(w));
        list[Math.max(0, Math.min(list.length - 1, at + delta))].activate();
    }

    // Workspace id each monitor is on, and the one it was on before the last
    // switch — so the indicator can animate from where you came from even
    // though it's only built once the switch has happened.
    property var current: ({})
    property var previous: ({})

    function note(monitor: string, id: int): void {
        if (root.current[monitor] === id)
            return;
        const prev = Object.assign({}, root.previous);
        prev[monitor] = root.current[monitor] ?? id;
        root.previous = prev;
        const cur = Object.assign({}, root.current);
        cur[monitor] = id;
        root.current = cur;
    }

    // Seed from Hyprland once its monitor list has loaded.
    Timer {
        running: true
        interval: 1500
        onTriggered: {
            const cur = {};
            for (const m of Hyprland.monitors.values)
                if (m.activeWorkspace && m.activeWorkspace.id > 0)
                    cur[m.name] = m.activeWorkspace.id;
            root.current = cur;
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "workspacev2") {
                // Data is "id,name"; the switch happens on the focused monitor.
                const id = parseInt(event.data);
                const monitor = Hyprland.focusedMonitor?.name ?? "";
                if (id > 0) {
                    root.note(monitor, id);
                    root.switched(monitor);
                }
            } else if (event.name === "focusedmonv2") {
                // Data is "monitor,workspace id": moving focus onto another
                // monitor shows where you landed.
                const [name, id] = event.data.split(",");
                if (parseInt(id) > 0)
                    root.switched(name);
            }
        }
    }
}
