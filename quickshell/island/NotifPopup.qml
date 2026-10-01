import QtQuick
import Quickshell.Services.Notifications
import qs.common
import qs.components
import qs.services

// A notification borrowing the clock pill for a few seconds.
Item {
    id: root

    property Notification notification

    implicitWidth: Theme.u(347)
    implicitHeight: Theme.u(51)

    NotifAvatar {
        id: avatar
        x: Theme.u(10)
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.u(30)
        notification: root.notification
    }

    Column {
        anchors.left: avatar.right
        anchors.leftMargin: Theme.u(10)
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(18)
        anchors.verticalCenter: parent.verticalCenter

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
            size: Theme.u(8)
            color: Theme.textDim
        }
    }
}
