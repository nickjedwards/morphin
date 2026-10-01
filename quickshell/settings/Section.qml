import QtQuick
import qs.common
import qs.components

// A titled group of settings rows on a card.
Column {
    id: section

    property string title
    default property alias rows: card.data

    spacing: Theme.u(5)

    Label {
        x: Theme.u(2)
        visible: section.title !== ""
        text: section.title
        size: Theme.u(7.5)
        color: Theme.textDim
    }

    Rectangle {
        width: section.width
        height: card.implicitHeight + Theme.u(4)
        radius: Theme.u(12)
        color: Theme.card

        Column {
            id: card
            y: Theme.u(2)
            width: parent.width
        }
    }
}
