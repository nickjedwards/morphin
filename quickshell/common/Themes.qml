pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// The colour themes. Each is a background, a foreground, an accent and six
// swatches (red, green, yellow, blue, magenta, cyan); Theme derives every
// surface in the shell from those. material-you has no fixed colours — it
// takes them from the wallpaper.
//
// Your own themes go in $XDG_DATA_HOME/<name>/themes/, one JSON file each
// with the same fields: { "id", "bg", "fg", "accent", "colors": [six] }. One
// with the same id as a built-in theme replaces it.
Singleton {
    id: root

    readonly property var list: {
        const user = root.userThemes;
        const ids = new Set(user.map(t => t.id));
        return root.builtin.filter(t => !ids.has(t.id)).concat(user).sort((a, b) => a.id.localeCompare(b.id));
    }

    readonly property var builtin: [
        { id: "ayu", bg: "#0b0e14", fg: "#bfbdb6", accent: "#e6b450", colors: ["#f07178", "#aad94c", "#e6b450", "#59c2ff", "#d2a6ff", "#95e6cb"] },
        { id: "catppuccin", bg: "#1e1e2e", fg: "#cdd6f4", accent: "#cba6f7", colors: ["#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5"] },
        { id: "cyberdream", bg: "#16181a", fg: "#ffffff", accent: "#5ef1ff", colors: ["#ff6e5e", "#5eff6c", "#f1ff5e", "#5ea1ff", "#ff5ef1", "#5ef1ff"] },
        { id: "dracula", bg: "#282a36", fg: "#f8f8f2", accent: "#bd93f9", colors: ["#ff5555", "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd"] },
        { id: "embark", bg: "#1e1c31", fg: "#cbe3e7", accent: "#a1efd3", colors: ["#f48fb1", "#a1efd3", "#ffe6b3", "#91ddff", "#d4bfff", "#87dfeb"] },
        { id: "everforest", bg: "#2d353b", fg: "#d3c6aa", accent: "#a7c080", colors: ["#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092"] },
        { id: "gruvbox", bg: "#282828", fg: "#ebdbb2", accent: "#d79921", colors: ["#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a"] },
        { id: "gruvbox-material", bg: "#1d2021", fg: "#d4be98", accent: "#a9b665", colors: ["#ea6962", "#a9b665", "#d8a657", "#7daea3", "#d3869b", "#89b482"] },
        { id: "horizon", bg: "#1c1e26", fg: "#e0e0e0", accent: "#26bbd9", colors: ["#e95678", "#29d398", "#fab795", "#26bbd9", "#ee64ac", "#59e1e3"] },
        { id: "industrial", bg: "#161616", fg: "#d0ccc4", accent: "#cfc7b0", colors: ["#9a9a9a", "#8a8a8a", "#b0b0b0", "#6e6e6e", "#7c7c7c", "#a4a4a4"] },
        { id: "kanagawa", bg: "#1f1f28", fg: "#dcd7ba", accent: "#7e9cd8", colors: ["#e46876", "#98bb6c", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f"] },
        { id: "material-you", dynamic: true, bg: "#1a1614", fg: "#ede0da", accent: "#f2b8a4", colors: [] },
        { id: "nightfox", bg: "#192330", fg: "#cdcecf", accent: "#719cd6", colors: ["#c94f6d", "#81b29a", "#dbc074", "#719cd6", "#9d79d6", "#63cdcf"] },
        { id: "nord", bg: "#2e3440", fg: "#eceff4", accent: "#88c0d0", colors: ["#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0"] },
        { id: "one-dark", bg: "#282c34", fg: "#abb2bf", accent: "#61afef", colors: ["#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2"] },
        { id: "rose-pine", bg: "#191724", fg: "#e0def4", accent: "#c4a7e7", colors: ["#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba"] },
        { id: "solarized", bg: "#002b36", fg: "#93a1a1", accent: "#268bd2", colors: ["#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198"] },
        { id: "tokyo-night", bg: "#1a1b26", fg: "#c0caf5", accent: "#7aa2f7", colors: ["#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff"] },
        { id: "vesper", bg: "#101010", fg: "#e8e8e8", accent: "#ffc799", colors: ["#ff8080", "#99ffe4", "#ffc799", "#a0a0a0", "#ffcfa8", "#8eb6f5"] }
    ]

    readonly property string currentId: Config.appearance.theme
    readonly property var current: resolve(list.find(t => t.id === currentId) ?? list.find(t => t.id === "gruvbox-material") ?? list[0])

    // ── User themes ──────────────────────────────────────────────────
    property var userThemes: []

    function valid(t): bool {
        const colour = c => typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c);
        return t && typeof t.id === "string" && /^[a-z0-9][a-z0-9-]*$/.test(t.id) && colour(t.bg) && colour(t.fg) && colour(t.accent) && Array.isArray(t.colors) && t.colors.length === 6 && t.colors.every(colour);
    }

    function collectUserThemes(): void {
        const out = [];
        for (let i = 0; i < userReaders.count; i++) {
            const t = userReaders.objectAt(i)?.theme;
            if (t)
                out.push(t);
        }
        root.userThemes = out;
    }

    FolderListModel {
        id: userFolder
        folder: Paths.ready ? "file://" + Paths.themes : Paths.nowhere
        nameFilters: ["*.json"]
        showDirs: false
    }

    Instantiator {
        id: userReaders
        model: userFolder
        delegate: FileView {
            required property string filePath
            property var theme: null
            // A FolderListModel lists the working directory until its folder
            // is set; never read anything outside the themes folder.
            readonly property bool ours: filePath.startsWith(Paths.themes + "/")
            path: ours ? filePath : ""
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                try {
                    const t = JSON.parse(text());
                    theme = root.valid(t) ? { id: t.id, bg: t.bg, fg: t.fg, accent: t.accent, colors: t.colors } : null;
                    if (!theme)
                        console.warn(`${Meta.name}: ignoring theme ${filePath}: needs id, bg, fg, accent and six colors as #rrggbb`);
                } catch (e) {
                    theme = null;
                    console.warn(`${Meta.name}: ignoring theme ${filePath}: ${e}`);
                }
                root.collectUserThemes();
            }
        }
        onObjectRemoved: root.collectUserThemes()
    }

    function indexOf(id: string): int {
        return root.list.findIndex(t => t.id === id);
    }

    // material-you, filled in from the wallpaper: a dark background tinted
    // with its dominant hue, its most colourful swatch as the accent, and
    // six of its colours, lifted to read on dark, as the swatches.
    function resolve(theme): var {
        if (!theme?.dynamic)
            return theme;
        const swatches = Wallpaper.colors;
        if (swatches.length === 0)
            return theme;
        const byChroma = [...swatches].sort((a, b) => (b.hslSaturation * (1 - Math.abs(b.hslLightness - 0.5))) - (a.hslSaturation * (1 - Math.abs(a.hslLightness - 0.5))));
        const hero = byChroma[0];
        const hue = hero.hslHue < 0 ? 0.08 : hero.hslHue;
        const lift = c => Qt.hsla(c.hslHue < 0 ? hue : c.hslHue, Math.min(0.55, Math.max(0.2, c.hslSaturation)), 0.68, 1);
        return {
            id: theme.id,
            dynamic: true,
            bg: Qt.hsla(hue, 0.18, 0.08, 1),
            fg: Qt.hsla(hue, 0.25, 0.9, 1),
            accent: Qt.hsla(hue, Math.min(0.6, Math.max(0.35, hero.hslSaturation)), 0.72, 1),
            colors: byChroma.slice(0, 6).map(lift)
        };
    }

    function apply(id: string): void {
        if (root.indexOf(id) < 0)
            return;
        Config.appearance.theme = id;
        Wallpaper.themeChanged(id);
    }
}
