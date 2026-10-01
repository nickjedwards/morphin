import QtQuick
import qs.common
import qs.services

// The audio pulse around the album art: the art's own rounded-square outline
// pushed outwards by each cava band, all the way round, as one smooth shape.
// Laid out from the bottom going clockwise, so with cava's stereo order the
// left channel runs up the left side, the right channel down the right, and
// the bass meets at the top. At silence it settles to a thin even halo.
//
// Place it over the art (same centre), sized `artSize + 2 * (gap + reach)`,
// and draw it behind the art.
Canvas {
    id: pulse

    property real artSize: Theme.u(94)
    property real artRadius: Theme.u(8)
    property real gap: Theme.u(1.5)
    property real reach: Theme.u(9)
    property color color: Media.artColor
    property bool live: true

    Behavior on color { ColorAnimation { duration: 600 } }

    // Levels eased toward cava's so the shape breathes rather than jitters:
    // quick to rise, slower to fall.
    property var shown: new Array(Cava.bars).fill(0)

    width: artSize + 2 * (gap + reach)
    height: width
    opacity: live ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { Anim { curve: "fade"; duration: 400 } }

    // Keep cava running only while there's something to show.
    property bool registered: false
    function sync(): void {
        const want = pulse.live && pulse.visible;
        if (want !== pulse.registered) {
            Cava.users += want ? 1 : -1;
            pulse.registered = want;
        }
    }
    onLiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (pulse.registered)
            Cava.users--;
    }

    Connections {
        target: Cava
        function onLevelsChanged(): void {
            const target = pulse.live ? Cava.levels : null;
            const next = new Array(Cava.bars);
            let moving = false;
            for (let i = 0; i < Cava.bars; i++) {
                const to = target ? target[i] : 0;
                const from = pulse.shown[i] ?? 0;
                next[i] = from + (to - from) * (to > from ? 0.6 : 0.25);
                if (Math.abs(next[i] - from) > 0.002)
                    moving = true;
            }
            pulse.shown = next;
            if (moving)
                pulse.requestPaint();
        }
    }

    // When cava stops, ease the shape back down to the halo.
    Timer {
        running: !Cava.active && pulse.shown.some(v => v > 0.002)
        interval: 16
        repeat: true
        onTriggered: {
            pulse.shown = pulse.shown.map(v => v * 0.8);
            pulse.requestPaint();
        }
    }

    onColorChanged: requestPaint()

    // Distance from the centre of a rounded square to its edge along a ray
    // with |cos| = c, |sin| = s. `h` is centre-to-side, `r` the corner radius.
    function edge(c: real, s: real, h: real, r: real): real {
        const a = h - r;
        if (c < 1e-6 || s < 1e-6)
            return h;
        const side = h / c;
        if (side * s <= a)
            return side;
        const top = h / s;
        if (top * c <= a)
            return top;
        // Corner circle centred on (a, a): solve |t·(c, s) − (a, a)| = r.
        const k = a * (c + s);
        return k + Math.sqrt(Math.max(0, k * k - (2 * a * a - r * r)));
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = Cava.bars;
        const cx = width / 2;
        const cy = height / 2;
        const h = pulse.artSize / 2;

        const pts = [];
        for (let i = 0; i < n; i++) {
            // Start at the bottom (90°) and go clockwise on screen.
            const t = Math.PI / 2 + 2 * Math.PI * (i + 0.5) / n;
            const c = Math.cos(t);
            const s = Math.sin(t);
            const d = pulse.edge(Math.abs(c), Math.abs(s), h, pulse.artRadius) + pulse.gap + pulse.reach * Math.pow(pulse.shown[i] ?? 0, 0.8);
            pts.push([cx + c * d, cy + s * d]);
        }

        // Smooth closed curve through the midpoints, each point a control.
        ctx.beginPath();
        const mid = (p, q) => [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
        let m = mid(pts[n - 1], pts[0]);
        ctx.moveTo(m[0], m[1]);
        for (let i = 0; i < n; i++) {
            const p = pts[i];
            const q = mid(p, pts[(i + 1) % n]);
            ctx.quadraticCurveTo(p[0], p[1], q[0], q[1]);
        }
        ctx.closePath();

        const col = pulse.color;
        ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.55);
        ctx.fill();
        ctx.lineWidth = Math.max(1, Theme.u(1));
        ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.9);
        ctx.stroke();
    }
}
