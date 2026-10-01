import QtQuick
import qs.common
import qs.components

// The card at the top of each settings page: icon, title, one line.
Rectangle {
    id: hero

    property string icon
    property string title
    property string subtitle

    implicitHeight: Theme.u(82)
    radius: Theme.u(12)
    color: Theme.card

    Column {
        anchors.centerIn: parent
        spacing: Theme.u(4)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.u(26)
            height: width
            radius: width / 2
            color: Theme.accentSoft

            Icon {
                anchors.centerIn: parent
                text: hero.icon
                size: Theme.u(12)
                color: Theme.accent
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: hero.title
            size: Theme.u(11)
            font.weight: Font.DemiBold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: hero.subtitle
            size: Theme.u(7.5)
            color: Theme.textDim
        }
    }
}
