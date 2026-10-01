pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.common

Singleton {
    id: root

    // "Focus": notifications are still kept, they just don't pop up.
    // Remembered across restarts.
    property bool focus: AppState.focus ?? false
    onFocusChanged: AppState.focus = focus

    readonly property var list: [...server.trackedNotifications.values].reverse()
    readonly property int count: server.trackedNotifications.values.length

    signal popup(Notification notification)

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            const silenced = root.focus || !Config.notifications.popups || (Config.notifications.silenceInGameMode && Session.gameMode);
            if (!silenced || notification.urgency === NotificationUrgency.Critical)
                root.popup(notification);
        }
    }

    function clearAll(): void {
        for (const n of [...server.trackedNotifications.values])
            n.dismiss();
    }

    function initial(notification: Notification): string {
        const name = notification?.appName || notification?.summary || "?";
        return name.charAt(0).toUpperCase();
    }
}
