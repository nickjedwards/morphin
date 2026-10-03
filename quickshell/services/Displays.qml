pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common

// Monitors as Hyprland reports them, plus brightness for the ones with a
// sysfs backlight (built-in panels), watched and written by morpher.
Singleton {
    id: root

    // Hyprland's own view of each monitor (what `hyprctl monitors -j` prints),
    // kept current by the Hyprland module.
    readonly property var monitors: Hyprland.monitors.values.map(m => m.lastIpcObject).filter(o => o && o.name)
    readonly property var focused: monitors.find(m => m.focused) ?? monitors[0] ?? null

    // connector name → { id, max, value (0..1) }, for monitors with a backlight
    property var brightness: ({})

    readonly property real focusedBrightness: root.brightnessOf(root.focused?.name ?? "")
    readonly property bool focusedHasBrightness: root.hasBrightness(root.focused?.name ?? "")

    signal brightnessTouched(string monitor)

    function refresh(): void {
        Hyprland.refreshMonitors();
    }
    // Asks morpher which backlight device drives which monitor. Only
    // needed at start and when monitors come and go; it follows the levels
    // from then on.
    function refreshBrightness(): void {
        Morpher.send({ cmd: "backlights" });
    }

    function hasBrightness(name: string): bool {
        return root.brightness[name] !== undefined;
    }
    // Brightness is handled on a perceived scale, like `brightnessctl -e4`:
    // the backlight's actual level is the perceived one to the power of the
    // curve, so equal steps look equal — small at the dark end, large at the
    // bright end. `value` is always the actual (linear) level; sliders, steps
    // and the OSD work in perceived terms.
    readonly property real curve: Math.max(1, Config.system.brightnessCurve)

    function brightnessOf(name: string): real {
        const entry = root.brightness[name];
        return entry ? Math.pow(entry.value, 1 / root.curve) : 0;
    }

    function setBrightness(name: string, v: real): void {
        const entry = root.brightness[name];
        if (!entry)
            return;
        // Never fully off: the lowest raw step.
        const value = Math.max(1 / entry.max, Math.min(1, Math.pow(Math.max(0, v), root.curve)));
        const next = Object.assign({}, root.brightness);
        next[name] = Object.assign({}, entry, { value });
        root.brightness = next;
        root.pendingWrites[name] = true;
        writeTimer.restart();
        root.brightnessTouched(name);
    }

    function nudgeBrightness(delta: real): void {
        const name = root.focused?.name ?? "";
        if (root.hasBrightness(name))
            root.setBrightness(name, root.brightnessOf(name) + delta);
    }

    property var pendingWrites: ({})
    Timer {
        id: writeTimer
        interval: 60
        onTriggered: {
            for (const name of Object.keys(root.pendingWrites)) {
                const e = root.brightness[name];
                // Raw values: at the dark end a whole percent is far too
                // coarse a step.
                Morpher.send({ cmd: "brightness", subsystem: "backlight", id: e.id, value: Math.max(1, Math.round(e.value * e.max)) });
            }
            root.pendingWrites = {};
        }
    }

    // ── Mode and scale ───────────────────────────────────────────────
    function modeString(m): string {
        return `${m.width}x${m.height}@${Number(m.refreshRate).toFixed(2)}`;
    }

    function apply(m, mode: string, scale: real): void {
        const lua = `hl.monitor({ output = "${m.name}", mode = "${mode}", position = "${m.x}x${m.y}", scale = ${scale} })`;
        Quickshell.execDetached(["hyprctl", "eval", lua]);
        refreshTimer.restart();
    }

    function setScale(m, scale: real): void {
        root.apply(m, root.modeString(m), scale);
    }

    function setMode(m, mode: string): void {
        root.apply(m, mode.replace(/Hz$/, ""), m.scale);
    }

    function describe(m): string {
        return `${m.width}×${m.height}  ·  ${Math.round(m.refreshRate)} Hz  ·  ${Number(m.scale).toFixed(2).replace(/\.?0+$/, "")}×`;
    }

    // Modes grouped to one entry per resolution+rate, highest first.
    function modesOf(m): var {
        const seen = {};
        const out = [];
        for (const mode of m.availableModes ?? []) {
            const match = mode.match(/(\d+)x(\d+)@([\d.]+)/);
            if (!match)
                continue;
            const key = `${match[1]}x${match[2]}@${Math.round(parseFloat(match[3]))}`;
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({ key, mode, label: `${match[1]}×${match[2]} @ ${Math.round(parseFloat(match[3]))} Hz` });
        }
        return out;
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name)) {
                refreshTimer.restart();
                discoverTimer.restart();
            } else if (event.name === "focusedmon") {
                refreshTimer.restart();
            }
        }
    }

    Timer {
        id: discoverTimer
        interval: 1000
        onTriggered: root.refreshBrightness()
    }

    // Brightness keys bound straight to brightnessctl don't tell us anything,
    // so the level has to be watched: morpher sleeps until the kernel
    // says a backlight changed and passes it on.
    function observed(name: string, raw: int): void {
        const entry = root.brightness[name];
        if (!entry || isNaN(raw) || raw === Math.round(entry.value * entry.max) || writeTimer.running)
            return;
        const next = Object.assign({}, root.brightness);
        next[name] = Object.assign({}, entry, { value: raw / entry.max });
        root.brightness = next;
        root.brightnessTouched(name);
    }

    Connections {
        target: Morpher
        function onAvailableChanged(): void {
            if (Morpher.available)
                root.refreshBrightness();
        }
        function onMessage(msg): void {
            if (msg.type === "backlights") {
                const next = {};
                for (const b of msg.list)
                    next[b.connector] = { id: b.id, max: b.max, value: b.level / b.max };
                root.brightness = next;
            } else if (msg.type === "backlight") {
                const name = Object.keys(root.brightness).find(c => root.brightness[c].id === msg.id);
                if (name)
                    root.observed(name, msg.value);
            }
        }
    }

    // The Hyprland module loads the monitor list itself; refreshing it before
    // that has happened leaves every monitor (and the focused one) empty.
    Component.onCompleted: refreshBrightness()
}
