//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.island
import qs.lock
import qs.settings
import qs.wallpaper
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Background {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Island {}
    }

    LockScreen {}
    SettingsWindow {}

    // Singletons load lazily; the notification server and polkit agent have
    // to exist up front to claim their bus names.
    Component.onCompleted: [Notifs.focus, Polkit.registered, NightLight.available, Weather.enabled]

    // The polkit prompt lives in the island. Closing the island any way at
    // all cancels the request, so nothing is left waiting on a hidden prompt.
    Connections {
        target: Polkit
        function onActiveChanged(): void {
            if (Polkit.active)
                IslandState.show("polkit", IslandState.focusedScreen);
            else if (IslandState.open === "polkit")
                IslandState.close();
        }
    }
    Connections {
        target: IslandState
        function onOpenChanged(): void {
            if (IslandState.open !== "polkit" && Polkit.active)
                Polkit.cancel();
        }
    }

    // <name> ipc call <target> <function> [args] (or qs -p <folder> ipc call …)
    IpcHandler {
        target: "island"

        function toggle(panel: string): void {
            IslandState.toggleOnFocused(panel);
        }
        function page(name: string): void {
            IslandState.openPage(name, IslandState.focusedScreen);
        }
        function close(): void {
            IslandState.close();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            IslandState.toggleOnFocused("launcher");
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            IslandState.toggleOnFocused("power");
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            Session.lock();
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void {
            SettingsState.toggle();
        }
        function open(page: string): void {
            SettingsState.open(page);
        }
    }

    IpcHandler {
        target: "volume"
        function up(): void {
            Audio.nudge(0.05);
        }
        function down(): void {
            Audio.nudge(-0.05);
        }
        function mute(): void {
            Audio.toggleMute();
        }
    }

    IpcHandler {
        target: "brightness"
        function up(): void {
            Displays.nudgeBrightness(0.05);
        }
        function down(): void {
            Displays.nudgeBrightness(-0.05);
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            IslandState.toggleOnFocused("wallpapers");
        }
        function set(path: string): void {
            Wallpaper.set(path);
        }
        function next(): void {
            Wallpaper.step(1);
        }
        function previous(): void {
            Wallpaper.step(-1);
        }
        function get(): string {
            return Wallpaper.resolved;
        }
    }

    IpcHandler {
        target: "theme"
        function toggle(): void {
            IslandState.toggleOnFocused("themes");
        }
        function set(name: string): void {
            Themes.apply(name);
        }
        function get(): string {
            return Config.appearance.theme;
        }
    }

    IpcHandler {
        target: "power-mode"
        function set(name: string): void {
            Power.setByName(name);
        }
        function cycle(): void {
            Power.cycle();
        }
        function get(): string {
            return Power.current.label;
        }
        function page(): void {
            IslandState.openPage("power", IslandState.focusedScreen);
        }
    }

    IpcHandler {
        target: "keyboard"
        function up(): void {
            KeyboardLight.nudge(1);
        }
        function down(): void {
            KeyboardLight.nudge(-1);
        }
        function toggle(): void {
            KeyboardLight.toggle();
        }
        function get(): string {
            return KeyboardLight.label;
        }
    }

    IpcHandler {
        target: "gamemode"
        function toggle(): void {
            Session.toggleGameMode();
        }
    }

    IpcHandler {
        target: "media"
        function playPause(): void {
            Media.togglePlaying();
        }
        function next(): void {
            Media.next();
        }
        function previous(): void {
            Media.previous();
        }
        function cycle(): void {
            Media.cycle(1);
        }
        function cycleBack(): void {
            Media.cycle(-1);
        }
        function players(): string {
            return Media.cycleOrder.map(p => Media.describe(p)).join("\n");
        }
    }
}
