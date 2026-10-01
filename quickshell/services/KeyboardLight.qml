pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The keyboard backlight: the first *kbd_backlight LED, found once at
// startup. Written through brightnessctl (the sysfs file is root's; it goes
// via logind), read by re-reading the file, since firmware keys (Fn+Space)
// change it without telling anyone.
//
// Some keyboards have a handful of fixed levels (max 2 or 3), others a range
// (max 100 on a Framework): steps are one level on the former, 10% on the
// latter.
Singleton {
    id: root

    property string device: ""
    property int max: 0
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

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/leds/*kbd_backlight*; do [ -e "$d/max_brightness" ] && { basename "$d"; cat "$d/max_brightness"; break; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const [device, max] = text.trim().split("\n");
                if (device && parseInt(max) > 0) {
                    root.device = device;
                    root.max = parseInt(max);
                }
            }
        }
    }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "-d", root.device, "set", String(root.raw)])
    }

    FileView {
        id: reader
        path: root.available ? `/sys/class/leds/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            const value = parseInt(text());
            if (isNaN(value) || value === root.raw || writeTimer.running)
                return;
            const first = !reader.seen;
            reader.seen = true;
            root.raw = value;
            if (!first)
                root.touched();
        }
        property bool seen: false
    }

    Timer {
        interval: 250
        running: root.available
        repeat: true
        onTriggered: reader.reload()
    }
}
