import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// The wallpaper crossfade for one screen.
//
// With hyprpaper running, hyprpaper draws the wallpaper and this holds no
// window at all: a change opens a window showing the old image over the new,
// fades the old one away, and closes again. A full-screen window costs
// ~100 MB of render buffers, so it only exists for the second it's needed.
// Without hyprpaper the window stays up and draws the wallpaper itself.
Scope {
    id: root

    required property ShellScreen modelData

    readonly property bool persistent: !Wallpaper.hyprpaper
    property bool fading: false
    property string fromSource: ""

    Connections {
        target: Wallpaper
        function onChanged(from: string, to: string): void {
            if (Config.appearance.transition === "none" || !from) {
                root.fromSource = "";
                root.fading = false;
                return;
            }
            root.fromSource = "file://" + from;
            root.fading = true;
        }
    }

    LazyLoader {
        active: root.persistent || root.fading

        PanelWindow {
            id: win

            screen: root.modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: Meta.name + "-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // The new wallpaper underneath (only needed without hyprpaper,
            // which is drawing it already), the old one on top, fading.
            Image {
                id: next
                anchors.fill: parent
                visible: root.persistent
                source: root.persistent ? Wallpaper.source : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: win.width
                sourceSize.height: win.height
            }

            Image {
                id: previous
                anchors.fill: parent
                source: root.fromSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: win.width
                sourceSize.height: win.height
                opacity: 1

                // Start once the old image is up (and, drawing it ourselves,
                // the new one), giving hyprpaper a moment to switch below.
                readonly property bool ready: status === Image.Ready && (!root.persistent || next.status === Image.Ready)
                onReadyChanged: {
                    if (ready)
                        startTimer.restart();
                }
            }

            Timer {
                id: startTimer
                interval: root.persistent ? 0 : 250
                onTriggered: fade.restart()
            }

            NumberAnimation {
                id: fade
                target: previous
                property: "opacity"
                from: 1
                to: 0
                duration: Math.round(700 / Theme.speed)
                easing.type: Easing.InOutQuad
                onFinished: {
                    root.fromSource = "";
                    root.fading = false;
                }
            }
        }
    }
}
