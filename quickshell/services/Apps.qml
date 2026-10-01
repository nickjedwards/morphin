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

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (!q)
            return root.all;
        return root.all.map(app => ({ app, s: root.score(app, q) })).filter(r => r.s >= 0).sort((a, b) => b.s - a.s).map(r => r.app);
    }

    function launch(app): void {
        if (app.runInTerminal)
            Quickshell.execDetached([Config.launcher.terminal, "-e", ...app.command]);
        else
            app.execute();
    }
}
