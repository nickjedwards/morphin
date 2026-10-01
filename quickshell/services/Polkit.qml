pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    readonly property bool registered: agent.isRegistered
    readonly property bool active: agent.isActive
    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
    }

    function submit(password: string): void {
        root.flow?.submit(password);
    }

    function cancel(): void {
        root.flow?.cancelAuthenticationRequest();
    }
}
