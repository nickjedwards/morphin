import QtQuick

// The shell's one animation. Everything that moves picks a `curve` and gets
// the matching duration and bezier, so shapes, positions and fades that run
// together stay in step instead of drifting apart mid-flight.
//
//   open   — panels growing: quick start, a soft ~3% settle past the target
//   close  — panels shrinking: eased in and out, never overshoots
//   hover  — small nudges: like open, but shorter
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
        const settle = [0.3, 1.3, 0.45, 1, 1, 1];
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
