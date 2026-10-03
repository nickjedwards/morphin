pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// morpher, the shell's native side: the binary (morpher/, in Rust) run as
// `morpher serve`, started once, for the things QML would otherwise poll or
// start a process for — what's on this machine at startup, the process list,
// the backlights. It talks in lines of JSON, both ways.
//
// The shell needs it: until it's `available` there are no directories to
// keep settings in, and nothing reads the process list or the backlights.
Singleton {
    id: root

    // True once it has said hello.
    property bool available: false

    // What it found at startup: cpuTemp, kbd { device, max }, hyprpaper,
    // hyprsunset, zone, wallpaperLink. Empty until it's ready.
    property var info: ({})

    // Everything it says after hello: { type, … }.
    signal message(var msg)

    function send(msg: var): void {
        if (proc.running)
            proc.write(JSON.stringify(msg) + "\n");
    }

    Process {
        id: proc
        running: true
        stdinEnabled: true
        command: [Meta.morpher, "serve"]
        // It makes the shell's directories before answering, so `ready`
        // also means they exist.
        onStarted: root.send({ cmd: "init", dirs: [Paths.config, Paths.state, Paths.artCache, Paths.themes], privateDir: Paths.runtime, link: Paths.wallpaperLink })
        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.type === "hello") {
                    root.info = msg;
                    root.available = true;
                } else {
                    root.message(msg);
                }
            }
        }
        onRunningChanged: {
            if (running)
                return;
            root.available = false;
            console.error(`${Meta.name}: ${Meta.morpher} serve isn't running; build it with make`);
        }
    }
}
