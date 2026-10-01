import QtQuick
import qs.common
import qs.services

// Power mode: a label, and a segmented pill of the three modes with the
// active one lit by a highlight that slides between them.
Rectangle {
    id: card

    property bool interactive: true

    signal opened

    // Same geometry as the slider cards, so it sits in the grid with them.
    readonly property real pad: Theme.u(5)
    readonly property real barHeight: Theme.u(22)
    readonly property bool showLabels: bar.width / Power.modes.length > Theme.u(62)

    implicitHeight: Theme.u(46)
    radius: barHeight / 2 + pad
    color: Theme.card

    CardHeader {
        y: Theme.u(4)
        width: parent.width
        height: bar.y - y
        inset: card.pad + Theme.u(6)
        label: "Power Mode"
        detail: Power.degraded ? `${Power.current.label} · limited` : Power.autoActive ? `${Power.current.label} · ${Power.autoReason}` : Power.current.label
        detailColor: Power.degraded ? Theme.danger : Theme.textDim
        interactive: card.interactive
        onOpened: card.opened()
    }

    Rectangle {
        id: bar
        x: card.pad
        y: card.height - card.pad - height
        width: parent.width - card.pad * 2
        height: card.barHeight
        radius: height / 2
        color: Theme.track

        readonly property real inset: Math.max(2, Math.round(height * 0.1))
        readonly property real segment: (width - inset * 2) / Power.modes.length

        Rectangle {
            x: bar.inset + bar.segment * Power.index
            y: bar.inset
            width: bar.segment
            height: bar.height - bar.inset * 2
            radius: height / 2
            color: Theme.accent
            Behavior on x { Anim { curve: "hover" } }
        }

        Row {
            x: bar.inset
            y: bar.inset

            Repeater {
                model: Power.modes

                delegate: Item {
                    id: seg

                    required property var modelData
                    required property int index
                    readonly property bool active: index === Power.index

                    width: bar.segment
                    height: bar.height - bar.inset * 2

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.u(4)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: seg.modelData.icon
                            size: Math.round(card.barHeight * 0.45)
                            color: seg.active ? Theme.accentInk : segMouse.containsMouse ? Theme.text : Theme.textDim
                            Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
                        }
                        Label {
                            visible: card.showLabels
                            anchors.verticalCenter: parent.verticalCenter
                            text: seg.modelData.short
                            size: Theme.u(8)
                            font.weight: Font.DemiBold
                            color: seg.active ? Theme.accentInk : segMouse.containsMouse ? Theme.text : Theme.textDim
                            Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
                        }
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        enabled: card.interactive
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Power.set(seg.modelData.profile)
                    }
                }
            }
        }
    }
}
