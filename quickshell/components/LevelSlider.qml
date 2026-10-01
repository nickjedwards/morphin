import QtQuick
import qs.common

// A slider with its percentage to the right.
Item {
    id: level

    property real value
    property string icon
    property bool showPercent: true

    signal moved(real value)

    implicitHeight: Theme.u(22)

    Slider {
        anchors.left: parent.left
        anchors.right: percent.left
        anchors.rightMargin: level.showPercent ? Theme.u(10) : 0
        icon: level.icon
        value: level.value
        onMoved: v => level.moved(v)
    }

    Label {
        id: percent
        visible: level.showPercent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: level.showPercent ? Theme.u(24) : 0
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(level.value * 100)}%`
        size: Theme.u(7.5)
        color: Theme.textDim
    }
}
