import QtQuick
import qs.common
import qs.services

// Brightness: a header (the focused monitor, opening the Display page) over
// the sliders this machine actually has — the focused screen's brightness
// and the keyboard backlight, side by side, or one at full width.
Rectangle {
    id: card

    property bool interactive: true

    signal opened

    // Same geometry as the other cards, so it sits in the grid with them.
    readonly property real pad: Theme.u(5)
    readonly property real sliderHeight: Theme.u(22)

    readonly property bool hasScreen: Displays.focusedHasBrightness
    readonly property bool hasKeyboard: KeyboardLight.available
    readonly property int count: (hasScreen ? 1 : 0) + (hasKeyboard ? 1 : 0)
    readonly property real sliderWidth: count === 2 ? (width - pad * 3) / 2 : width - pad * 2

    implicitHeight: Theme.u(46)
    radius: sliderHeight / 2 + pad
    color: Theme.card

    CardHeader {
        y: Theme.u(4)
        width: parent.width
        height: sliders.y - y
        inset: card.pad + Theme.u(6)
        label: "Display"
        detail: Displays.focused?.name ?? ""
        interactive: card.interactive
        onOpened: card.opened()
    }

    Row {
        id: sliders
        x: card.pad
        y: card.height - card.pad - card.sliderHeight
        spacing: card.pad

        Slider {
            visible: card.hasScreen
            width: card.sliderWidth
            implicitHeight: card.sliderHeight
            enabled: card.interactive
            icon: Icons.brightness
            value: Displays.focusedBrightness
            onMoved: v => Displays.setBrightness(Displays.focused?.name ?? "", v)
        }
        Slider {
            visible: card.hasKeyboard
            width: card.sliderWidth
            implicitHeight: card.sliderHeight
            enabled: card.interactive
            icon: Icons.keyboard
            value: KeyboardLight.value
            onMoved: v => KeyboardLight.set(v)
        }
    }

    // Neither a controllable screen nor a keyboard backlight.
    Rectangle {
        visible: card.count === 0
        x: card.pad
        y: sliders.y
        width: parent.width - card.pad * 2
        height: card.sliderHeight
        radius: height / 2
        color: Theme.track

        Label {
            anchors.centerIn: parent
            text: "No brightness controls here"
            size: Theme.u(8)
            color: Theme.textFaint
        }
    }
}
