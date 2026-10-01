import QtQuick
import qs.common

// A control-center toggle. Wide: round icon on the left, title and state
// beside it — the icon toggles, the rest opens details when there are any.
// One cell wide: just the round button, filled with the accent when on.
Rectangle {
    id: tile

    property string icon
    property string title
    property string subtitle
    property bool active
    property bool compact: width < Theme.u(80)
    property bool interactive: true

    signal toggled
    signal opened

    implicitHeight: Theme.u(46)
    radius: height / 2
    color: compact ? (active ? Theme.accent : bodyMouse.containsMouse ? Theme.surfaceHover : Theme.surface) : bodyMouse.containsMouse ? Theme.surfaceHover : Theme.surface
    Behavior on color { ColorAnimation { duration: 150 } }

    MouseArea {
        id: bodyMouse
        anchors.fill: parent
        enabled: tile.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.compact ? tile.toggled() : tile.opened()
    }

    Rectangle {
        id: dot
        visible: !tile.compact
        x: Theme.u(7)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.u(31)
        height: width
        radius: width / 2
        color: tile.active ? (dotMouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : dotMouse.containsMouse ? Theme.surfaceHover : Theme.iconOff
        Behavior on color { ColorAnimation { duration: 200 } }

        MouseArea {
            id: dotMouse
            anchors.fill: parent
            enabled: tile.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
    }

    Icon {
        anchors.centerIn: tile.compact ? parent : dot
        text: tile.icon
        size: Theme.u(12)
        color: tile.active ? Theme.accentInk : Theme.text
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Column {
        visible: !tile.compact
        anchors.left: dot.right
        anchors.leftMargin: Theme.u(9)
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u(1)

        Label {
            width: parent.width
            text: tile.title
            size: Theme.u(10.5)
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: tile.subtitle
            size: Theme.u(8)
            color: Theme.textDim
        }
    }
}
