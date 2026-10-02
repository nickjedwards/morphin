import QtQuick
import qs.common

// A progress line in three parts: what's played as a wave, a short upright
// bar at the current position, and what's left as a thin straight line. The
// wave travels while playing and settles flat when paused.
Item {
    id: root

    property real fraction: 0
    property bool playing: false
    property color color: Theme.accent
    property color restColor: Qt.rgba(1, 1, 1, 0.2)

    readonly property real stroke: Math.max(2, Theme.u(2))
    readonly property real wavelength: Theme.u(15)
    readonly property real handleWidth: Math.max(2, Theme.u(2.5))

    implicitHeight: Theme.u(11)

    // Eased, so half-second position updates glide rather than tick.
    property real shown: Math.max(0, Math.min(1, fraction))
    Behavior on shown { NumberAnimation { duration: 500 } }

    // Wave height: full while playing, flat when paused.
    property real amplitude: playing ? Theme.u(2.2) : 0
    Behavior on amplitude { Anim { curve: "close" } }

    // The wave's travel: one wavelength every 1.6 s, only while it shows.
    property real phase: 0
    NumberAnimation on phase {
        running: root.playing && root.visible
        from: 0
        to: 2 * Math.PI
        duration: 1600
        loops: Animation.Infinite
    }

    onShownChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()
    onPhaseChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const mid = height / 2;
            const cap = root.stroke / 2;
            const at = cap + (width - cap * 2) * root.shown;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // What's left.
            if (at < width - cap) {
                ctx.beginPath();
                ctx.moveTo(Math.min(width - cap, at + root.handleWidth * 2), mid);
                ctx.lineTo(width - cap, mid);
                ctx.lineWidth = Math.max(1, root.stroke / 2);
                ctx.strokeStyle = root.restColor;
                ctx.stroke();
            }

            // What's played: a sine that eases to nothing at each end, so it
            // starts on the centre line and meets the handle on it.
            const end = at - root.handleWidth;
            if (end > cap) {
                const k = 2 * Math.PI / root.wavelength;
                const ramp = root.wavelength / 2;
                ctx.beginPath();
                for (let x = cap; x <= end; x += 1) {
                    const edge = Math.min(1, (x - cap) / ramp, (end - x) / ramp);
                    const y = mid + Math.sin(x * k - root.phase) * root.amplitude * Math.max(0, edge);
                    x === cap ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.lineWidth = root.stroke;
                ctx.strokeStyle = root.color;
                ctx.stroke();
            }

            // Where it is now.
            ctx.beginPath();
            ctx.moveTo(at, cap + root.handleWidth / 2);
            ctx.lineTo(at, height - cap - root.handleWidth / 2);
            ctx.lineWidth = root.handleWidth;
            ctx.strokeStyle = root.color;
            ctx.stroke();
        }
    }
}
