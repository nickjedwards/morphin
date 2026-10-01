pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.common

// Power profiles through power-profiles-daemon: Power Saver, Balanced,
// Performance. Performance is missing on hardware that has no such profile.
//
// Also switches to Power Saver on its own — when unplugged, or when the
// battery runs low — and back when plugged in. A choice made by hand while
// that's in effect wins, until the next time the charger goes in or out.
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property var holds: PowerProfiles.holds
    // Set when the daemon has throttled Performance (heat, lap detection).
    readonly property string degraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None ? PerformanceDegradationReason.toString(PowerProfiles.degradationReason) : ""

    readonly property var modes: [
        { profile: PowerProfile.PowerSaver, label: "Power Saver", short: "Saver", icon: Icons.leaf, description: "Cooler and quieter, stretches the battery" },
        { profile: PowerProfile.Balanced, label: "Balanced", short: "Balanced", icon: Icons.balance, description: "Everyday mix of speed and battery life" },
        { profile: PowerProfile.Performance, label: "Performance", short: "Performance", icon: Icons.speedometer, description: "Full speed; runs warmer and louder" }
    ].filter(m => m.profile !== PowerProfile.Performance || root.hasPerformance)

    readonly property int index: Math.max(0, modes.findIndex(m => m.profile === root.profile))
    readonly property var current: modes[index] ?? modes[0]

    function modeFor(profile: int): var {
        return root.modes.find(m => m.profile === profile) ?? root.modes[0];
    }

    function set(profile: int): void {
        PowerProfiles.profile = profile;
    }

    function cycle(): void {
        root.set(root.modes[(root.index + 1) % root.modes.length].profile);
    }

    function setByName(name: string): void {
        const n = name.toLowerCase().replace(/[^a-z]/g, "");
        const match = root.modes.find(m => m.label.toLowerCase().replace(/[^a-z]/g, "").includes(n));
        if (match)
            root.set(match.profile);
    }

    // ── Automatic switching ──────────────────────────────────────────
    // `autoActive`: we switched to Power Saver ourselves and will put back
    // `restoreTo` when the charger goes in — unless the user has picked a
    // mode by hand since (the profile no longer being what we set).
    property bool autoActive: false
    property int restoreTo: PowerProfile.Balanced
    property bool lowFired: false
    readonly property string autoReason: !autoActive ? "" : lowFired ? "low battery" : "on battery"

    function autoSaver(): void {
        if (root.profile === PowerProfile.PowerSaver)
            return;
        if (!root.autoActive)
            root.restoreTo = root.profile;
        root.autoActive = true;
        root.set(PowerProfile.PowerSaver);
    }

    onProfileChanged: {
        if (root.autoActive && root.profile !== PowerProfile.PowerSaver)
            root.autoActive = false;
    }

    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            root.chargerChanged(UPower.onBattery);
        }
    }

    function chargerChanged(onBattery: bool): void {
        if (!Battery.available)
            return;
        if (onBattery) {
            if (Config.power.saverOnBattery)
                root.autoSaver();
            root.checkLow();
        } else {
            if (root.autoActive && root.profile === PowerProfile.PowerSaver)
                root.set(root.restoreTo);
            root.autoActive = false;
            root.lowFired = false;
        }
    }

    // Once per discharge: dropping under the threshold switches to Power
    // Saver; picking another mode afterwards sticks.
    function checkLow(): void {
        if (!Battery.available || !UPower.onBattery || root.lowFired || !Config.power.saverOnLowBattery)
            return;
        if (Battery.level * 100 <= Config.power.lowBatteryThreshold) {
            root.lowFired = true;
            root.autoSaver();
        }
    }

    Connections {
        target: Battery
        function onLevelChanged(): void {
            root.checkLow();
        }
    }
}
