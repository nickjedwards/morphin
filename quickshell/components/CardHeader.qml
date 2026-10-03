import QtQuick
import qs.common

// The top row of a control-center card: its name on the left and, on the
// right, what its page is about (the current device, monitor or mode) with a
// bare chevron. The whole row opens the page; on hover the right side
// brightens so it reads as a link.
//
// With room to spare (`tall`, in a card two cells high) it is laid out like
// a tile instead: a round icon, the name with the detail under it, and the
// chevron alone on the right.
Item {
    id: header

    property string label
    property string detail
    property color detailColor: Theme.textDim
    property bool hasPage: true
    property bool interactive: true
    property string icon
    property bool tall: false
    // Inset matching the card's slider, so text lines up with its ends.
    property real inset: Theme.u(11)

    signal opened

    readonly property bool hovered: mouse.containsMouse

    Label {
        id: title
        visible: !header.tall
        x: header.inset
        height: parent.height
        text: header.label
        size: Theme.u(9.5)
        font.weight: Font.Medium
    }

    Rectangle {
        id: dot
        visible: header.tall
        x: header.inset - Theme.u(4)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.u(29)
        height: width
        radius: width / 2
        color: header.hovered && header.hasPage ? Theme.surfaceHover : Theme.iconOff
        Behavior on color { ColorAnimation { duration: Theme.fastDuration } }

        Icon {
            anchors.centerIn: parent
            text: header.icon
            size: Theme.u(12)
        }
    }

    Column {
        visible: header.tall
        anchors.left: dot.right
        anchors.leftMargin: Theme.u(9)
        anchors.right: links.left
        anchors.rightMargin: Theme.u(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u(1)

        Label {
            width: parent.width
            text: header.label
            size: Theme.u(10.5)
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: header.detail
            size: Theme.u(8)
            color: header.hovered && header.hasPage ? Theme.text : header.detailColor
            Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
        }
    }

    Row {
        id: links
        anchors.right: parent.right
        anchors.rightMargin: header.hasPage ? header.inset - Theme.u(3) : header.inset
        height: parent.height
        spacing: Theme.u(2)

        Label {
            anchors.verticalCenter: parent.verticalCenter
            // Never crowds the title.
            width: Math.min(implicitWidth, header.width - title.implicitWidth - header.inset * 2 - Theme.u(24))
            visible: text !== "" && !header.tall
            text: header.detail
            size: Theme.u(8)
            color: header.hovered && header.hasPage ? Theme.text : header.detailColor
            Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: header.hasPage
            text: Icons.chevronRight
            size: Theme.u(10)
            color: header.hovered ? Theme.text : Theme.textFaint
            Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: header.interactive && header.hasPage
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: header.opened()
    }
}
