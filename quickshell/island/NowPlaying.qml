import QtQuick
import Quickshell.Widgets
import qs.common
import qs.components
import qs.services

// Compact media control for the control-center grid.
Rectangle {
    id: root

    radius: Theme.u(20)
    color: Theme.card

    ClippingRectangle {
        id: art
        x: Theme.u(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.height - Theme.u(20), Theme.u(80))
        height: width
        radius: Theme.u(10)
        color: Theme.surface

        Icon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: Icons.music
            size: Theme.u(18)
            color: Theme.textFaint
        }
        Image {
            id: cover
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            asynchronous: true
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: Theme.u(10)
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u(2)

        Label {
            width: parent.width
            text: Media.title
            size: Theme.u(10)
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            text: Media.artist || Media.identity
            size: Theme.u(8)
            color: Theme.textDim
        }
        Row {
            spacing: Theme.u(4)
            topPadding: Theme.u(4)

            CircleButton {
                implicitWidth: Theme.u(24)
                icon: Icons.previous
                iconSize: Theme.u(11)
                onClicked: Media.previous()
            }
            CircleButton {
                implicitWidth: Theme.u(24)
                icon: Media.playing ? Icons.pause : Icons.play
                iconSize: Theme.u(11)
                idleColor: Theme.accent
                hoverColor: Qt.lighter(Theme.accent, 1.1)
                iconColor: Theme.accentInk
                onClicked: Media.togglePlaying()
            }
            CircleButton {
                implicitWidth: Theme.u(24)
                icon: Icons.next
                iconSize: Theme.u(11)
                onClicked: Media.next()
            }
        }
    }
}
