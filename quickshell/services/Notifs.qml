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

    // The list grouped by app, each group newest first, groups ordered by
    // their newest notification.
    readonly property var groups: {
        const byApp = new Map();
        for (const n of root.list) {
            const app = n.appName || "Notifications";
            if (!byApp.has(app))
                byApp.set(app, []);
            byApp.get(app).push(n);
        }
        return [...byApp.entries()].map(([app, items]) => ({ app, items }));
    }

    signal popup(Notification notification)

    // Still around (not dismissed, expired or closed by its app)?
    function isLive(notification): bool {
        return notification !== null && server.trackedNotifications.values.includes(notification);
    }

    // The buttons an app offers, without the "default" action — that one is
    // what clicking the notification itself does.
    function buttons(notification): var {
        return (notification?.actions ?? []).filter(a => a.identifier !== "default" && a.text !== "");
    }

    function open(notification): void {
        const primary = (notification?.actions ?? []).find(a => a.identifier === "default");
        if (primary)
            primary.invoke();
    }

    function dismissAll(notifications): void {
        for (const n of [...notifications])
            n.dismiss();
    }

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
