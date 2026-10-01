pragma Singleton

import Quickshell

// The shell's name, in one place. Everything named after the shell — its
// XDG folders, layer namespaces, the settings window, the command shown in
// hints — reads it from here.
//
// `make install NAME=…` rewrites the value below in the installed copy, so a
// packaged build can be called anything without touching the source.
Singleton {
    readonly property string name: "morphin"

    // How to reach the running shell from a terminal or keybind: the
    // installed launcher, or `qs -p <this folder>` when run from source.
    readonly property bool installed: !Quickshell.shellDir.startsWith(Quickshell.env("HOME") + "/")
    readonly property string command: installed ? name : `qs -p ${Quickshell.shellDir.replace(Quickshell.env("HOME"), "~")}`
}
