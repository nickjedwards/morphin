pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Power and session actions, plus game mode.
Singleton {
    id: root

    // Game mode strips Hyprland's eye candy and flattens the island into a
    // bar; turning it off reloads the config so everything comes back.
    property bool gameMode: false

    readonly property string gameModeLua: "hl.config({ animations = { enabled = false }, decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0 } })"

    signal lockRequested
    signal lockPreviewRequested

    function previewLock(): void {
        root.lockPreviewRequested();
    }

    function toggleGameMode(): void {
        root.gameMode = !root.gameMode;
        Quickshell.execDetached(root.gameMode ? ["hyprctl", "eval", root.gameModeLua] : ["hyprctl", "reload"]);
    }

    function lock(): void {
        root.lockRequested();
    }
    function suspend(): void {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    function logout(): void {
        Quickshell.execDetached(["sh", "-c", Config.system.logoutCommand]);
    }
    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function powerOff(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    readonly property var actions: [
        { id: "lock", label: "Lock", icon: Icons.lock },
        { id: "suspend", label: "Suspend", icon: Icons.sleep },
        { id: "logout", label: "Log Out", icon: Icons.logout },
        { id: "reboot", label: "Reboot", icon: Icons.reboot },
        { id: "poweroff", label: "Power Off", icon: Icons.power }
    ]

    function run(id: string): void {
        switch (id) {
        case "lock":
            root.lock();
            break;
        case "suspend":
            root.lock();
            suspendTimer.start();
            break;
        case "logout":
            root.logout();
            break;
        case "reboot":
            root.reboot();
            break;
        case "poweroff":
            root.powerOff();
            break;
        }
    }

    // Lock first so the machine wakes up to the lock screen.
    Timer {
        id: suspendTimer
        interval: 600
        onTriggered: root.suspend()
    }
}
