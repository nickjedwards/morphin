pragma Singleton

import QtQuick
import Quickshell
import qs.common

// The keyboard backlight: the first *kbd_backlight LED, found once at
// startup. Written through logind (the sysfs file is root's), read by
// re-reading the file, since firmware keys (Fn+Space) change it without
// telling anyone. morpher does all three and says when it changes.
//
// Some keyboards have a handful of fixed levels (max 2 or 3), others a range
// (max 100 on a Framework): steps are one level on the former, 10% on the
// latter.
Singleton {
    id: root

    readonly property string device: Morpher.info.kbd?.device ?? ""
    readonly property int max: Morpher.info.kbd?.max ?? 0
    property int raw: 0

    readonly property bool available: device !== "" && max > 0
    readonly property real value: available ? raw / max : 0
    readonly property bool stepped: max <= 5
    readonly property real step: stepped ? 1 / max : 0.1
    readonly property string label: !available ? "" : raw === 0 ? "Off" : stepped ? `Level ${raw} of ${max}` : `${Math.round(value * 100)}%`

    // Changed, by us or by the keyboard's own keys: for the OSD.
    signal touched

    function set(v: real): void {
        if (!root.available)
            return;
        const next = Math.max(0, Math.min(root.max, Math.round(v * root.max)));
        if (next === root.raw)
            return;
        root.raw = next;
        writeTimer.restart();
        root.touched();
    }

    function nudge(direction: int): void {
        root.set(root.value + direction * root.step);
    }

    // Off, or back to where it was.
    property int lastOn: 0
    function toggle(): void {
        if (root.raw > 0) {
            root.lastOn = root.raw;
            root.set(0);
        } else {
            root.set((root.lastOn || Math.ceil(root.max / 2)) / root.max);
        }
    }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: Morpher.send({ cmd: "brightness", subsystem: "leds", id: root.device, value: root.raw })
    }

    // The level as the file has it. The first reading is where it already
    // was, not a change.
    property bool seen: false
    function observed(value: int): void {
        if (isNaN(value) || writeTimer.running)
            return;
        const first = !root.seen;
        root.seen = true;
        if (value === root.raw)
            return;
        root.raw = value;
        if (!first)
            root.touched();
    }

    // Ask where it is now; after that morpher only speaks up on a change.
    readonly property bool listening: root.available && Morpher.available
    onListeningChanged: {
        if (root.listening)
            Morpher.send({ cmd: "kbd" });
    }

    Connections {
        target: Morpher
        function onMessage(msg): void {
            if (msg.type === "kbd")
                root.observed(msg.value);
        }
    }
}
