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

    // How to call the running shell from a terminal or keybind, for hints:
    // the installed command, or Quickshell itself when run from source.
    // Followed by a target and a function: `<command> launcher toggle`.
    readonly property bool installed: !Quickshell.shellDir.startsWith(Quickshell.env("HOME") + "/")
    readonly property string command: installed ? "morpher dinozord" : `qs -p ${Quickshell.shellDir.replace(Quickshell.env("HOME"), "~")} ipc call`

    // The morpher binary (morpher/), which is both the installed command and,
    // run as `morpher alpha`, the shell's native side (see common/Morpher.qml):
    // where `make install` put it, or cargo's build next to the checkout.
    // $MORPHER overrides both.
    readonly property string binary: "/usr/local/bin/morpher"
    readonly property string morpher: Quickshell.env("MORPHER") || (installed ? binary : Quickshell.shellDir + "/../morpher/target/release/morpher")
}
