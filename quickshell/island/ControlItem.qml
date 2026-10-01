import QtQuick
import qs.common
import qs.components
import qs.services
import Quickshell.Services.UPower

// One control-center control of any type, drawn at whatever size its grid
// cell gives it. `interactive: false` renders it inert for the editor.
Item {
    id: root

    property string type
    property bool interactive: true

    signal pageRequested(string page)

    readonly property var info: Controls.info(type)

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.type) {
            case "wifi":
            case "bluetooth":
            case "focus":
            case "gamemode":
            case "nightlight":
                return toggleComponent;
            case "lock":
            case "power":
                return actionComponent;
            case "audio":
                return audioComponent;
            case "brightness":
                return brightnessComponent;
            case "powermode":
                return root.width < Theme.u(80) ? powerTileComponent : powerCardComponent;
            case "system":
                return systemComponent;
            case "notifications":
                return notificationsComponent;
            case "nowplaying":
                return nowPlayingComponent;
            }
            return null;
        }
    }

    Component {
        id: toggleComponent

        Tile {
            interactive: root.interactive
            icon: {
                switch (root.type) {
                case "wifi":
                    return Net.icon;
                case "bluetooth":
                    return Bt.enabled ? Icons.bluetooth : Icons.bluetoothOff;
                }
                return root.info.icon;
            }
            title: root.info.label
            subtitle: {
                switch (root.type) {
                case "wifi":
                    return Net.status;
                case "bluetooth":
                    return Bt.status;
                case "focus":
                    return Notifs.focus ? "On" : "Off";
                case "gamemode":
                    return Session.gameMode ? "On" : "Off";
                case "nightlight":
                    return !NightLight.available ? "Needs hyprsunset" : NightLight.enabled ? `${NightLight.temperature} K` : "Off";
                }
                return "";
            }
            active: {
                switch (root.type) {
                case "wifi":
                    return Net.enabled;
                case "bluetooth":
                    return Bt.enabled;
                case "focus":
                    return Notifs.focus;
                case "gamemode":
                    return Session.gameMode;
                case "nightlight":
                    return NightLight.enabled;
                }
                return false;
            }
            onToggled: {
                switch (root.type) {
                case "wifi":
                    Net.toggle();
                    break;
                case "bluetooth":
                    Bt.toggle();
                    break;
                case "focus":
                    Notifs.focus = !Notifs.focus;
                    break;
                case "gamemode":
                    Session.toggleGameMode();
                    break;
                case "nightlight":
                    NightLight.toggle();
                    break;
                }
            }
            onOpened: {
                if (root.info.page)
                    root.pageRequested(root.info.page);
                else if (root.type === "nightlight")
                    root.pageRequested("display");
                else
                    toggled();
            }
        }
    }

    Component {
        id: actionComponent

        Tile {
            interactive: root.interactive
            icon: root.info.icon
            title: root.info.label
            subtitle: ""
            active: false
            onToggled: run()
            onOpened: run()

            function run(): void {
                if (root.type === "lock") {
                    IslandState.close();
                    Session.lock();
                } else {
                    IslandState.show("power", IslandState.screen);
                }
            }
        }
    }

    Component {
        id: brightnessComponent

        BrightnessCard {
            interactive: root.interactive
            onOpened: root.pageRequested("display")
        }
    }

    Component {
        id: audioComponent

        AudioCard {
            interactive: root.interactive
            onOpened: root.pageRequested("audio")
        }
    }

    Component {
        id: systemComponent

        SystemCard {
            interactive: root.interactive
            onOpened: root.pageRequested("system")
        }
    }

    Component {
        id: powerCardComponent

        PowerModeCard {
            interactive: root.interactive
            onOpened: root.pageRequested("power")
        }
    }

    // One cell: a round button showing the current mode; clicking cycles.
    Component {
        id: powerTileComponent

        Tile {
            interactive: root.interactive
            icon: Power.current.icon
            title: Power.current.label
            subtitle: ""
            active: Power.current.profile !== PowerProfile.Balanced
            onToggled: Power.cycle()
            onOpened: Power.cycle()
        }
    }

    Component {
        id: notificationsComponent

        NotificationList {
            enabled: root.interactive
            fixedHeight: root.height
        }
    }

    Component {
        id: nowPlayingComponent

        NowPlaying {
            enabled: root.interactive
        }
    }
}
