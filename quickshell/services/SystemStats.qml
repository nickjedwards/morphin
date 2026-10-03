pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// CPU and memory use, read straight from /proc — plain file reads, no
// processes. It ticks slowly in the background, just enough to notice
// sustained strain for the status ring; once a second while something is
// showing the numbers (`watchers`); and it only keeps history, reads the
// temperature and lists processes (which come from morpher) while the
// System page is open (`detailWatchers`).
Singleton {
    id: root

    property int watchers: 0
    property int detailWatchers: 0

    // ── CPU ──────────────────────────────────────────────────────────
    property real cpu: 0                 // 0..1 across all cores
    property var cores: []               // 0..1 each
    property var history: []             // last minute of `cpu`, oldest first
    readonly property int historyLength: 60
    property real temperature: 0         // °C, 0 when unknown

    // ── Memory ───────────────────────────────────────────────────────
    property real memTotal: 0            // all in GiB
    property real memUsed: 0             // what apps hold (total − available)
    property real memCached: 0           // reclaimable cache, part of "free"
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0

    // ── Strain ───────────────────────────────────────────────────────
    // CPU pinned for ten seconds, or memory nearly gone.
    readonly property real cpuLimit: 0.9
    readonly property real memLimit: 0.9
    property real cpuHotSince: 0
    property bool cpuStrained: false
    readonly property bool memStrained: mem >= memLimit
    readonly property bool strained: cpuStrained || memStrained

    // ── Processes ────────────────────────────────────────────────────
    property string sortBy: "cpu"        // cpu | mem
    property var processes: []           // [{ pid, name, cpu, mem }]

    function gib(v: real): string {
        return v >= 10 ? v.toFixed(0) : v.toFixed(1);
    }

    // /proc/stat: "cpu user nice system idle iowait irq softirq steal …" in
    // ticks since boot; use is the change in busy over the change in total.
    property var lastTicks: ({})

    function parseStat(text: string): void {
        const next = {};
        const cores = [];
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                break;
            const f = line.trim().split(/\s+/);
            const v = f.slice(1, 9).map(Number);
            const idle = v[3] + v[4];
            const total = v.reduce((a, b) => a + b, 0);
            next[f[0]] = [idle, total];
            const prev = root.lastTicks[f[0]];
            const use = prev && total > prev[1] ? 1 - (idle - prev[0]) / (total - prev[1]) : 0;
            if (f[0] === "cpu")
                root.cpu = Math.max(0, Math.min(1, use));
            else
                cores.push(Math.max(0, Math.min(1, use)));
        }
        root.lastTicks = next;
        root.cores = cores;

        if (root.detailWatchers > 0)
            root.history = root.history.concat([root.cpu]).slice(-root.historyLength);

        const now = Date.now();
        if (root.cpu >= root.cpuLimit) {
            if (root.cpuHotSince === 0)
                root.cpuHotSince = now;
            root.cpuStrained = now - root.cpuHotSince >= 10000;
        } else {
            root.cpuHotSince = 0;
            root.cpuStrained = false;
        }
    }

    function parseMeminfo(text: string): void {
        const kb = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kb[m[1]] = Number(m[2]);
        }
        const g = 1024 * 1024;
        root.memTotal = (kb.MemTotal ?? 0) / g;
        root.memUsed = ((kb.MemTotal ?? 0) - (kb.MemAvailable ?? 0)) / g;
        root.memCached = ((kb.Cached ?? 0) + (kb.Buffers ?? 0) + (kb.SReclaimable ?? 0)) / g;
        root.swapTotal = (kb.SwapTotal ?? 0) / g;
        root.swapUsed = ((kb.SwapTotal ?? 0) - (kb.SwapFree ?? 0)) / g;
    }

    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.parseStat(text())
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.parseMeminfo(text())
    }

    Timer {
        interval: root.watchers > 0 || root.detailWatchers > 0 ? 1000 : 3000
        running: true
        repeat: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (root.detailWatchers > 0 && temp.path !== "")
                temp.reload();
        }
    }

    // ── Temperature ──────────────────────────────────────────────────
    // The CPU's own sensor, which morpher finds by name at startup: hwmon
    // numbers move around.
    FileView {
        id: temp
        path: Morpher.info.cpuTemp ?? ""
        printErrors: false
        onLoaded: root.temperature = parseInt(text()) / 1000
    }

    // ── Processes ────────────────────────────────────────────────────
    // morpher reads /proc itself and sends the list once a second while
    // it's asked to; a change of order is answered straight away.
    readonly property bool detailed: detailWatchers > 0

    function ask(): void {
        Morpher.send({ cmd: "procs", on: root.detailed, sort: root.sortBy });
    }

    onDetailedChanged: ask()

    Connections {
        target: Morpher
        function onAvailableChanged(): void {
            if (Morpher.available && root.detailed)
                root.ask();
        }
        function onMessage(msg): void {
            if (msg.type === "procs" && root.detailed)
                root.processes = msg.list;
        }
    }

    onSortByChanged: ask()

    onDetailWatchersChanged: {
        if (root.detailWatchers === 0) {
            root.history = [];
            root.processes = [];
        }
    }
}
