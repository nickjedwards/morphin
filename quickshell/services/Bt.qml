pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.common

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.adapter?.enabled ?? false
    readonly property bool scanning: root.adapter?.discovering ?? false
    readonly property var devices: Bluetooth.devices.values
    readonly property var connected: root.devices.filter(d => d.connected)
    readonly property var saved: root.devices.filter(d => d.paired || d.bonded).sort((a, b) => b.connected - a.connected)
    readonly property var nearby: root.devices.filter(d => !d.paired && !d.bonded)

    readonly property string status: {
        if (!root.available)
            return "Unavailable";
        if (!root.enabled)
            return "Off";
        if (root.connected.length > 0)
            return root.connected[0].name;
        return "On";
    }

    function toggle(): void {
        if (root.adapter)
            root.adapter.enabled = !root.adapter.enabled;
    }

    function setScanning(on: bool): void {
        if (root.adapter && root.adapter.enabled)
            root.adapter.discovering = on;
    }

    function deviceIcon(device): string {
        const icon = device?.icon ?? "";
        if (icon.includes("audio") || icon.includes("headset") || icon.includes("headphone"))
            return Icons.headphones;
        if (icon.includes("input-mouse"))
            return Icons.mouse;
        if (icon.includes("input-keyboard"))
            return Icons.keyboard;
        if (icon.includes("phone"))
            return Icons.phone;
        return Icons.bluetooth;
    }

    function deviceState(device): string {
        if (device.pairing)
            return "Pairing…";
        if (device.connected)
            return device.batteryAvailable ? `Connected  ·  ${Math.round(device.battery * 100)}%` : "Connected";
        if (device.paired || device.bonded)
            return "Saved";
        return "Not paired";
    }

    function act(device): void {
        if (device.connected)
            device.disconnect();
        else if (device.paired || device.bonded)
            device.connect();
        else {
            device.trusted = true;
            device.pair();
        }
    }
}
