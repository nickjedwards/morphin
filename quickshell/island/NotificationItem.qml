import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.common
import qs.components
import qs.services

Rectangle {
    id: root

    property Notification notification

    implicitHeight: Math.max(Theme.u(44), content.implicitHeight + Theme.u(14))
    radius: Theme.u(14)
    color: mouse.containsMouse ? Theme.surface : Theme.cardItem
    Behavior on color { ColorAnimation { duration: 150 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Notifs.open(root.notification)
    }

    NotifAvatar {
        id: avatar
        x: Theme.u(10)
        y: Theme.u(7)
        notification: root.notification
    }

    Column {
        id: content
        anchors.left: avatar.right
        anchors.leftMargin: Theme.u(10)
        anchors.right: close.left
        anchors.rightMargin: Theme.u(6)
        y: Theme.u(6)
        spacing: Theme.u(1)

        Label {
            width: parent.width
            text: root.notification?.appName || "Notification"
            size: Theme.u(8)
            color: Theme.textDim
        }
        Label {
            width: parent.width
            text: root.notification?.summary ?? ""
            size: Theme.u(10)
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: root.notification?.body ?? ""
            size: Theme.u(8.5)
            color: Theme.textDim
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
        NotifActions {
            topPadding: Theme.u(4)
            notification: root.notification
        }
    }

    Icon {
        id: close
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(10)
        y: Theme.u(8)
        text: Icons.close
        size: Theme.u(10)
        color: closeMouse.containsMouse ? Theme.text : Theme.textDim

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            anchors.margins: -Theme.u(4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notification?.dismiss()
        }
    }
}
