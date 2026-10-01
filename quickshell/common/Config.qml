pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, persisted to $XDG_CONFIG_HOME/<name>/config.json. Anything
// the settings window changes lands here and is written back straight away.
// What the shell merely remembers between runs lives in State instead.
Singleton {
    id: root

    readonly property string path: Paths.config + "/config.json"

    property alias island: adapter.island
    property alias clock: adapter.clock
    property alias appearance: adapter.appearance
    property alias motion: adapter.motion
    property alias launcher: adapter.launcher
    property alias notifications: adapter.notifications
    property alias controlCenter: adapter.controlCenter
    property alias lock: adapter.lock
    property alias system: adapter.system
    property alias power: adapter.power

    readonly property var defaultLayout: [
        { type: "wifi", x: 0, y: 0, w: 3, h: 1 },
        { type: "focus", x: 3, y: 0, w: 3, h: 1 },
        { type: "lock", x: 6, y: 0, w: 1, h: 1 },
        { type: "bluetooth", x: 0, y: 1, w: 3, h: 1 },
        { type: "gamemode", x: 3, y: 1, w: 3, h: 1 },
        { type: "nightlight", x: 6, y: 1, w: 1, h: 1 },
        { type: "audio", x: 0, y: 2, w: 7, h: 1 },
        { type: "brightness", x: 0, y: 3, w: 7, h: 1 },
        { type: "notifications", x: 0, y: 4, w: 7, h: 3 }
    ]

    function save(): void {
        file.writeAdapter();
    }

    // Layouts saved before controls were combined: Sound and Microphone are
    // now one Audio control, Display and Keyboard one Brightness control.
    // The first of each pair found becomes the combined control where it was,
    // the other goes, and if it had a row to itself everything below moves
    // up to close the gap.
    readonly property var merged: ({
            audio: ["sound", "microphone"],
            brightness: ["display", "keyboard"]
        })

    function migrateLayout(): void {
        let items = adapter.controlCenter.items;
        let changed = false;
        for (const into of Object.keys(root.merged)) {
            const olds = root.merged[into];
            if (!items.some(i => olds.includes(i.type)))
                continue;
            changed = true;
            const exists = items.some(i => i.type === into);
            const keep = olds.map(t => items.find(i => i.type === t)).find(i => i);
            const dropped = items.filter(i => olds.includes(i.type) && (exists || i !== keep));
            let next = items.filter(i => !olds.includes(i.type)).map(i => Object.assign({}, i));
            if (!exists)
                next.push(Object.assign({}, keep, { type: into }));
            for (const gone of dropped.sort((a, b) => b.y - a.y)) {
                const rowStillUsed = next.some(i => i.y < gone.y + gone.h && gone.y < i.y + i.h);
                if (!rowStillUsed)
                    next = next.map(i => i.y > gone.y ? Object.assign({}, i, { y: i.y - gone.h }) : i);
            }
            items = next;
        }
        if (changed)
            adapter.controlCenter.items = items;
    }

    FileView {
        id: file
        // Only once the directory exists, so a first run can write the file.
        path: Paths.ready ? root.path : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: Qt.callLater(root.migrateLayout)
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property JsonObject island: JsonObject {
                property real scale: 1.5
                property bool hoverCalendar: true
                property int hoverDelay: 250
                property bool showAlbumArt: true
                property string ring: "battery"   // battery | volume | none
                property bool gameModeBar: true
                property string workspaces: "switch"   // switch | off
                property bool shadow: true
            }

            property JsonObject clock: JsonObject {
                property bool use24h: true
                property bool showSeconds: false
                property int weekStart: 0          // 0 = Sunday, 1 = Monday
                property bool highlightWeekends: true
            }

            property JsonObject appearance: JsonObject {
                property string theme: "gruvbox-material"
                property string accentMode: "theme"      // theme | custom
                property string customAccent: "#86c497"
                property string wallpaper: "~/.config/wallpaper"
                property string wallpaperDir: ""         // empty: the current wallpaper's folder
                property string transition: "fade"       // fade | none
                property string font: "Inter"
            }

            property JsonObject motion: JsonObject {
                property real speed: 1.0
                property bool bounce: true
            }

            property JsonObject launcher: JsonObject {
                property int maxResults: 6
                property bool showDescriptions: true
                property string terminal: "alacritty"
            }

            property JsonObject notifications: JsonObject {
                property bool popups: true
                property int popupSeconds: 5
                property bool silenceInGameMode: true
            }

            property JsonObject controlCenter: JsonObject {
                property int columns: 7
                property var items: root.defaultLayout
            }

            property JsonObject lock: JsonObject {
                property bool blur: true
                property bool showDate: true
                property bool twelveHour: false
            }

            property JsonObject power: JsonObject {
                property bool saverOnBattery: true
                property bool saverOnLowBattery: true
                property int lowBatteryThreshold: 20
            }

            property JsonObject system: JsonObject {
                property int nightLightTemp: 3700
                property bool osd: true
                property bool loadWarning: true       // red status ring under sustained strain
                property real brightnessCurve: 4      // like brightnessctl -e4; 1 = linear
                property string logoutCommand: "hyprctl dispatch 'hl.dsp.exit()'"
            }
        }
    }
}
