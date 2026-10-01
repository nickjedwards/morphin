pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.common

// The one player the island follows. One you've picked (by cycling) wins,
// until some other player starts playing; otherwise whichever is playing,
// else the one that played last, else the first that can be controlled.
//
// playerctld is left out: it only forwards to whichever player it thinks is
// active, which isn't always the one on screen.
Singleton {
    id: root

    property MprisPlayer lastPlaying: null
    property MprisPlayer pinned: null

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    // The players cycling walks, by name. Ones that can't play or pause
    // (a browser with no media left, say) are skipped while others can.
    readonly property var usable: players.filter(p => p.isPlaying || p.canPlay || p.canPause)
    readonly property var cycleOrder: [...(usable.length > 0 ? usable : players)].sort((a, b) => a.identity.localeCompare(b.identity) || a.dbusName.localeCompare(b.dbusName))

    readonly property MprisPlayer player: {
        const list = root.players;
        if (root.pinned && list.includes(root.pinned))
            return root.pinned;
        const playing = list.find(p => p.isPlaying);
        if (playing)
            return playing;
        if (root.lastPlaying && list.includes(root.lastPlaying))
            return root.lastPlaying;
        return root.usable[0] ?? list[0] ?? null;
    }
    readonly property int playerIndex: cycleOrder.indexOf(player)

    readonly property bool available: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || "Nothing playing"
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string identity: player?.identity ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0

    // Fired whenever playback starts or stops, for the on-screen indicator.
    signal playbackToggled(bool playing)

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged(): void {
                if (modelData.dbusName.includes("playerctld"))
                    return;
                if (modelData.isPlaying) {
                    root.lastPlaying = modelData;
                    // Something else started: follow it rather than the pin.
                    if (root.pinned && root.pinned !== modelData)
                        root.pinned = null;
                }
                if (modelData === root.player || modelData.isPlaying)
                    root.playbackToggled(modelData.isPlaying);
            }
        }
    }

    // ── Art colour ───────────────────────────────────────────────────
    // The cover's most colourful swatch, lifted so it reads on the dark
    // card; the theme accent when there's no art to sample.
    // ColorQuantizer only reads local files, and players like Spotify hand
    // out https art, so remote covers are fetched into a small cache first.
    property string artFile: ""
    readonly property string artCache: Paths.artCache

    onArtUrlChanged: {
        const url = root.artUrl;
        if (!url) {
            root.artFile = "";
        } else if (url.startsWith("file://")) {
            root.artFile = url;
        } else if (/^https?:/.test(url)) {
            const name = url.replace(/[^A-Za-z0-9]/g, "").slice(-48);
            fetcher.target = `${root.artCache}/${name}`;
            // A cache hit just refreshes the file's time; a miss downloads it
            // (to a temp name, so a failed download never looks cached). The
            // cache then keeps the 200 most recently used covers.
            fetcher.command = ["sh", "-c", `mkdir -p "$1"
if [ -s "$2" ]; then touch "$2"; else curl -fsSL --max-time 10 -o "$2.part" "$3" && mv "$2.part" "$2"; fi
status=$?
ls -t "$1" | tail -n +201 | while read -r f; do rm -f "$1/$f"; done
exit $status`, "sh", root.artCache, fetcher.target, url];
            fetcher.running = true;
        }
    }

    Process {
        id: fetcher
        property string target
        onExited: code => {
            if (code === 0)
                root.artFile = "file://" + fetcher.target;
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root.artFile
        depth: 3
        rescaleSize: 64
    }

    readonly property color artColor: {
        let best = null;
        let bestScore = -1;
        for (const c of quantizer.colors) {
            const score = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.4);
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }
        if (!best || !root.artFile)
            return Theme.accent;
        // Near-grey covers keep their tone rather than inventing a hue.
        if (best.hslSaturation < 0.12)
            return Qt.hsla(0, 0, 0.78, 1);
        return Qt.hsla(best.hslHue, Math.max(0.4, Math.min(0.8, best.hslSaturation)), 0.68, 1);
    }

    // MPRIS doesn't push position updates; poke the player while anyone cares.
    property int positionWatchers: 0
    Timer {
        running: root.playing && root.positionWatchers > 0
        interval: 500
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // Browsers in particular report play and pause separately, or not at
    // all while a tab is changing state, so fall through to whichever call
    // the player accepts, and to playerctl as a last resort.
    function togglePlaying(): void {
        const p = root.player;
        if (!p)
            return;
        if (p.canTogglePlaying)
            p.togglePlaying();
        else if (p.isPlaying && p.canPause)
            p.pause();
        else if (!p.isPlaying && p.canPlay)
            p.play();
        else
            root.playerctl("play-pause");
    }
    function next(): void {
        if (root.player?.canGoNext)
            root.player.next();
        else
            root.playerctl("next");
    }
    function previous(): void {
        if (root.player?.canGoPrevious)
            root.player.previous();
        else
            root.playerctl("previous");
    }

    // The player's bus name without the MPRIS prefix is what playerctl calls it.
    function playerctl(action: string): void {
        if (!root.player)
            return;
        const name = root.player.dbusName.replace("org.mpris.MediaPlayer2.", "");
        Quickshell.execDetached(["playerctl", "--player=" + name, action]);
    }

    // Pin the next (or previous) player; it stays until another one plays.
    function cycle(delta: int): void {
        const list = root.cycleOrder;
        if (list.length < 2)
            return;
        const at = Math.max(0, list.indexOf(root.player));
        root.pinned = list[(at + delta + list.length) % list.length];
    }

    function describe(p): string {
        if (!p)
            return "";
        const state = p.isPlaying ? "playing" : p.playbackState === MprisPlaybackState.Paused ? "paused" : "stopped";
        return `${p.identity} (${state})${p === root.player ? " *" : ""}`;
    }
    function seek(fraction: real): void {
        if (root.player?.canSeek && root.length > 0)
            root.player.position = fraction * root.length;
    }

    function formatTime(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }
}
