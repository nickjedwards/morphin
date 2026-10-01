pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Where the shell keeps things, per the XDG Base Directory spec. Each base
// honours its environment variable and falls back to the spec's default.
//
//   config   $XDG_CONFIG_HOME/<name>      settings you choose (config.json)
//   state    $XDG_STATE_HOME/<name>       what it remembers between runs
//   cache    $XDG_CACHE_HOME/<name>       safe to delete; rebuilt as needed
//   data     $XDG_DATA_HOME/<name>        things you add (themes/)
//   runtime  $XDG_RUNTIME_DIR/<name>      this session only (generated files)
//
// Named directories rather than Quickshell.statePath() and friends: those
// are keyed by a hash of the config's location, so moving the checkout
// would lose everything.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    function base(variable: string, fallback: string): string {
        const value = Quickshell.env(variable);
        // The spec says relative paths are invalid and must be ignored.
        return value && value.startsWith("/") ? value : root.home + fallback;
    }

    readonly property string configHome: base("XDG_CONFIG_HOME", "/.config")
    readonly property string stateHome: base("XDG_STATE_HOME", "/.local/state")
    readonly property string cacheHome: base("XDG_CACHE_HOME", "/.cache")
    readonly property string dataHome: base("XDG_DATA_HOME", "/.local/share")

    readonly property string config: configHome + "/" + Meta.name
    readonly property string state: stateHome + "/" + Meta.name
    readonly property string cache: cacheHome + "/" + Meta.name
    readonly property string data: dataHome + "/" + Meta.name
    // No runtime dir (rare outside a login session): fall back to the cache.
    readonly property string runtime: {
        const dir = Quickshell.env("XDG_RUNTIME_DIR");
        return dir && dir.startsWith("/") ? dir + "/" + Meta.name : root.cache + "/runtime";
    }

    readonly property string themes: data + "/themes"
    readonly property string artCache: cache + "/art"

    // For a FolderListModel with nothing to list yet: an empty folder makes
    // it list the process's working directory instead.
    readonly property url nowhere: "file:///nonexistent/" + Meta.name

    // Expand a leading ~ the way a shell would.
    function expand(p: string): string {
        return p.startsWith("~") ? root.home + p.slice(1) : p;
    }

    // Everything exists before anyone writes: the runtime dir private to us,
    // as the spec requires of it.
    property bool ready: false
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$1" "$2" "$3" "$4" "$5" && chmod 700 "$5"', "sh", root.config, root.state, root.artCache, root.themes, root.runtime]
        onExited: root.ready = true
    }
}
