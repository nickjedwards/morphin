pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

// Monitors as Hyprland reports them, plus per-monitor brightness: the sysfs
// backlight for built-in panels, DDC/CI through ddcutil for external ones.
Singleton {
    id: root

    // Hyprland's own view of each monitor (what `hyprctl monitors -j` prints),
    // kept current by the Hyprland module.
    readonly property var monitors: Hyprland.monitors.values.map(m => m.lastIpcObject).filter(o => o && o.name)
    readonly property var focused: monitors.find(m => m.focused) ?? monitors[0] ?? null

    // connector name → { kind: "backlight" | "ddc", id, value (0..1) }
    property var brightness: ({})

    readonly property real focusedBrightness: root.brightnessOf(root.focused?.name ?? "")
    readonly property bool focusedHasBrightness: root.hasBrightness(root.focused?.name ?? "")

    signal brightnessTouched(string monitor)

    function refresh(): void {
        Hyprland.refreshMonitors();
    }
    // Finds which backlight/DDC device drives which monitor. Only needed at
    // start and when monitors come and go; levels are read by FileView.
    function refreshBrightness(): void {
        backlightProc.running = true;
    }

    function hasBrightness(name: string): bool {
        return root.brightness[name] !== undefined;
    }
    // Brightness is handled on a perceived scale, like `brightnessctl -e4`:
    // the backlight's actual level is the perceived one to the power of the
    // curve, so equal steps look equal — small at the dark end, large at the
    // bright end. `value` is always the actual (linear) level; sliders, steps
    // and the OSD work in perceived terms. External (DDC) monitors already
    // scale perceptually, so their curve is 1.
    function curveOf(entry): real {
        return entry?.kind === "backlight" ? Math.max(1, Config.system.brightnessCurve) : 1;
    }

    function brightnessOf(name: string): real {
        const entry = root.brightness[name];
        return entry ? Math.pow(entry.value, 1 / root.curveOf(entry)) : 0;
    }

    function setBrightness(name: string, v: real): void {
        const entry = root.brightness[name];
        if (!entry)
            return;
        // Never fully off: the lowest raw step for a backlight, 1% for DDC.
        const floor = entry.kind === "backlight" && entry.max > 0 ? 1 / entry.max : 0.01;
        const value = Math.max(floor, Math.min(1, Math.pow(Math.max(0, v), root.curveOf(entry))));
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
                // Raw values for backlights: at the dark end a whole percent
                // is far too coarse a step.
                if (e.kind === "backlight")
                    Quickshell.execDetached(["brightnessctl", "-q", "-d", e.id, "set", String(Math.max(1, Math.round(e.value * e.max)))]);
                else
                    Quickshell.execDetached(["ddcutil", "--noverify", "--display", e.id, "setvcp", "10", String(Math.round(e.value * 100))]);
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

    // Each line: "<device> <connector> <percent>" for backlights, then
    // "ddc <display> <connector> <percent>" for DDC/CI monitors.
    Process {
        id: backlightProc
        command: ["sh", "-c", `
for b in /sys/class/backlight/*; do
  [ -e "$b" ] || continue
  conn=$(basename "$(readlink -f "$b/device")" | sed 's/^card[0-9]*-//')
  cur=$(cat "$b/brightness"); max=$(cat "$b/max_brightness")
  echo "backlight $(basename "$b") $conn $cur $max"
done
if command -v ddcutil >/dev/null; then
  ddcutil detect --terse 2>/dev/null | awk '/^Display/ {d=$2} /DRM connector:/ {sub(/^card[0-9]*-/, "", $3); print d, $3}' |
  while read d conn; do
    v=$(ddcutil --display "$d" getvcp 10 --terse 2>/dev/null | awk '{print int($4 * 100 / $5)}')
    [ -n "$v" ] && echo "ddc $d $conn $v"
  done
fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.trim().split("\n")) {
                    const [kind, id, conn, pct, max] = line.trim().split(/\s+/);
                    if (!conn)
                        continue;
                    next[conn] = { kind, id, max: parseInt(max) || 0, value: kind === "backlight" ? parseInt(pct) / (parseInt(max) || 1) : parseInt(pct) / 100 };
                }
                root.brightness = next;
            }
        }
    }

    // Brightness keys bound straight to brightnessctl don't tell us anything,
    // and sysfs doesn't send change notifications, so the backlight files are
    // re-read four times a second — a plain file read, no process, so cheap
    // enough to poll quickly and keep the OSD prompt.
    readonly property var backlights: Object.keys(root.brightness).filter(c => root.brightness[c].kind === "backlight" && root.brightness[c].max > 0)

    Instantiator {
        id: backlightReaders
        model: root.backlights
        delegate: FileView {
            required property string modelData
            readonly property var entry: root.brightness[modelData]
            path: `/sys/class/backlight/${entry.id}/brightness`
            printErrors: false
            onLoaded: {
                const value = parseInt(text()) / entry.max;
                if (!isNaN(value) && Math.round(value * entry.max) !== Math.round(entry.value * entry.max) && !writeTimer.running) {
                    const next = Object.assign({}, root.brightness);
                    next[modelData] = Object.assign({}, entry, { value });
                    root.brightness = next;
                    root.brightnessTouched(modelData);
                }
            }
        }
    }

    Timer {
        interval: 250
        running: root.backlights.length > 0
        repeat: true
        onTriggered: {
            for (let i = 0; i < backlightReaders.count; i++)
                backlightReaders.objectAt(i).reload();
        }
    }

    // The Hyprland module loads the monitor list itself; refreshing it before
    // that has happened leaves every monitor (and the focused one) empty.
    Component.onCompleted: refreshBrightness()
}
