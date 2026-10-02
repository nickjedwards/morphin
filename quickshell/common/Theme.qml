pragma Singleton

import QtQuick
import Quickshell

// Every size in the shell is written in "reference units": pixels as measured
// off the reference recording. `u()` turns them into real pixels, so the whole
// island can be resized by changing the scale alone.
Singleton {
    id: root

    readonly property real scale: Config.island.scale

    function u(v: real): int {
        return Math.round(v * root.scale);
    }

    // ── Palette ──────────────────────────────────────────────────────
    // Three colours from the current theme, eased when the theme changes so
    // the whole shell recolours smoothly; everything below derives from them.
    property color base: Themes.current.bg
    property color fg: Themes.current.fg
    property color accent: Config.appearance.accentMode === "custom" ? Config.appearance.customAccent : Themes.current.accent
    Behavior on base { ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on fg { ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }

    readonly property var swatches: Themes.current.colors

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    function over(a: color, b: color, alpha: real): color {
        return Qt.tint(a, Qt.rgba(b.r, b.g, b.b, alpha));
    }

    // Ink on the accent: very dark in the accent's own hue.
    readonly property color accentInk: Qt.hsla(Math.max(0, accent.hslHue), 0.45, 0.1, 1)
    readonly property color accentSoft: over(bg, accent, 0.14)
    readonly property color accentMuted: over(surface, accent, 0.45)

    // ── Surfaces ─────────────────────────────────────────────────────
    // The island stays near-black, just tinted by the theme; cards and
    // controls step up from the theme's own background.
    readonly property color bg: mix(base, "#000000", 0.6)
    readonly property color sidebar: mix(base, "#000000", 0.45)
    readonly property color card: over(mix(base, "#000000", 0.25), fg, 0.035)
    readonly property color cardItem: over(card, fg, 0.05)
    readonly property color surface: over(card, fg, 0.06)
    readonly property color surfaceHover: over(card, fg, 0.11)
    readonly property color track: mix(base, "#000000", 0.5)
    readonly property color iconOff: over(card, fg, 0.12)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)

    readonly property color avatar: over(card, fg, 0.08)
    readonly property color avatarInk: accent

    // ── Text ─────────────────────────────────────────────────────────
    readonly property color text: fg
    readonly property color textDim: mix(fg, card, 0.42)
    readonly property color textFaint: mix(fg, card, 0.64)
    readonly property color weekend: swatches[0] ?? "#e0707a"
    readonly property color danger: red

    // The theme's reddest swatch: nearest in hue to red, among those with
    // enough colour to read as red at all. For fixed themes that's their red;
    // material-you's swatches come from the wallpaper in no set order.
    readonly property color red: {
        let best = null;
        let bestScore = Infinity;
        for (const c of swatches) {
            const col = Qt.color(c);
            if (col.hslSaturation < 0.2 || col.hslHue < 0)
                continue;
            const distance = Math.min(col.hslHue, 1 - col.hslHue);
            // Pale pinks sit close to red in hue but don't read as red.
            const score = distance + Math.abs(col.hslLightness - 0.6) * 0.3 - col.hslSaturation * 0.05;
            if (score < bestScore) {
                bestScore = score;
                best = col;
            }
        }
        return best ?? "#e5534b";
    }
    readonly property color ring: fg
    // Power Saver and Performance, from the theme's green and yellow.
    readonly property color good: swatches[1] ?? "#a9b665"
    readonly property color warn: swatches[2] ?? "#d8a657"

    readonly property string font: Config.appearance.font
    readonly property string iconFont: "Symbols Nerd Font"

    // ── Motion ───────────────────────────────────────────────────────
    // Durations for Anim's curves; the Motion speed setting scales them all.
    readonly property real speed: Math.max(0.1, Config.motion.speed)
    readonly property int openDuration: Math.round(600 / speed)
    readonly property int closeDuration: Math.round(400 / speed)
    readonly property int hoverDuration: Math.round(360 / speed)
    readonly property int fastDuration: Math.round(200 / speed)
}
