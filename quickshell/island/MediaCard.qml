import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.common
import qs.components
import qs.services

// The inner card of the media panel; the island's black frame sits around it.
ClippingRectangle {
    id: root

    implicitWidth: Theme.u(289)
    implicitHeight: Theme.u(141)
    radius: Theme.u(16)
    color: "#2a322c"

    Component.onCompleted: Media.positionWatchers++
    Component.onDestruction: Media.positionWatchers--

    // Backdrop: the cover, blurred into a wash of its own colours.
    Image {
        id: backdropSource
        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 128
        sourceSize.height: 128
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        anchors.margins: -Theme.u(20)
        source: backdropSource
        visible: backdropSource.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: -0.1
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.42
    }

    // Drawn behind the art, centred on it.
    // The pulse's furthest reach past the art, and the clear space kept
    // beyond that to the card's edges and to the track info.
    readonly property real pulseExtent: pulse.gap + pulse.reach
    readonly property real clearance: Theme.u(8)

    ArtPulse {
        id: pulse
        anchors.centerIn: art
        artSize: art.width
        artRadius: art.radius
        live: Media.playing
    }

    ClippingRectangle {
        id: art
        x: root.pulseExtent + root.clearance
        y: root.pulseExtent + root.clearance
        width: Theme.u(80)
        height: width
        // Rounded square, or a full circle; the pulse follows either.
        radius: (Config.island.artShape ?? "rounded") === "circle" ? width / 2 : Theme.u(8)
        Behavior on radius { Anim { curve: "hover" } }
        color: "#1c211d"

        Icon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: Icons.music
            size: Theme.u(30)
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

    Item {
        id: info
        anchors.left: art.right
        anchors.leftMargin: root.pulseExtent + Theme.u(12)
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(12)
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            y: Theme.u(9)
            width: parent.width
            spacing: Theme.u(1)

            Label {
                width: parent.width
                text: Media.title
                size: Theme.u(13)
                font.weight: Font.DemiBold
                color: "#f2f0ee"
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                size: Theme.u(9.5)
                color: Qt.rgba(1, 1, 1, 0.6)
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: Media.album
                size: Theme.u(7.5)
                color: Qt.rgba(1, 1, 1, 0.35)
            }
            // Which player, and — with more than one — a way to switch.
            Row {
                visible: Media.identity !== ""
                spacing: Theme.u(3)

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.identity
                    size: Theme.u(7.5)
                    color: Qt.rgba(1, 1, 1, 0.35)
                }

                Rectangle {
                    visible: Media.cycleOrder.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: switchRow.implicitWidth + Theme.u(8)
                    height: Theme.u(12)
                    radius: height / 2
                    color: Qt.rgba(Media.artColor.r, Media.artColor.g, Media.artColor.b, switchMouse.containsMouse ? 0.45 : 0.2)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: switchRow
                        anchors.centerIn: parent
                        spacing: Theme.u(2)

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${Media.playerIndex + 1}/${Media.cycleOrder.length}`
                            size: Theme.u(6.5)
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.chevronRight
                            size: Theme.u(7.5)
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }
                    }

                    MouseArea {
                        id: switchMouse
                        anchors.fill: parent
                        anchors.margins: -Theme.u(3)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => Media.cycle(mouse.button === Qt.RightButton ? -1 : 1)
                        onWheel: wheel => Media.cycle(wheel.angleDelta.y > 0 ? -1 : 1)
                    }
                }
            }
        }

        // Progress
        Item {
            id: progress
            y: Theme.u(78.5)
            width: parent.width
            height: Theme.u(11)

            readonly property real fraction: Media.length > 0 ? Math.min(1, Media.position / Media.length) : 0

            WaveProgress {
                anchors.fill: parent
                fraction: progress.fraction
                playing: Media.playing
                color: Media.artColor
                Behavior on color { ColorAnimation { duration: 600 } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.u(3)
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Media.seek((mouse.x - Theme.u(3)) / progress.width)
            }
        }

        Label {
            y: Theme.u(89)
            text: Media.formatTime(Media.position)
            size: Theme.u(7)
            color: Qt.rgba(1, 1, 1, 0.4)
        }
        Label {
            anchors.right: parent.right
            y: Theme.u(89)
            text: Media.formatTime(Media.length)
            size: Theme.u(7)
            color: Qt.rgba(1, 1, 1, 0.4)
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.u(104)
            spacing: Theme.u(12)

            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.previous
                onClicked: Media.previous()
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Media.playing ? Icons.pause : Icons.play
                filled: true
                onClicked: Media.togglePlaying()
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.next
                onClicked: Media.next()
            }
        }
    }

    component MediaButton: Rectangle {
        id: button

        property string icon
        property bool filled
        signal clicked

        width: Theme.u(28)
        height: width
        radius: width / 2
        // Tinted with the cover's sampled colour, like the pulse and the
        // progress bar: faintly at rest (filled buttons only), more on hover.
        color: Qt.rgba(Media.artColor.r, Media.artColor.g, Media.artColor.b, buttonMouse.containsMouse ? 0.45 : filled ? 0.2 : 0)
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: buttonMouse.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }

        Icon {
            anchors.centerIn: parent
            text: button.icon
            size: Theme.u(12)
            color: "#f2f0ee"
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
