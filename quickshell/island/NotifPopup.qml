import QtQuick
import Quickshell.Services.Notifications
import qs.common
import qs.components
import qs.services

// A notification borrowing the clock pill for a few seconds: who it's from,
// what it says, the buttons it offers, and how many more are waiting.
Item {
    id: root

    property Notification notification
    property int waiting: 0

    // An action was taken; move on to the next one.
    signal done

    implicitWidth: Theme.u(347)
    implicitHeight: Math.max(Theme.u(51), content.implicitHeight + Theme.u(18))

    NotifAvatar {
        id: avatar
        x: Theme.u(10)
        y: (Theme.u(51) - height) / 2
        size: Theme.u(30)
        notification: root.notification
    }

    Rectangle {
        id: more
        visible: root.waiting > 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(14)
        y: Theme.u(10)
        width: moreLabel.implicitWidth + Theme.u(10)
        height: Theme.u(14)
        radius: height / 2
        color: Theme.surface

        Label {
            id: moreLabel
            anchors.centerIn: parent
            text: `+${root.waiting}`
            size: Theme.u(7.5)
            font.weight: Font.DemiBold
            color: Theme.textDim
        }
    }

    Column {
        id: content
        anchors.left: avatar.right
        anchors.leftMargin: Theme.u(10)
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(18)
        y: actions.visible ? Theme.u(9) : (root.height - height) / 2

        Label {
            width: parent.width - (more.visible ? more.width + Theme.u(6) : 0)
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
        NotifActions {
            id: actions
            topPadding: Theme.u(5)
            notification: root.notification
            onInvoked: root.done()
        }
    }
}
