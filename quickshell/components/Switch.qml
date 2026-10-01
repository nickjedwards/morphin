import QtQuick
import qs.common

// Pill toggle: accent track with a dark knob on the right when on.
Rectangle {
    id: sw

    property bool checked
    signal toggled

    implicitWidth: Theme.u(34)
    implicitHeight: Theme.u(20)
    radius: height / 2
    color: checked ? Theme.accent : Theme.iconOff
    Behavior on color { ColorAnimation { duration: Theme.fastDuration } }

    Rectangle {
        width: parent.height - Theme.u(5)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? parent.width - width - Theme.u(2.5) : Theme.u(2.5)
        color: sw.checked ? Theme.accentInk : Theme.textDim
        Behavior on x { Anim { curve: "fade" } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
