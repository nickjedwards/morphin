pragma Singleton

import Quickshell

// The shell's own notifications ("Wallpaper changed"). They go out over the
// notification bus like anyone else's, marked transient: they pop up in the
// island and are gone, without piling up in the list.
Singleton {
    function send(title: string, body: string, image: string): void {
        if (!Config.notifications.announceChanges)
            return;
        const args = ["notify-send", "--app-name", Meta.name, "--transient"];
        if (image !== "")
            args.push("--icon", image);
        args.push(title, body);
        Quickshell.execDetached(args);
    }
}
