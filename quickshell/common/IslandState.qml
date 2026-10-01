pragma Singleton

import Quickshell
import Quickshell.Hyprland

// Which panel the island has open, and on which screen. Only one panel is
// ever open at a time; opening another closes the first.
//
// Panels: media, calendar (the month view), controlcenter, launcher, power,
// polkit. The control center also has a page: wifi, bluetooth, sound,
// display, or "" for its main grid.
Singleton {
    id: root

    property string open: ""
    property string screen: ""
    property string page: ""

    // Hyprland.focusedMonitor is only set by focus events, and is null again
    // after the monitor list is refreshed; the refreshed data marks the
    // focused monitor itself, so fall back to that.
    readonly property string focusedScreen: Hyprland.focusedMonitor?.name || (Hyprland.monitors.values.find(m => m.lastIpcObject?.focused)?.name ?? "")

    function show(panel: string, screenName: string): void {
        root.screen = screenName || root.focusedScreen;
        root.page = "";
        root.open = panel;
    }

    function toggle(panel: string, screenName: string): void {
        const name = screenName || root.focusedScreen;
        if (root.open === panel && root.screen === name)
            root.close();
        else
            root.show(panel, name);
    }

    function toggleOnFocused(panel: string): void {
        root.toggle(panel, root.focusedScreen);
    }

    function openPage(page: string, screenName: string): void {
        if (root.open !== "controlcenter")
            root.show("controlcenter", screenName);
        root.page = page;
    }

    function close(): void {
        root.open = "";
        root.page = "";
    }

    function isOpen(panel: string, screenName: string): bool {
        return root.open === panel && root.screen === screenName;
    }
}
