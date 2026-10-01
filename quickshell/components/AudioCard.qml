import QtQuick
import qs.common
import qs.services

// Audio: a header (the output device, opening the Audio page) over two
// sliders side by side — speaker volume and microphone level.
Rectangle {
    id: card

    property bool interactive: true

    signal opened

    // Same geometry as the other cards, so it sits in the grid with them.
    readonly property real pad: Theme.u(5)
    readonly property real sliderHeight: Theme.u(22)
    readonly property real half: (width - pad * 3) / 2

    implicitHeight: Theme.u(46)
    radius: sliderHeight / 2 + pad
    color: Theme.card

    CardHeader {
        y: Theme.u(4)
        width: parent.width
        height: sliders.y - y
        inset: card.pad + Theme.u(6)
        label: "Audio"
        detail: Audio.nodeName(Audio.sink)
        interactive: card.interactive
        onOpened: card.opened()
    }

    Row {
        id: sliders
        x: card.pad
        y: card.height - card.pad - card.sliderHeight
        spacing: card.pad

        Slider {
            width: card.half
            implicitHeight: card.sliderHeight
            enabled: card.interactive
            icon: Audio.icon
            value: Audio.muted ? 0 : Audio.volume
            onMoved: v => Audio.setVolume(v)
        }
        Slider {
            width: card.half
            implicitHeight: card.sliderHeight
            enabled: card.interactive && Audio.source !== null
            opacity: Audio.source !== null ? 1 : 0.4
            icon: Icons.microphone
            value: Audio.inputMuted ? 0 : Audio.inputVolume
            onMoved: v => Audio.setInputVolume(v)
        }
    }
}
