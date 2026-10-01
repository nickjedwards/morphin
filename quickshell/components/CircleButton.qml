import QtQuick
import qs.common

Rectangle {
    id: button

    property string icon
    property real iconSize: Theme.u(12)
    property color idleColor: Theme.surface
    property color hoverColor: Theme.surfaceHover
    property color iconColor: Theme.text

    signal clicked

    implicitWidth: Theme.u(46)
    implicitHeight: implicitWidth
    radius: width / 2
    color: mouse.containsMouse ? hoverColor : idleColor
    Behavior on color { ColorAnimation { duration: 150 } }

    Icon {
        anchors.centerIn: parent
        text: button.icon
        size: button.iconSize
        color: button.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
