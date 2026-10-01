import QtQuick
import Quickshell
import qs.common
import qs.components

// A week-wide strip of days centred on today; scroll to walk through time.
Item {
    id: root

    property date now
    property int offset: 0

    // Scrolling is held to a 30-day span around today — two weeks back,
    // two weeks and a day ahead — with all seven visible days kept inside it.
    readonly property int daysBefore: 14
    readonly property int daysAfter: 15
    readonly property int minOffset: -(daysBefore - 3)
    readonly property int maxOffset: daysAfter - 3

    readonly property real step: Theme.u(22.5)
    // Extra room either side of the centre day, so its highlight doesn't
    // crowd the neighbours.
    readonly property real centerGap: Theme.u(4)
    readonly property var fade: [0.12, 0.45, 0.6, 1, 0.6, 0.45, 0.12]
    readonly property var letters: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var names: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    implicitWidth: step * 7 + centerGap * 2
    implicitHeight: Theme.u(34)

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    Repeater {
        model: 7

        delegate: Item {
            id: day

            required property int index
            readonly property int rel: index - 3
            readonly property date date: {
                const d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
                d.setDate(d.getDate() + root.offset + rel);
                return d;
            }
            readonly property bool isCenter: rel === 0
            readonly property bool isToday: root.sameDay(date, root.now)
            readonly property bool isWeekend: date.getDay() === 0 || date.getDay() === 6

            x: root.width / 2 + rel * root.step + Math.sign(rel) * root.centerGap - width / 2
            width: root.step
            height: root.height
            opacity: root.fade[index]

            // Today's highlight hugs the text with the same padding on every
            // side. It's sized from the ink of the two labels (their tight
            // bounding boxes), not their line boxes, which carry uneven
            // amounts of empty space above and below the glyphs — and the
            // text varies in width ("WED" against "FRI", "1" against "28").
            TextMetrics {
                id: nameInk
                font: nameLabel.font
                text: nameLabel.text
            }
            TextMetrics {
                id: numberInk
                font: numberLabel.font
                text: numberLabel.text
            }

            Rectangle {
                readonly property real pad: Theme.u(6)
                readonly property real inkLeft: Math.min(nameLabel.x + nameInk.tightBoundingRect.x, numberLabel.x + numberInk.tightBoundingRect.x)
                readonly property real inkRight: Math.max(nameLabel.x + nameInk.tightBoundingRect.x + nameInk.tightBoundingRect.width, numberLabel.x + numberInk.tightBoundingRect.x + numberInk.tightBoundingRect.width)
                readonly property real inkTop: nameLabel.y + nameLabel.baselineOffset + nameInk.tightBoundingRect.y
                readonly property real inkBottom: numberLabel.y + numberLabel.baselineOffset + numberInk.tightBoundingRect.y + numberInk.tightBoundingRect.height

                x: Math.round(inkLeft - pad)
                y: Math.round(inkTop - pad)
                width: Math.round(inkRight + pad) - x
                height: Math.round(inkBottom + pad) - y
                radius: Theme.u(8)
                color: Theme.accentSoft
                visible: day.isToday && day.isCenter
            }

            Label {
                id: nameLabel
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u(3)
                height: Theme.u(10)
                text: day.isCenter ? root.names[day.date.getDay()] : root.letters[day.date.getDay()]
                size: day.isCenter ? Theme.u(7.5) : Theme.u(7)
                font.weight: day.isCenter ? Font.Bold : Font.Medium
                color: day.isWeekend && Config.clock.highlightWeekends ? Theme.weekend : day.isCenter ? Theme.text : Theme.textDim
            }

            Label {
                id: numberLabel
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u(15)
                height: Theme.u(17)
                text: day.date.getDate()
                size: day.isCenter ? Theme.u(13) : Theme.u(10)
                font.weight: day.isCenter ? Font.DemiBold : Font.Medium
                color: day.isToday ? Theme.accent : day.isWeekend && Config.clock.highlightWeekends ? Theme.weekend : day.isCenter ? Theme.text : Theme.textDim
            }
        }
    }

    // Wheel only: clicks fall through to the pill, which opens the month.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1;
            root.offset = Math.max(root.minOffset, Math.min(root.maxOffset, root.offset + step));
        }
    }
}
