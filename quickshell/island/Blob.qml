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
    readonly property string curve: settled ? "hover" : expanded ? "open" : "close"

    // The collapsed face fades out over the first third; the expanded face
    // fades in over the back half. They overlap slightly, so there's never
    // an empty black shape mid-morph.
    readonly property real idleOpacity: 1 - smooth(progress / 0.35)
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

    Behavior on width {
        Anim {
            curve: blob.curve
        }
    }
    Behavior on height {
        Anim {
            curve: blob.curve
        }
    }
}
