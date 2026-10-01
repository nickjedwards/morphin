import QtQuick
import qs.common
import qs.components

// The full month: arrows either side of the title, six weeks of days.
Item {
    id: root

    property date now
    property int monthOffset: 0

    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property real cell: Theme.u(28)
    readonly property var dayLetters: {
        const letters = ["S", "M", "T", "W", "T", "F", "S"];
        const start = Config.clock.weekStart;
        return [...letters.slice(start), ...letters.slice(0, start)];
    }

    implicitWidth: cell * 7 + Theme.u(24)
    implicitHeight: Theme.u(44) + Theme.u(18) + cell * 6 + Theme.u(10)

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function dayAt(index: int): date {
        const first = root.shown;
        const lead = (first.getDay() - Config.clock.weekStart + 7) % 7;
        return new Date(first.getFullYear(), first.getMonth(), 1 - lead + index);
    }

    CircleButton {
        x: Theme.u(12)
        y: Theme.u(12)
        implicitWidth: Theme.u(22)
        icon: Icons.arrowLeft
        iconSize: Theme.u(10)
        idleColor: Theme.surface
        onClicked: root.monthOffset--
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.u(12)
        height: Theme.u(22)
        text: Qt.formatDate(root.shown, "MMMM yyyy")
        size: Theme.u(10.5)
        font.weight: Font.DemiBold

        MouseArea {
            anchors.fill: parent
            cursorShape: root.monthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.monthOffset = 0
        }
    }

    CircleButton {
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(12)
        y: Theme.u(12)
        implicitWidth: Theme.u(22)
        icon: Icons.arrowRight
        iconSize: Theme.u(10)
        idleColor: Theme.surface
        onClicked: root.monthOffset++
    }

    Row {
        x: Theme.u(12)
        y: Theme.u(44)

        Repeater {
            model: root.dayLetters
            delegate: Label {
                required property string modelData
                width: root.cell
                height: Theme.u(14)
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                size: Theme.u(8)
                font.weight: Font.Medium
                color: Theme.textDim
            }
        }
    }

    Grid {
        x: Theme.u(12)
        y: Theme.u(62)
        columns: 7

        Repeater {
            model: 42
            delegate: Item {
                id: day

                required property int index
                readonly property date date: root.dayAt(index)
                readonly property bool inMonth: date.getMonth() === root.shown.getMonth()
                readonly property bool isToday: root.sameDay(date, root.now)

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.u(22)
                    height: width
                    radius: width / 2
                    color: day.isToday ? Theme.accent : dayMouse.containsMouse ? Theme.surface : "transparent"
                }

                Label {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    size: Theme.u(9)
                    font.weight: day.isToday ? Font.DemiBold : Font.Medium
                    color: day.isToday ? Theme.accentInk : day.inMonth ? Theme.text : Theme.textFaint
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onWheel: wheel => root.monthOffset += wheel.angleDelta.y > 0 ? -1 : 1
    }
}
