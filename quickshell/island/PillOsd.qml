import QtQuick
import qs.common
import qs.components
import qs.services

// Volume or brightness level, shown in the pill while it changes.
Item {
    id: root

    property string kind: "volume"   // volume | brightness

    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : kind === "keyboard" ? KeyboardLight.value : Displays.focusedBrightness
    readonly property string icon: kind === "volume" ? Audio.icon : kind === "keyboard" ? Icons.keyboard : Icons.brightness

    implicitWidth: Theme.u(214)
    implicitHeight: Theme.u(33)

    Icon {
        id: glyph
        x: Theme.u(13)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: Theme.u(11)
        color: Theme.text
    }

    Rectangle {
        id: track
        anchors.left: glyph.right
        anchors.leftMargin: Theme.u(10)
        anchors.right: percent.left
        anchors.rightMargin: Theme.u(12)
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.u(4.5)
        radius: height / 2
        color: Theme.surface

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: Theme.accent
            Behavior on width { Anim { curve: "fade"; duration: 140 } }
        }
    }

    Label {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(13)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.u(24)
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(root.value * 100)}%`
        size: Theme.u(8)
        color: Theme.textDim
    }
}
