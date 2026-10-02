import QtQuick
import qs.common

// A row in a detail page: round icon, name and state, and either a small
// action button or a tick on the right.
Rectangle {
    id: row

    property string icon
    property string title
    property string subtitle
    property bool highlighted: false
    property bool selected: false
    property string action: ""
    property bool actionPrimary: false
    // A second, destructive action ("Forget"), asked twice before it runs.
    property string secondary: ""
    property bool clickable: action === ""

    signal clicked
    signal actionClicked
    signal secondaryConfirmed

    implicitHeight: subtitle !== "" ? Theme.u(34) : Theme.u(28)
    radius: Theme.u(11)
    color: mouse.containsMouse ? Theme.surfaceHover : Theme.cardItem
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.clicked()
    }

    Rectangle {
        id: dot
        x: Theme.u(6)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - Theme.u(12)
        height: width
        radius: width / 2
        color: row.highlighted ? Theme.accent : Theme.surface

        Icon {
            anchors.centerIn: parent
            text: row.icon
            size: Theme.u(9)
            color: row.highlighted ? Theme.accentInk : Theme.textDim
        }
    }

    Column {
        anchors.left: dot.right
        anchors.leftMargin: Theme.u(9)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.u(8)
        anchors.verticalCenter: parent.verticalCenter

        Label {
            width: parent.width
            text: row.title
            size: Theme.u(9)
            font.weight: row.selected || row.highlighted ? Font.DemiBold : Font.Medium
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            size: Theme.u(7.5)
            color: Theme.textDim
        }
    }

    Item {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(8)
        anchors.verticalCenter: parent.verticalCenter
        width: (row.action !== "" ? actionButton.width : row.selected ? Theme.u(12) : 0) + (secondaryButton.visible ? secondaryButton.width + Theme.u(4) : 0)
        height: parent.height

        ConfirmButton {
            id: secondaryButton
            visible: row.secondary !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: row.secondary
            onConfirmed: row.secondaryConfirmed()
        }

        PillButton {
            id: actionButton
            visible: row.action !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.action
            tinted: !row.actionPrimary
            onClicked: row.actionClicked()
        }

        Icon {
            visible: row.action === "" && row.selected
            anchors.centerIn: parent
            text: Icons.check
            size: Theme.u(10)
            color: Theme.accent
        }
    }
}
