pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The wallpaper: which file it is, which files it could be, and its colours.
//
// Wallpapers come from one folder — by default the folder the current
// wallpaper lives in. A sub-folder named after the current theme takes over
// when it has images in it, so each theme can bring its own set. Each theme
// also remembers the wallpaper last used with it.
Singleton {
    id: root

    function expand(p: string): string {
        return Paths.expand(p);
    }
    function dirOf(p: string): string {
        return p.substring(0, p.lastIndexOf("/"));
    }
    function nameOf(p: string): string {
        return p.substring(p.lastIndexOf("/") + 1);
    }

    // The configured path, which may be a symlink ($XDG_CONFIG_HOME/wallpaper);
    // `resolved` is the real file behind it.
    readonly property string path: expand(Config.appearance.wallpaper)
    readonly property string linkPath: Paths.configHome + "/wallpaper"
    property string linkTarget: ""
    readonly property string resolved: path === linkPath && linkTarget ? linkTarget : path
    readonly property url source: resolved ? "file://" + resolved : ""
    readonly property string name: nameOf(resolved)
    // The wallpaper's sampled colours (material-you is built from these).
    // Held until the new wallpaper's are ready: while it's being sampled the
    // quantizer has none, and passing that on would flash material-you to its
    // fallback palette between the old wallpaper's colours and the new.
    property var colors: []
    Connections {
        target: quantizer
        function onColorsChanged(): void {
            if (quantizer.colors.length > 0)
                root.colors = quantizer.colors;
        }
    }

    readonly property string baseDir: Config.appearance.wallpaperDir ? expand(Config.appearance.wallpaperDir) : dirOf(resolved)
    readonly property string themeDir: baseDir + "/" + Config.appearance.theme
    readonly property bool usingThemeDir: themeFolder.count > 0
    readonly property string dir: usingThemeDir ? themeDir : baseDir

    // Every image in `dir`, as absolute paths, sorted by name.
    readonly property var files: {
        const model = root.usingThemeDir ? themeFolder : baseFolder;
        const out = [];
        for (let i = 0; i < model.count; i++)
            out.push(model.get(i, "filePath"));
        // Before its folder is set a FolderListModel lists the working
        // directory; keep only files that are really in `dir`.
        return out.filter(f => f.startsWith(root.dir + "/"));
    }

    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif", "*.JPG", "*.PNG"]

    FolderListModel {
        id: baseFolder
        folder: root.baseDir ? "file://" + root.baseDir : Paths.nowhere
        nameFilters: root.imageFilters
        showDirs: false
        sortField: FolderListModel.Name
    }
    FolderListModel {
        id: themeFolder
        folder: root.baseDir ? "file://" + root.themeDir : Paths.nowhere
        nameFilters: root.imageFilters
        showDirs: false
        sortField: FolderListModel.Name
    }

    ColorQuantizer {
        id: quantizer
        source: root.source
        depth: 3
        rescaleSize: 96
    }

    Process {
        id: resolver
        command: ["readlink", "-f", root.linkPath]
        stdout: StdioCollector {
            onStreamFinished: root.linkTarget = text.trim()
        }
    }
    Component.onCompleted: resolver.running = true

    // hyprpaper draws the wallpaper when it's running; the shell only draws
    // the crossfade on top. Without it, the shell draws the wallpaper itself.
    property bool hyprpaper: false

    Process {
        id: hyprpaperProbe
        command: ["pgrep", "-x", "hyprpaper"]
        running: true
        onExited: code => root.hyprpaper = code === 0
    }

    // Emitted when the wallpaper changes, with both files, for the crossfade.
    signal changed(string from, string to)

    // Set the wallpaper. $XDG_CONFIG_HOME/wallpaper is repointed too when it's a
    // symlink (or missing), so hyprpaper and hyprlock stay in step.
    function set(file: string): void {
        if (!file || file === root.resolved)
            return;
        root.apply(file);
        Announce.send("Wallpaper changed", root.nameOf(file), file);
    }

    // The change itself, without announcing it: a theme switching to its own
    // wallpaper is announced as the theme change it is.
    function apply(file: string): void {
        if (!file || file === root.resolved)
            return;
        const from = root.resolved;
        root.changed(from, file);
        // One command per output: an empty monitor name only reaches one.
        if (root.hyprpaper)
            for (const m of Hyprland.monitors.values)
                Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", `${m.name},${file}`]);
        Config.appearance.wallpaper = file;
        const remembered = Object.assign({}, AppState.themeWallpapers);
        remembered[Config.appearance.theme] = file;
        AppState.themeWallpapers = remembered;
        root.linkTarget = file;
        Quickshell.execDetached(["sh", "-c", 'if [ -L "$1" ] || [ ! -e "$1" ]; then ln -sfn "$2" "$1"; fi', "sh", root.linkPath, file]);
    }

    function step(delta: int): void {
        if (root.files.length === 0)
            return;
        const at = root.files.indexOf(root.resolved);
        root.set(root.files[((at < 0 ? 0 : at + delta) % root.files.length + root.files.length) % root.files.length]);
    }

    // Called after the theme changes: bring back the wallpaper this theme
    // was last used with, or the first of its own folder if it has one.
    function themeChanged(id: string): void {
        const remembered = AppState.themeWallpapers[id];
        if (remembered) {
            if (remembered !== root.resolved)
                root.apply(remembered);
            return;
        }
        pendingTheme.restart();
    }

    // The theme folder's listing arrives a moment after the folder changes.
    Timer {
        id: pendingTheme
        interval: 250
        onTriggered: {
            if (root.usingThemeDir && !root.files.includes(root.resolved))
                root.apply(root.files[0]);
        }
    }
}
