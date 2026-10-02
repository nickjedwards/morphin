import QtQuick
import Quickshell
import qs.common
import qs.components
import qs.services

Rectangle {
    id: root

    readonly property int headerHeight: Theme.u(30)
    property real fixedHeight: 0
    // app name → whether its group is unfolded
    property var expanded: ({})

    implicitHeight: fixedHeight > 0 ? fixedHeight : Math.max(Theme.u(155), Math.min(Theme.u(260), headerHeight + list.contentHeight + Theme.u(10)))

    radius: Theme.u(20)
    color: Theme.card

    Label {
        x: Theme.u(12)
        height: root.headerHeight
        text: "Notifications"
        size: Theme.u(8.5)
        color: Theme.textDim
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(12)
        height: root.headerHeight
        visible: Notifs.count > 0
        text: "Clear all"
        size: Theme.u(8.5)
        color: clearMouse.containsMouse ? Theme.text : Theme.textDim

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            anchors.margins: -Theme.u(4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.clearAll()
        }
    }

    Label {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.headerHeight / 2
        visible: Notifs.count === 0
        text: "No notifications"
        size: Theme.u(8.5)
        color: Theme.textFaint
    }

    ListView {
        id: list
        x: Theme.u(8)
        y: root.headerHeight
        width: parent.width - Theme.u(16)
        height: parent.height - y - Theme.u(8)
        clip: true
        spacing: Theme.u(5)
        boundsBehavior: Flickable.StopAtBounds

        model: Notifs.groups

        // One app's notifications: the newest, and — when there are more —
        // a line to unfold the rest or clear them all.
        delegate: Column {
            id: group

            required property var modelData
            readonly property bool expanded: root.expanded[modelData.app] === true
            readonly property int extra: modelData.items.length - 1

            width: list.width
            spacing: Theme.u(3)

            Repeater {
                model: group.expanded ? group.modelData.items : group.modelData.items.slice(0, 1)

                delegate: NotificationItem {
                    required property var modelData
                    width: group.width
                    notification: modelData
                }
            }

            Item {
                visible: group.extra > 0
                width: parent.width
                height: Theme.u(18)

                Label {
                    x: Theme.u(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.expanded ? "Show less" : `${group.extra} more from ${group.modelData.app}`
                    size: Theme.u(8)
                    color: moreMouse.containsMouse ? Theme.text : Theme.textDim

                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        anchors.margins: -Theme.u(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const next = Object.assign({}, root.expanded);
                            next[group.modelData.app] = !group.expanded;
                            root.expanded = next;
                        }
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear"
                    size: Theme.u(8)
                    color: groupClearMouse.containsMouse ? Theme.text : Theme.textDim

                    MouseArea {
                        id: groupClearMouse
                        anchors.fill: parent
                        anchors.margins: -Theme.u(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismissAll(group.modelData.items)
                    }
                }
            }
        }
    }
}
