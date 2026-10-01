import QtQuick
import qs.common

// Small rounded text button: "Disconnect", "Pair", "Authenticate"…
Rectangle {
    id: button

    property string text
    property bool primary: false
    property bool tinted: false
    property real size: Theme.u(8.5)

    signal clicked

    implicitWidth: label.implicitWidth + Theme.u(18)
    implicitHeight: Theme.u(20)
    radius: height / 2
    color: primary ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : tinted ? (mouse.containsMouse ? Theme.accentMuted : Theme.accentSoft) : (mouse.containsMouse ? Theme.surfaceHover : Theme.surface)
    Behavior on color { ColorAnimation { duration: 150 } }
    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 100 } }

    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
        size: button.size
        font.weight: Font.DemiBold
        color: button.primary ? Theme.accentInk : button.tinted ? Theme.accent : Theme.text
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
