pragma Singleton

import Quickshell

// Every control the control center can hold: its name, icon, the sizes it
// comes in (in grid cells), and the size it gets when first added.
Singleton {
    id: root

    function range(from: int, to: int): var {
        const out = [];
        for (let i = from; i <= to; i++)
            out.push(i);
        return out;
    }

    function toggleSizes(): var {
        return [[1, 1], [2, 1], [3, 1], [4, 1]];
    }

    readonly property var types: ({
            wifi: { label: "Wi-Fi", icon: Icons.wifi, sizes: toggleSizes(), size: [3, 1], page: "wifi" },
            bluetooth: { label: "Bluetooth", icon: Icons.bluetooth, sizes: toggleSizes(), size: [3, 1], page: "bluetooth" },
            focus: { label: "Focus", icon: Icons.focus, sizes: toggleSizes(), size: [3, 1] },
            gamemode: { label: "Game Mode", icon: Icons.gameMode, sizes: toggleSizes(), size: [3, 1] },
            nightlight: { label: "Night Light", icon: Icons.nightLight, sizes: toggleSizes(), size: [1, 1] },
            lock: { label: "Lock", icon: Icons.lock, sizes: [[1, 1], [2, 1], [3, 1]], size: [1, 1] },
            power: { label: "Power", icon: Icons.power, sizes: [[1, 1], [2, 1], [3, 1]], size: [1, 1] },
            audio: { label: "Audio", icon: Icons.volumeHigh, sizes: range(3, 9).map(w => [w, 1]), size: [7, 1], page: "audio" },
            brightness: { label: "Brightness", icon: Icons.brightness, sizes: range(3, 9).map(w => [w, 1]), size: [7, 1], page: "display" },
            notifications: { label: "Notifications", icon: Icons.bell, sizes: range(4, 9).reduce((all, w) => all.concat(range(2, 6).map(h => [w, h])), []), size: [7, 3] },
            system: { label: "System", icon: Icons.chip, page: "system", sizes: [[1, 1]].concat(range(3, 9).map(w => [w, 1])), size: [7, 1] },
            powermode: { label: "Power Mode", icon: Icons.speedometer, page: "power", sizes: [[1, 1]].concat(range(3, 9).map(w => [w, 1])), size: [7, 1] },
            nowplaying: { label: "Now Playing", icon: Icons.music, sizes: range(3, 9).map(w => [w, 2]), size: [3, 2] }
        })

    readonly property var order: ["wifi", "bluetooth", "focus", "gamemode", "nightlight", "lock", "power", "audio", "brightness", "system", "powermode", "notifications", "nowplaying"]

    function info(type: string): var {
        return root.types[type] ?? { label: type, icon: Icons.app, sizes: [[1, 1]], size: [1, 1] };
    }

    function sizesFor(type: string, columns: int): var {
        return root.info(type).sizes.filter(s => s[0] <= columns);
    }

    // Nearest supported size to a requested one — for corner-dragging.
    function snapSize(type: string, w: int, h: int, columns: int): var {
        let best = null;
        let bestD = Infinity;
        for (const s of root.sizesFor(type, columns)) {
            const d = Math.abs(s[0] - w) * 1.2 + Math.abs(s[1] - h);
            if (d < bestD) {
                bestD = d;
                best = s;
            }
        }
        return best ?? [1, 1];
    }
}
