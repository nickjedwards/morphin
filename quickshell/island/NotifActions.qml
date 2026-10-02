import QtQuick
import Quickshell.Services.Notifications
import qs.common
import qs.components
import qs.services

// The buttons a notification offers ("Reply", "Mark as read"…), up to three.
Row {
    id: root

    property Notification notification
    readonly property var buttons: Notifs.buttons(notification).slice(0, 3)

    // Emitted after a button was pressed.
    signal invoked

    visible: buttons.length > 0
    spacing: Theme.u(4)

    Repeater {
        model: root.buttons

        delegate: PillButton {
            required property var modelData
            text: modelData.text
            size: Theme.u(8)
            implicitHeight: Theme.u(18)
            tinted: true
            onClicked: {
                modelData.invoke();
                root.invoked();
            }
        }
    }
}
