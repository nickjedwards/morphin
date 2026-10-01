import QtQuick
import Quickshell
import qs.common
import qs.components
import qs.services

Rectangle {
    id: root

    readonly property int headerHeight: Theme.u(30)
    property real fixedHeight: 0

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

        model: ScriptModel {
            values: Notifs.list
        }

        delegate: NotificationItem {
            required property var modelData
            width: list.width
            notification: modelData
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        displaced: Transition {
            Anim { property: "y"; curve: "fade"; duration: 260 }
        }
    }
}
