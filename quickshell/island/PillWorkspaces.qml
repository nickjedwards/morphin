import QtQuick
import qs.common
import qs.components
import qs.services

// A row of dots, one per workspace on this monitor: a capsule in the accent
// for the current one, dots in the text colour for ones with windows and in
// the dimmer grey for empty ones, and the theme's red for urgent.
//
// Switching stretches the capsule like a page indicator: its leading edge
// races to the new slot while the trailing edge lags behind, then it settles.
// The strip is only built once the switch has happened, so it starts from
// the workspace you came from (Workspaces.previous) and animates from there.
Item {
    id: root

    property string monitor
    property bool interactive: true

    readonly property var workspaces: Workspaces.forMonitor(monitor)
    readonly property int activeIndex: Math.max(0, workspaces.findIndex(w => Workspaces.isActive(w)))

    // The index the row is laid out around; follows activeIndex, but starts
    // at the previous workspace so a freshly shown strip still animates.
    property int shownIndex: activeIndex

    readonly property real dot: Theme.u(6)
    readonly property real capsule: Theme.u(18)
    readonly property real gap: Theme.u(7)
    readonly property real pad: Theme.u(14)

    readonly property int leadDuration: Math.round(Theme.hoverDuration * 0.6)
    readonly property int trailDuration: Math.round(Theme.hoverDuration * 1.3)

    // Every slot is a dot wide except the current one, which is a capsule.
    function slotX(i: int): real {
        return root.pad + i * (root.dot + root.gap) + (i > root.shownIndex ? root.capsule - root.dot : 0);
    }

    implicitWidth: pad * 2 + Math.max(1, workspaces.length) * (dot + gap) - gap + (workspaces.length > 0 ? capsule - dot : 0)
    implicitHeight: Theme.u(30)

    // ── Capsule edges ────────────────────────────────────────────────
    property bool movingRight: true
    property bool animate: false
    property real leftEdge: 0
    property real rightEdge: 0

    function placeCapsule(): void {
        const x = root.slotX(root.shownIndex);
        root.leftEdge = x;
        root.rightEdge = x + root.capsule;
    }

    function moveTo(index: int): void {
        if (index !== root.shownIndex)
            root.movingRight = index > root.shownIndex;
        root.shownIndex = index;
        root.placeCapsule();
    }

    onActiveIndexChanged: {
        if (root.animate)
            root.moveTo(root.activeIndex);
    }
    onWorkspacesChanged: {
        if (root.animate)
            root.placeCapsule();
    }

    Component.onCompleted: {
        const prevId = Workspaces.previous[root.monitor];
        const from = root.workspaces.findIndex(w => w.id === prevId);
        root.shownIndex = from >= 0 ? from : root.activeIndex;
        root.placeCapsule();
        root.animate = true;
        // Hold the old position until the pill has grown and the dots have
        // faded in, so the move is seen rather than hidden in the morph.
        if (root.shownIndex !== root.activeIndex)
            entrance.start();
    }

    Timer {
        id: entrance
        interval: Math.round(Theme.openDuration * 0.4)
        onTriggered: root.moveTo(root.activeIndex)
    }

    Behavior on leftEdge {
        enabled: root.animate
        NumberAnimation {
            duration: root.movingRight ? root.trailDuration : root.leadDuration
            easing.type: root.movingRight ? Easing.InOutCubic : Easing.OutCubic
        }
    }
    Behavior on rightEdge {
        enabled: root.animate
        NumberAnimation {
            duration: root.movingRight ? root.leadDuration : root.trailDuration
            easing.type: root.movingRight ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    Repeater {
        model: root.workspaces

        delegate: Rectangle {
            id: slot

            required property var modelData
            required property int index
            readonly property bool current: index === root.shownIndex
            readonly property bool occupied: Workspaces.isOccupied(modelData)
            readonly property bool urgent: modelData.urgent

            x: root.slotX(index)
            anchors.verticalCenter: parent.verticalCenter
            width: root.dot
            height: root.dot
            radius: height / 2
            // The current slot is drawn by the capsule.
            opacity: current ? 0 : 1
            color: urgent ? Theme.red : occupied ? Theme.text : Theme.textDim

            Behavior on x {
                enabled: root.animate
                NumberAnimation {
                    duration: root.trailDuration
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on opacity { Anim { curve: "fade" } }

            MouseArea {
                anchors.centerIn: parent
                width: root.dot + root.gap
                height: root.height
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: slot.modelData.activate()
            }
        }
    }

    Rectangle {
        visible: root.workspaces.length > 0
        x: root.leftEdge
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.dot, root.rightEdge - root.leftEdge)
        height: root.dot
        radius: height / 2
        color: root.workspaces[root.activeIndex]?.urgent ? Theme.red : Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
    }
}
