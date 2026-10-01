pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Night light through hyprsunset. It runs while night light is on; warmth
// changes go to the running process over hyprsunset's IPC, not a restart.
Singleton {
    id: root

    // Remembered across restarts.
    property bool enabled: AppState.nightLight ?? false
    onEnabledChanged: AppState.nightLight = enabled
    property bool available: false
    readonly property int temperature: Config.system.nightLightTemp
    readonly property int minTemp: 2500
    readonly property int maxTemp: 6000

    // 0..1 where 1 is warmest, for the slider.
    readonly property real warmth: (maxTemp - temperature) / (maxTemp - minTemp)

    function toggle(): void {
        root.enabled = !root.enabled;
    }

    function setWarmth(v: real): void {
        const t = Math.round((root.maxTemp - Math.max(0, Math.min(1, v)) * (root.maxTemp - root.minTemp)) / 50) * 50;
        Config.system.nightLightTemp = t;
        apply.restart();
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v hyprsunset"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: sunset
        running: root.enabled && root.available
        command: ["hyprsunset", "-t", String(root.temperature)]
    }

    // Coalesce slider drags into one IPC call.
    Timer {
        id: apply
        interval: 120
        onTriggered: {
            if (sunset.running)
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temperature)]);
        }
    }
}
