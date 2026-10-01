pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.common

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    // The physical battery, for details the combined display device lacks
    // (health, native path).
    readonly property var cell: UPower.devices.values.find(d => d.isLaptopBattery) ?? device
    readonly property bool available: device !== null && device.ready && device.isLaptopBattery
    readonly property bool onBattery: UPower.onBattery
    // Machines without a battery show a full ring.
    readonly property real level: root.available ? root.device.percentage : 1
    readonly property int state: root.available ? root.device.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.state === UPowerDeviceState.Charging
    // Plugged in but holding below full: a charge limit is in effect.
    readonly property bool holding: root.state === UPowerDeviceState.PendingCharge
    readonly property string icon: root.charging ? Icons.batteryCharging : root.level > 0.35 ? Icons.battery : Icons.batteryHalf

    readonly property real energy: root.available ? root.device.energy : 0
    readonly property real capacity: root.available ? root.device.energyCapacity : 0
    readonly property real rate: root.available ? Math.abs(root.device.changeRate) : 0
    readonly property bool healthSupported: root.available && (root.cell?.healthSupported ?? false)
    readonly property real health: root.healthSupported ? root.cell.healthPercentage / 100 : 0

    readonly property string status: {
        if (!root.available)
            return "";
        switch (root.state) {
        case UPowerDeviceState.Charging:
            return root.device.timeToFull > 0 ? `Charging · ${root.duration(root.device.timeToFull)} to full` : "Charging";
        case UPowerDeviceState.Discharging:
            return root.device.timeToEmpty > 0 ? `On battery · ${root.duration(root.device.timeToEmpty)} left` : "On battery";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Plugged in · holding at charge limit";
        }
        return root.onBattery ? "On battery" : "Plugged in";
    }

    function duration(seconds: real): string {
        const m = Math.round(seconds / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? `${h}h ${m % 60}m` : `${m}m`;
    }

    // Charge cycles and charge limit aren't exposed by Quickshell; read them
    // straight off UPower's D-Bus object.
    property int cycles: -1
    property bool thresholdSupported: false
    property bool thresholdEnabled: false
    property int thresholdStart: 0
    property int thresholdEnd: 0

    readonly property string dbusPath: root.available && root.cell?.nativePath ? `/org/freedesktop/UPower/devices/battery_${root.cell.nativePath}` : ""

    function refresh(): void {
        if (root.dbusPath)
            reader.running = true;
    }

    function setThreshold(enabled: bool): void {
        Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.UPower", root.dbusPath, "org.freedesktop.UPower.Device", "EnableChargeThreshold", "b", enabled ? "true" : "false"]);
        refreshTimer.restart();
    }

    Process {
        id: reader
        command: ["busctl", "--system", "get-property", "org.freedesktop.UPower", root.dbusPath, "org.freedesktop.UPower.Device", "ChargeCycles", "ChargeThresholdSupported", "ChargeThresholdEnabled", "ChargeStartThreshold", "ChargeEndThreshold"]
        stdout: StdioCollector {
            onStreamFinished: {
                // One "<type> <value>" line per property, in the order asked.
                const v = text.trim().split("\n").map(l => l.trim().split(/\s+/)[1]);
                if (v.length < 5)
                    return;
                root.cycles = parseInt(v[0]);
                root.thresholdSupported = v[1] === "true";
                root.thresholdEnabled = v[2] === "true";
                root.thresholdStart = parseInt(v[3]);
                root.thresholdEnd = parseInt(v[4]);
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: root.refresh()
    }

    onDbusPathChanged: refresh()
}
