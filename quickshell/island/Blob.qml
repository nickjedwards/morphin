import QtQuick
import QtQuick.Effects
import qs.common

// One black shape of the island. It morphs between a small pill/circle and a
// panel by animating its size; the radius follows so corners stay continuous.
//
// An Item holding a soft shadow and, over it, the clipped shape that takes
// the children. The shadow has to sit outside the clip, and being part of
// the same Item it follows the shape as it grows, moves and fades.
Item {
    id: blob

    property bool expanded: false
    property real maxRadius: Theme.u(23)
    property color color: Theme.bg
    readonly property real radius: Math.min(width / 2, height / 2, maxRadius)

    default property alias content: body.data

    // 0 → collapsed, 1 → expanded; drives cross-fades of whatever sits inside.
    // Runs on the same curve as the size so the fades track the shape.
    property real progress: expanded ? 1 : 0
    Behavior on progress {
        Anim {
            curve: blob.expanded ? "open" : "close"
            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
        }
    }

    // Fully collapsed: size changes now are hover nudges, which are quick
    // rather than the full panel morph.
    readonly property bool settled: !expanded && progress < 0.01

    // The curve the size moves on, and the switch the size follows. Both are
    // set here, in that order, when `expanded` changes — never as bindings —
    // so the size can't start moving before the curve has changed. (As
    // bindings, a closing could start on the elastic opening curve: its
    // overshoot, a share of the distance travelled, squashed a big panel
    // like the control center nearly to a dot before it bounced back.)
    // Give the shape its open size behind `sizeOpen`, not `expanded`.
    property string curve: "hover"
    property bool sizeOpen: false

    // The size the shape closes to. When set, closing springs past it and
    // back by `closeBounce`, the same few pixels for every panel: the
    // spring's overshoot is a share of the distance travelled, so left
    // unscaled a big panel would squash far past its resting size.
    property real restSize: 0
    property real restWidth: restSize
    property real restHeight: restSize
    property real closeBounce: Theme.u(8)
    property real bounceWidth: 0
    property real bounceHeight: 0

    onExpandedChanged: {
        if (!expanded) {
            bounceWidth = bounceFor(width, restWidth);
            bounceHeight = bounceFor(height, restHeight);
        }
        curve = expanded ? "open" : "close";
        sizeOpen = expanded;
        if (!expanded)
            closed.restart();
    }

    // Once the closing has run its course (a bouncing one runs on the
    // elastic curve, so as long as an opening), size changes are hover nudges.
    Timer {
        id: closed
        interval: Math.max(Theme.openDuration, Theme.closeDuration) + 40
        onTriggered: {
            if (!blob.expanded)
                blob.curve = "hover";
        }
    }

    // The collapsed face fades out over the first third; the expanded face
    // fades in over the back half. They overlap slightly, so there's never
    // an empty black shape mid-morph.
    // Closing, the face comes in earlier — fully there by progress 0.15
    // rather than at 0 — so it's showing when the shape squashes past its
    // resting size and it squashes with it (see `squash`).
    readonly property real idleOpacity: expanded ? 1 - smooth(progress / 0.35) : 1 - smooth((progress - 0.15) / 0.3)
    readonly property real contentOpacity: smooth((progress - 0.3) / 0.6)

    function smooth(x: real): real {
        const t = Math.max(0, Math.min(1, x));
        return t * t * (3 - 2 * t);
    }

    // Faint and soft: enough to lift the shape off a light wallpaper, not
    // enough to read as a border. Slightly deeper under an open panel.
    RectangularShadow {
        visible: Config.island.shadow ?? true
        anchors.fill: body
        radius: blob.radius
        offset.y: Theme.u(1.5)
        blur: Theme.u(9) + Theme.u(7) * blob.progress
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.3)
        cached: blob.settled
    }

    Rectangle {
        id: body
        anchors.fill: parent
        color: blob.color
        radius: blob.radius
        clip: true
        antialiasing: true
    }

    // The elastic curve's overshoot that swings `closeBounce` past `rest`
    // when closing from `from`; 0 when there's no rest size.
    function bounceFor(from: real, rest: real): real {
        const distance = from - rest;
        if (rest <= 0 || distance <= 0)
            return 0;
        return Math.min(1, closeBounce / (0.06 * distance));
    }

    // How far the closing bounce has squashed the shape below its resting
    // size, as a scale: 1 at rest or larger. The resting face scales by it
    // so it squashes and springs back with the shape instead of being cut
    // off by its edges. Only while closing, so hovering — which changes the
    // rest size before the shape has grown to it — doesn't shrink the face.
    readonly property real squash: curve === "close" && restWidth > 0 && restHeight > 0 ? Math.min(1, width / restWidth, height / restHeight) : 1

    // Closing with a bounce runs on the elastic curve, scaled per axis.
    readonly property bool bouncing: curve === "close" && Config.motion.bounce && (bounceWidth > 0 || bounceHeight > 0)

    Behavior on width {
        Anim {
            curve: blob.bouncing ? "open" : blob.curve
            overshoot: blob.bouncing ? blob.bounceWidth : 1
        }
    }
    Behavior on height {
        Anim {
            curve: blob.bouncing ? "open" : blob.curve
            overshoot: blob.bouncing ? blob.bounceHeight : 1
        }
    }
}
