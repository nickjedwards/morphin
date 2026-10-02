import QtQuick

// The shell's one animation. Everything that moves picks a `curve` and gets
// the matching duration and bezier, so shapes, positions and fades that run
// together stay in step instead of drifting apart mid-flight.
//
//   open   — panels growing: elastic — a quick start, about 6% past the
//            target, a small rebound just under it, then rest
//   close  — panels shrinking: eased in and out, never overshoots
//   hover  — small nudges: the same spring, shorter
//   fade   — opacity and colour-ish things: plain decelerate
NumberAnimation {
    property string curve: "open"

    duration: {
        switch (curve) {
        case "close":
            return Theme.closeDuration;
        case "hover":
            return Theme.hoverDuration;
        case "fade":
            return Theme.fastDuration;
        }
        return Theme.openDuration;
    }
    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        // Three bezier segments joined where the motion turns round, each
        // join flat so the curve stays smooth: up to 1.06 by 42% of the
        // time, back to 0.988 by 70%, and home.
        const settle = [0.15, 0.9, 0.3, 1.06, 0.42, 1.06, 0.52, 1.06, 0.6, 0.988, 0.7, 0.988, 0.8, 0.988, 0.88, 1, 1, 1];
        const decelerate = [0.2, 0, 0, 1, 1, 1];
        switch (curve) {
        case "close":
            return [0.3, 0, 0.1, 1, 1, 1];
        case "fade":
            return decelerate;
        }
        return Config.motion.bounce ? settle : decelerate;
    }
}
