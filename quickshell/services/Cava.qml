pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Audio levels from cava, as `bars` numbers in 0..1. cava only runs while
// something wants it (`users` > 0), so the visualiser costs nothing hidden.
//
// Stereo: the first half is the left channel from treble down to bass, the
// second half the right channel from bass up to treble — so laid round a
// shape from the bottom, bass meets itself at the top.
Singleton {
    id: root

    property int users: 0
    readonly property bool active: users > 0
    readonly property int bars: 48

    property var levels: new Array(bars).fill(0)

    readonly property string configPath: Paths.runtime + "/cava.conf"
    readonly property string config: `[general]
framerate = 60
bars = ${root.bars}
autosens = 1
[input]
method = pipewire
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = stereo
[smoothing]
noise_reduction = 70
`

    Process {
        id: proc
        running: root.active
        command: ["sh", "-c", 'printf "%s" "$1" > "$2" && exec cava -p "$2"', "sh", root.config, root.configPath]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = new Array(root.bars);
                for (let i = 0; i < root.bars; i++)
                    out[i] = Math.min(1, (parseInt(parts[i]) || 0) / 1000);
                root.levels = out;
            }
        }
        onRunningChanged: {
            if (!running)
                root.levels = new Array(root.bars).fill(0);
        }
    }
}
