import QtQuick
import qs.common

// A read-only level in the sliders' clothes: the same track, inset fill and
// icon in the round end, with the reading at the right.
Item {
    id: meter

    property real value: 0
    property string icon
    property string text
    property color fill: Theme.accent

    readonly property real inset: Math.max(2, Math.round(height * 0.1))
    readonly property real inner: height - inset * 2
    readonly property real fillWidth: inner + (width - inset * 2 - inner) * Math.max(0, Math.min(1, value))

    implicitHeight: Theme.u(22)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.track
    }

    Rectangle {
        x: meter.inset
        y: meter.inset
        width: meter.fillWidth
        height: meter.inner
        radius: height / 2
        color: meter.fill
        Behavior on width { Anim { curve: "fade"; duration: 400 } }
        Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
    }

    Icon {
        x: meter.inset
        y: meter.inset
        width: meter.inner
        height: meter.inner
        text: meter.icon
        size: Math.round(meter.height * 0.4)
        color: Theme.accentInk
    }

    Label {
        id: reading
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(9)
        anchors.verticalCenter: parent.verticalCenter
        text: meter.text
        size: Theme.u(8)
        font.weight: Font.Medium
        // Dark on the fill once it reaches the text, dim on the bare track.
        color: meter.inset + meter.fillWidth > reading.x + reading.width / 2 ? Theme.accentInk : Theme.textDim
    }
}
