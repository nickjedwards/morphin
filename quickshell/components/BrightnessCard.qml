import QtQuick
import qs.common
import qs.services

// Brightness: a header (the focused monitor, opening the Display page) over
// the sliders this machine actually has — the focused screen's brightness
// and the keyboard backlight. Two cells tall, they stack, each the full
// width; one cell tall, they sit side by side, or one has the full width.
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
    readonly property bool stacked: height > Theme.u(70)
    readonly property real sliderWidth: count === 2 && !stacked ? (width - pad * 3) / 2 : width - pad * 2

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
        icon: Icons.monitor
        tall: card.stacked
        interactive: card.interactive
        onOpened: card.opened()
    }

    Grid {
        id: sliders
        x: card.pad
        y: card.height - card.pad - Math.max(height, card.sliderHeight)
        columns: card.stacked ? 1 : 2
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
        y: card.height - card.pad - height
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
