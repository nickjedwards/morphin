import QtQuick
import qs.common
import qs.components
import qs.services

// Five big buttons; arrows move the selection, Enter runs it.
FocusScope {
    id: root

    signal done

    property int selected: 1

    readonly property real tileWidth: Theme.u(70)
    readonly property real tileHeight: Theme.u(62)
    readonly property real spacing: Theme.u(7)

    implicitWidth: Session.actions.length * tileWidth + (Session.actions.length - 1) * spacing + Theme.u(22)
    implicitHeight: tileHeight + Theme.u(22)

    focus: true
    Component.onCompleted: forceActiveFocus()

    function run(index: int): void {
        const action = Session.actions[index];
        root.done();
        Session.run(action.id);
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            root.selected = (root.selected + Session.actions.length - 1) % Session.actions.length;
            break;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            root.selected = (root.selected + 1) % Session.actions.length;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.run(root.selected);
            break;
        case Qt.Key_Escape:
            root.done();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Row {
        x: Theme.u(11)
        y: Theme.u(11)
        spacing: root.spacing

        Repeater {
            model: Session.actions

            delegate: Rectangle {
                id: tile

                required property var modelData
                required property int index
                readonly property bool isSelected: root.selected === index

                width: root.tileWidth
                height: root.tileHeight
                radius: Theme.u(14)
                color: isSelected ? Theme.accent : mouse.containsMouse ? Theme.accentMuted : Theme.surface
                Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
                scale: mouse.pressed ? 0.95 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.u(4)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.icon
                        size: Theme.u(14)
                        color: tile.isSelected ? Theme.accentInk : Theme.text
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        size: Theme.u(8.5)
                        font.weight: Font.DemiBold
                        color: tile.isSelected ? Theme.accentInk : Theme.text
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run(tile.index)
                }
            }
        }
    }
}
