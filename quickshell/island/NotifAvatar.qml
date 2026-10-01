import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.common
import qs.components
import qs.services

// The notification's image if it sent one, otherwise its app's initial.
ClippingRectangle {
    id: root

    property Notification notification
    property real size: Theme.u(22)

    readonly property string source: {
        const n = root.notification;
        if (!n)
            return "";
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.includes("/") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    width: size
    height: size
    radius: size / 2
    color: Theme.avatar

    Label {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: Notifs.initial(root.notification)
        size: root.size * 0.42
        font.weight: Font.DemiBold
        color: Theme.avatarInk
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        asynchronous: true
    }
}
