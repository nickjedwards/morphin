pragma Singleton

import QtQuick
import Quickshell
import qs.common

Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // Name prefix beats word start beats substring beats a scattered match;
    // the description and keywords count for a little.
    function score(app, q: string): int {
        const name = app.name.toLowerCase();
        if (name === q)
            return 1000;
        if (name.startsWith(q))
            return 800 - name.length;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 600 - name.length;
        if (name.includes(q))
            return 400 - name.indexOf(q);
        const extra = `${app.genericName ?? ""} ${app.comment ?? ""} ${(app.keywords ?? []).join(" ")}`.toLowerCase();
        if (extra.includes(q))
            return 200;
        let i = 0;
        for (const ch of name) {
            if (ch === q[i])
                i++;
            if (i === q.length)
                return 100 - name.length;
        }
        return -1;
    }

    // How much an app is used: launches, counting for less the longer ago
    // the last one was (halving every two weeks). 0 for never launched.
    function usage(app): real {
        const entry = (AppState.launches ?? {})[app.id];
        if (!entry)
            return 0;
        const days = Math.max(0, (Date.now() - entry.last) / 86400000);
        return entry.count * Math.pow(0.5, days / 14);
    }

    // With nothing typed: the apps you use, most used first, then the rest
    // by name. With a query: by how well the name matches, with use breaking
    // ties and lifting a regular over a stranger that matches about as well —
    // but never past a clearly better match (the boost stays under the gap
    // between match kinds).
    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (!q)
            return root.all.map(app => ({ app, u: root.usage(app) })).sort((a, b) => (b.u - a.u) || a.app.name.localeCompare(b.app.name)).map(r => r.app);
        return root.all.map(app => ({ app, s: root.score(app, q) })).filter(r => r.s >= 0).map(r => ({ app: r.app, s: r.s + Math.min(150, root.usage(r.app) * 30) })).sort((a, b) => b.s - a.s).map(r => r.app);
    }

    function remember(app): void {
        if (!app.id)
            return;
        const next = Object.assign({}, AppState.launches ?? {});
        const entry = next[app.id] ?? { count: 0, last: 0 };
        next[app.id] = { count: entry.count + 1, last: Date.now() };
        // Keep the 200 most recently used; uninstalled apps fall out in time.
        const ids = Object.keys(next);
        if (ids.length > 200)
            for (const id of ids.sort((a, b) => next[a].last - next[b].last).slice(0, ids.length - 200))
                delete next[id];
        AppState.launches = next;
    }

    function forget(): void {
        AppState.launches = {};
    }

    function launch(app): void {
        root.remember(app);
        if (app.runInTerminal)
            Quickshell.execDetached([Config.launcher.terminal, "-e", ...app.command]);
        else
            app.execute();
    }
}
