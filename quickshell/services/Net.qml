pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.common

Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var network: root.wifiDevice?.networks.values.find(n => n.connected) ?? null

    readonly property var networks: {
        const list = root.wifiDevice ? [...root.wifiDevice.networks.values] : [];
        return list.filter(n => !n.connected && n.name).sort((a, b) => (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }

    readonly property bool available: root.wifiDevice !== null
    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool connected: root.network !== null || root.wiredDevice !== null
    readonly property bool scanning: root.wifiDevice?.scannerEnabled ?? false

    readonly property string status: {
        if (!root.available)
            return root.wiredDevice ? "Wired" : "Unavailable";
        if (!root.enabled)
            return "Off";
        if (root.network)
            return root.network.name;
        return root.wiredDevice ? "Wired" : "Not connected";
    }

    readonly property string icon: root.enabled || root.wiredDevice ? Icons.wifi : Icons.wifiOff

    // The network a password is being asked for, if any.
    property var pending: null
    property string error: ""

    function toggle(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function setScanning(on: bool): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = on;
    }

    function isSecure(network): bool {
        return network && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function securityName(network): string {
        if (!network)
            return "";
        switch (network.security) {
        case WifiSecurityType.Open:
            return "Open";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3";
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.WpaEap:
            return "WPA";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        default:
            return "Secured";
        }
    }

    function detail(network): string {
        if (!network)
            return "";
        const parts = [];
        if (network.connected)
            parts.push("Connected");
        else if (network.known)
            parts.push("Saved");
        parts.push(root.securityName(network));
        parts.push(`${Math.round(network.signalStrength * 100)}% signal`);
        return parts.join("  ·  ");
    }

    function signalIcon(network): string {
        const s = network?.signalStrength ?? 0;
        if (s > 0.75)
            return Icons.wifiStrength4;
        if (s > 0.5)
            return Icons.wifiStrength3;
        if (s > 0.25)
            return Icons.wifiStrength2;
        return Icons.wifiStrength1;
    }

    // Known or open networks connect straight away; anything else asks for a
    // password first, handed to NetworkManager by the Networking module.
    function activate(network): void {
        root.error = "";
        if (network.known || !root.isSecure(network)) {
            network.connect();
            root.pending = null;
        } else {
            root.pending = network;
        }
    }

    function connectWithPassword(password: string): void {
        if (!root.pending)
            return;
        root.error = "";
        root.pending.connectWithPsk(password);
    }

    function disconnect(): void {
        root.network?.disconnect();
    }

    // A hidden network never shows up in a scan, so the Networking module
    // has nothing to connect to; NetworkManager is asked directly.
    property bool joining: false
    property string hiddenError: ""
    signal hiddenJoined

    function joinHidden(ssid: string, password: string): void {
        root.hiddenError = "";
        root.joining = true;
        const args = ["nmcli", "--wait", "30", "device", "wifi", "connect", ssid];
        if (password !== "")
            args.push("password", password);
        args.push("hidden", "yes");
        nmcli.command = args;
        nmcli.running = true;
    }

    Process {
        id: nmcli
        stderr: StdioCollector {
            id: nmcliErrors
        }
        onExited: code => {
            root.joining = false;
            if (code === 0)
                root.hiddenJoined();
            else
                root.hiddenError = nmcliErrors.text.trim().replace(/^Error:\s*/, "") || "Couldn't join that network";
        }
    }

    Connections {
        target: root.pending
        function onConnectedChanged(): void {
            if (root.pending?.connected) {
                root.pending = null;
                root.error = "";
            }
        }
        function onConnectionFailed(reason): void {
            root.error = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : ConnectionFailReason.toString(reason);
        }
    }
}
