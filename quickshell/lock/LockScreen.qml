import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.common
import qs.services

// Session lock with PAM ("login" service, same as hyprlock).
Scope {
    id: root

    property bool locked: false
    // Drives the fade in/out; the lock is only dropped once it reaches 0.
    property real shown: 0

    readonly property string user: Quickshell.env("USER") || "user"
    property string buffer: ""
    property bool typing: false
    property bool busy: false
    property bool failed: false
    property string message: ""

    signal rejected

    function lock(): void {
        if (root.locked)
            return;
        root.buffer = "";
        root.typing = false;
        root.failed = false;
        root.message = "";
        root.locked = true;
        root.shown = 1;
    }

    function submit(): void {
        if (root.buffer === "" || root.busy)
            return;
        root.busy = true;
        root.failed = false;
        pam.start();
    }

    Behavior on shown {
        Anim {
            curve: "close"
        }
    }
    onShownChanged: {
        if (shown === 0 && root.locked)
            root.locked = false;
    }

    Connections {
        target: Session
        function onLockRequested(): void {
            root.lock();
        }
        function onLockPreviewRequested(): void {
            root.previewing = true;
            previewTimer.restart();
        }
    }

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (responseRequired)
                respond(root.buffer);
            else if (messageIsError)
                root.message = message;
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.buffer = "";
                root.shown = 0;
            } else {
                root.buffer = "";
                root.failed = true;
                root.message = "Wrong password";
                root.rejected();
            }
        }

        onError: {
            root.busy = false;
            root.failed = true;
            root.message = "Authentication error";
            root.rejected();
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            color: "black"

            LockContent {
                anchors.fill: parent
                context: root
                opacity: root.shown
                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    // A look at the lock screen without locking anything, for tweaking it:
    // <name> ipc call lockscreen preview
    property bool previewing: false

    IpcHandler {
        target: "lockscreen"
        function preview(): void {
            root.previewing = true;
            previewTimer.restart();
        }
    }

    Timer {
        id: previewTimer
        interval: 6000
        onTriggered: root.previewing = false
    }

    LazyLoader {
        active: root.previewing

        PanelWindow {
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: Meta.name + "-lock-preview"
            color: "black"

            LockContent {
                anchors.fill: parent
                context: root
            }
        }
    }
}
