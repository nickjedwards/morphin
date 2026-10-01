import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services

// CPU and memory at a glance. Wide: a header (opening the System page) over
// two meters side by side. One cell: two concentric rings — CPU outside,
// memory inside. Either turns the theme's red while under strain.
Rectangle {
    id: card

    property bool interactive: true
    readonly property bool compact: width < Theme.u(80)

    signal opened

    readonly property real pad: Theme.u(5)
    readonly property real barHeight: Theme.u(22)
    readonly property color cpuColor: SystemStats.cpuStrained ? Theme.red : Theme.accent
    readonly property color memColor: SystemStats.memStrained ? Theme.red : Theme.accent

    implicitHeight: Theme.u(46)
    radius: compact ? height / 2 : barHeight / 2 + pad
    color: compact && compactMouse.containsMouse ? Theme.surfaceHover : compact ? Theme.surface : Theme.card
    Behavior on color { ColorAnimation { duration: 150 } }

    // Only reads the numbers every second while it's on screen.
    Component.onCompleted: SystemStats.watchers++
    Component.onDestruction: SystemStats.watchers--

    // One ring of the compact face.
    component Ring: Shape {
        id: ring
        property real diameter
        property real value
        property color color

        anchors.centerIn: parent
        width: diameter
        height: diameter
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.iconOff
            strokeWidth: rings.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.diameter / 2
                centerY: ring.diameter / 2
                radiusX: (ring.diameter - rings.stroke) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.color
            strokeWidth: rings.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.diameter / 2
                centerY: ring.diameter / 2
                radiusX: (ring.diameter - rings.stroke) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * Math.max(0.001, Math.min(1, ring.value))
                Behavior on sweepAngle { Anim { curve: "fade"; duration: 400 } }
            }
        }
    }

    // ── Wide ─────────────────────────────────────────────────────────
    CardHeader {
        visible: !card.compact
        y: Theme.u(4)
        width: parent.width
        height: meters.y - y
        inset: card.pad + Theme.u(6)
        label: "System"
        detail: SystemStats.temperature > 0 ? `${Math.round(SystemStats.temperature)}°C` : ""
        interactive: card.interactive
        onOpened: card.opened()
    }

    Row {
        id: meters
        visible: !card.compact
        x: card.pad
        y: card.height - card.pad - card.barHeight
        spacing: card.pad

        Meter {
            width: (card.width - card.pad * 3) / 2
            implicitHeight: card.barHeight
            icon: Icons.chip
            value: SystemStats.cpu
            fill: card.cpuColor
            text: `CPU ${Math.round(SystemStats.cpu * 100)}%`
        }
        Meter {
            width: (card.width - card.pad * 3) / 2
            implicitHeight: card.barHeight
            icon: Icons.memory
            value: SystemStats.mem
            fill: card.memColor
            text: `${SystemStats.gib(SystemStats.memUsed)} / ${SystemStats.gib(SystemStats.memTotal)} GB`
        }
    }

    // ── One cell ─────────────────────────────────────────────────────
    Item {
        id: rings
        visible: card.compact
        anchors.centerIn: parent
        width: Theme.u(30)
        height: width

        readonly property real stroke: Theme.u(2.6)

        Ring {
            diameter: rings.width
            value: SystemStats.cpu
            color: card.cpuColor
        }
        Ring {
            diameter: rings.width - rings.stroke * 2 - Theme.u(3)
            value: SystemStats.mem
            color: card.memColor
        }
    }

    MouseArea {
        id: compactMouse
        anchors.fill: parent
        visible: card.compact
        enabled: card.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.opened()
    }
}
