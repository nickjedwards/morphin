pragma Singleton

import Quickshell
import qs.common

Singleton {
    id: root

    property bool visible: false
    property string page: "island"
    property var back: []
    property var forward: []
    property string search: ""

    readonly property var pages: [
        { id: "island", label: "Bar & Island", icon: Icons.island, keywords: "scale size hover calendar album art ring battery volume game bar" },
        { id: "clock", label: "Clock & Date", icon: Icons.clock, keywords: "24 hour seconds week start monday sunday time" },
        { id: "appearance", label: "Appearance", icon: Icons.palette, keywords: "accent colour color wallpaper font theme" },
        { id: "motion", label: "Motion", icon: Icons.motion, keywords: "animation speed bounce spring" },
        { id: "launcher", label: "Launcher", icon: Icons.search, keywords: "apps search results terminal" },
        { id: "notifications", label: "Notifications", icon: Icons.bell, keywords: "popup focus do not disturb game" },
        { id: "controlcenter", label: "Control Center", icon: Icons.tune, keywords: "layout grid tiles controls arrange" },
        { id: "system", label: "System", icon: Icons.cog, keywords: "night light osd logout brightness" }
    ]

    function toggle(): void {
        root.visible = !root.visible;
    }

    function open(page: string): void {
        if (page)
            root.go(page);
        root.visible = true;
    }

    function go(page: string): void {
        if (page === root.page)
            return;
        root.back = root.back.concat([root.page]);
        root.forward = [];
        root.page = page;
    }

    function goBack(): void {
        if (root.back.length === 0)
            return;
        root.forward = [root.page].concat(root.forward);
        root.page = root.back[root.back.length - 1];
        root.back = root.back.slice(0, -1);
    }

    function goForward(): void {
        if (root.forward.length === 0)
            return;
        root.back = root.back.concat([root.page]);
        root.page = root.forward[0];
        root.forward = root.forward.slice(1);
    }
}
