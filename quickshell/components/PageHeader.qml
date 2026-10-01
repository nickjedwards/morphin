import QtQuick
import qs.common

// Back button, title, and an optional on/off switch on the right.
Item {
    id: header

    property string title
    property bool hasSwitch: false
    property bool checked: false

    signal back
    signal toggled

    implicitHeight: Theme.u(36)

    CircleButton {
        id: backButton
        x: Theme.u(2)
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Theme.u(20)
        icon: Icons.chevronLeft
        iconSize: Theme.u(10)
        iconColor: Theme.textDim
        onClicked: header.back()
    }

    Label {
        anchors.left: backButton.right
        anchors.leftMargin: Theme.u(8)
        anchors.verticalCenter: parent.verticalCenter
        text: header.title
        size: Theme.u(12)
        font.weight: Font.Medium
    }

    Switch {
        visible: header.hasSwitch
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(2)
        anchors.verticalCenter: parent.verticalCenter
        checked: header.checked
        onToggled: header.toggled()
    }
}
