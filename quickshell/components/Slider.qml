import QtQuick
import qs.common

// A chunky pill slider. The fill sits inset inside the track, so a thin ring
// of track shows all the way round it, and its corners are concentric with
// the track's. At the fill's moving end sits a round drag handle in a
// contrasting colour, carrying the icon; at zero the fill is just the handle.
//
// While the pointer is on the slider, or it's being dragged, the icon gives
// way to the value as a number, which follows the drag; it comes back when
// the pointer leaves.
Item {
    id: slider

    property real value: 0
    property string icon
    readonly property bool dragging: mouse.pressed
    // What the round end shows in place of the icon while in use.
    property string valueText: String(Math.round(Math.max(0, Math.min(1, value)) * 100))
    // Off for sliders whose range isn't a 0–100 level (a scale, a delay, a
    // colour temperature): a bare percentage would mislead there.
    property bool valueOnHover: true
    readonly property bool showValue: valueOnHover && enabled && (mouse.containsMouse || mouse.pressed)

    // Ring of track around the fill, about a tenth of the height.
    readonly property real inset: Math.max(2, Math.round(height * 0.1))
    readonly property real inner: height - inset * 2

    signal moved(real value)

    implicitHeight: Theme.u(22)

    // Maps the pointer so the fill's round end follows it.
    function valueAt(x: real): real {
        return Math.max(0, Math.min(1, (x - inset - inner / 2) / (width - inset * 2 - inner)));
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.track
    }

    Rectangle {
        id: fill
        x: slider.inset
        y: slider.inset
        height: slider.inner
        radius: height / 2
        color: Theme.accent
        width: slider.inner + (slider.width - slider.inset * 2 - slider.inner) * Math.max(0, Math.min(1, slider.value))
        Behavior on width {
            enabled: !slider.dragging
            Anim { curve: "fade"; duration: 140 }
        }
    }

    // The drag handle: a dark circle at the moving end of the fill, with
    // light content. It sits just inside the fill's end, so a ring of the
    // fill colour outlines it — the track is as dark as the handle, and
    // without the ring it would vanish at zero, where the fill is only as
    // big as the handle. It carries the icon, which swaps with the value
    // while the slider is in use; each shrinks a little as it fades so the
    // change reads as a swap.
    Rectangle {
        id: handle
        readonly property real ring: Math.max(2, Theme.u(1.5))
        x: fill.x + fill.width - width - ring
        y: slider.inset + ring
        width: slider.inner - ring * 2
        height: width
        radius: width / 2
        color: Theme.bg

        Icon {
            anchors.fill: parent
            text: slider.icon
            size: Math.round(slider.height * 0.36)
            color: Theme.text
            opacity: slider.showValue ? 0 : 1
            scale: slider.showValue ? 0.6 : 1
            Behavior on opacity { Anim { curve: "fade" } }
            Behavior on scale { Anim { curve: "fade" } }
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: slider.valueText
            color: Theme.text
            font.family: Theme.font
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            // Three digits ("100") have to fit the same circle as two.
            font.pixelSize: Math.round(slider.height * (slider.valueText.length > 2 ? 0.27 : 0.34))
            opacity: slider.showValue ? 1 : 0
            scale: slider.showValue ? 1 : 0.6
            Behavior on opacity { Anim { curve: "fade" } }
            Behavior on scale { Anim { curve: "fade" } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => slider.moved(slider.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                slider.moved(slider.valueAt(mouse.x));
        }
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            slider.moved(Math.max(0, Math.min(1, slider.value + step)));
        }
    }
}
