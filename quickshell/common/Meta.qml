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
    // installed command, or `qs -p <this folder>` when run from source.
    readonly property bool installed: !Quickshell.shellDir.startsWith(Quickshell.env("HOME") + "/")
    readonly property string command: installed ? "morpher" : `qs -p ${Quickshell.shellDir.replace(Quickshell.env("HOME"), "~")}`

    // The morpher binary (morpher/), which is both the installed command and,
    // run as `morpher serve`, the shell's native side (see common/Morpher.qml):
    // where `make install` put it, or cargo's build next to the checkout.
    // $MORPHER overrides both.
    readonly property string binary: "/usr/local/bin/morpher"
    readonly property string morpher: Quickshell.env("MORPHER") || (installed ? binary : Quickshell.shellDir + "/../morpher/target/release/morpher")
}
