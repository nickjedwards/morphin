import QtQuick
import qs.common
import qs.components
import qs.services

// The weather for the days in the calendar strip above: an icon and one
// temperature under each, in the same columns, fading the same way and
// scrolling with it. Today shows what it is now; other days their high.
// The forecast reaches a week ahead — days past that show nothing.
Item {
    id: root

    // The CalendarStrip this sits under: its geometry and scroll position.
    required property Item strip
    property date now

    height: Theme.u(25)
    // Where the temperature's digits end, for the highlight above to reach.
    readonly property real inkBottom: Theme.u(23)

    function key(d: date): string {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    Repeater {
        model: 7

        delegate: Item {
            id: day

            required property int index
            readonly property int rel: index - 3
            readonly property int ahead: root.strip.offset + rel       // days from today
            readonly property date date: {
                const d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
                d.setDate(d.getDate() + ahead);
                return d;
            }
            readonly property var weather: Weather.byDate[root.key(date)] ?? null
            readonly property bool isToday: ahead === 0

            x: root.width / 2 + rel * root.strip.step + Math.sign(rel) * root.strip.centerGap - width / 2
            width: root.strip.step
            height: root.height
            opacity: root.strip.fade[index]
            visible: weather !== null

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.u(13)
                text: day.weather ? Weather.icon(day.weather.code) : ""
                size: Theme.u(11.5)
                color: day.isToday ? Theme.accent : rel === 0 ? Theme.text : Theme.textDim
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u(15)
                text: day.weather ? `${Math.round(day.isToday && !isNaN(Weather.current) ? Weather.current : day.weather.max)}°` : ""
                size: Theme.u(8)
                font.weight: rel === 0 ? Font.DemiBold : Font.Medium
                color: day.isToday || rel === 0 ? Theme.text : Theme.textDim
            }
        }
    }

    // Wheel only, like the strip: scrolling here moves both.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => root.strip.scroll(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
    }
}
