pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the shell remembers between runs, as opposed to what you've set:
// persisted to $XDG_STATE_HOME/<name>/state.json. Losing this file costs
// nothing but a little memory of how things were.
Singleton {
    id: root

    readonly property string path: Paths.state + "/state.json"

    // theme id → the wallpaper last used with it
    property alias themeWallpapers: adapter.themeWallpapers
    // Toggles that should survive a restart.
    property alias focus: adapter.focus
    property alias nightLight: adapter.nightLight
    // app id → { count, last (ms since epoch) }, for ranking the launcher
    property alias launches: adapter.launches

    property bool loaded: false

    FileView {
        id: file
        path: Paths.ready ? root.path : ""
        onAdapterUpdated: writeAdapter()
        onLoaded: root.loaded = true
        onLoadFailed: error => {
            // Deferred: reading and writing from inside this handler gets
            // dropped as part of the failed operation.
            if (error === FileViewError.FileNotFound)
                Qt.callLater(() => legacy.path = Paths.config + "/config.json");
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter
            property var themeWallpapers: ({})
            property bool focus: false
            property bool nightLight: false
            property var launches: ({})
        }
    }

    // First run with a state file: carry over what older versions kept in
    // config.json.
    FileView {
        id: legacy
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const old = JSON.parse(text()).appearance?.themeWallpapers;
                if (old && Object.keys(old).length > 0)
                    adapter.themeWallpapers = old;
            } catch (e) {}
            Qt.callLater(file.writeAdapter);
        }
        onLoadFailed: Qt.callLater(file.writeAdapter)
    }
}
