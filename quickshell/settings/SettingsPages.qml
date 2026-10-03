import QtQuick
import qs.common
import qs.components
import qs.services

// Every settings page, picked by SettingsState.page.
Loader {
    id: pages

    sourceComponent: {
        switch (SettingsState.page) {
        case "island":
            return islandPage;
        case "clock":
            return clockPage;
        case "appearance":
            return appearancePage;
        case "motion":
            return motionPage;
        case "launcher":
            return launcherPage;
        case "notifications":
            return notificationsPage;
        case "controlcenter":
            return controlCenterPage;
        case "lock":
            return lockPage;
        case "system":
            return systemPage;
        }
        return islandPage;
    }

    component Page: Column {
        property string icon
        property string title
        property string subtitle
        default property alias content: body.data

        width: pages.width
        spacing: Theme.u(12)

        PageHero {
            width: parent.width
            icon: parent.icon
            title: parent.title
            subtitle: parent.subtitle
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.u(12)
        }
    }

    Component {
        id: islandPage
        Page {
            icon: Icons.island
            title: "Bar & Island"
            subtitle: "How the island looks and behaves at the top of the screen."

            Section {
                width: parent.width
                title: "Size"
                SettingRow {
                    label: "Scale"
                    description: "Everything in the island, the control center and the settings grows with this."
                    kind: "slider"
                    from: 1
                    to: 2.5
                    step: 0.05
                    decimals: 2
                    suffix: "×"
                    value: Config.island.scale
                    onChanged: v => Config.island.scale = v
                }
            }
            Section {
                width: parent.width
                title: "Behaviour"
                SettingRow {
                    label: "Peek at the calendar on hover"
                    description: "Hovering the clock shows the week; clicking opens the month."
                    value: Config.island.hoverCalendar
                    onChanged: v => Config.island.hoverCalendar = v
                }
                SettingRow {
                    label: "Hover delay"
                    kind: "slider"
                    from: 0
                    to: 600
                    step: 10
                    suffix: " ms"
                    value: Config.island.hoverDelay
                    onChanged: v => Config.island.hoverDelay = v
                }
                SettingRow {
                    label: "Show album art"
                    description: "The left bubble shows the cover of what's playing."
                    value: Config.island.showAlbumArt
                    onChanged: v => Config.island.showAlbumArt = v
                }
                SettingRow {
                    label: "Album art shape"
                    description: "In the media card. The audio pulse follows the shape: a ring round a circle."
                    kind: "choice"
                    options: [
                        { label: "Rounded", value: "rounded" },
                        { label: "Circle", value: "circle" }
                    ]
                    value: Config.island.artShape
                    onChanged: v => Config.island.artShape = v
                }
                SettingRow {
                    label: "Status ring"
                    description: "What the ring around the Wi-Fi bubble tracks."
                    kind: "choice"
                    options: [
                        { label: "Battery", value: "battery" },
                        { label: "Volume", value: "volume" },
                        { label: "None", value: "none" }
                    ]
                    value: Config.island.ring
                    onChanged: v => Config.island.ring = v
                }
                SettingRow {
                    label: "Shadow"
                    description: "A faint shadow around the island's shapes."
                    value: Config.island.shadow
                    onChanged: v => Config.island.shadow = v
                }
                SettingRow {
                    label: "Workspace indicator"
                    description: "Dots in the clock pill for a moment when you switch workspace."
                    kind: "choice"
                    options: [
                        { label: "On switch", value: "switch" },
                        { label: "Off", value: "off" }
                    ]
                    value: Config.island.workspaces
                    onChanged: v => Config.island.workspaces = v
                }
                SettingRow {
                    label: "Flat bar in Game Mode"
                    description: "Game Mode turns the island into a plain full-width bar."
                    value: Config.island.gameModeBar
                    onChanged: v => Config.island.gameModeBar = v
                }
            }
        }
    }

    Component {
        id: clockPage
        Page {
            icon: Icons.clock
            title: "Clock & Date"
            subtitle: "The time in the island and the calendar under it."

            Section {
                width: parent.width
                SettingRow {
                    label: "24-hour clock"
                    value: Config.clock.use24h
                    onChanged: v => Config.clock.use24h = v
                }
                SettingRow {
                    label: "Show seconds"
                    value: Config.clock.showSeconds
                    onChanged: v => Config.clock.showSeconds = v
                }
                SettingRow {
                    label: "Week starts on"
                    kind: "choice"
                    options: [
                        { label: "Sunday", value: 0 },
                        { label: "Monday", value: 1 }
                    ]
                    value: Config.clock.weekStart
                    onChanged: v => Config.clock.weekStart = v
                }
                SettingRow {
                    label: "Highlight weekends"
                    value: Config.clock.highlightWeekends
                    onChanged: v => Config.clock.highlightWeekends = v
                }
            }
            Section {
                width: parent.width
                title: "Weather"
                SettingRow {
                    label: "Forecast under the week"
                    description: Weather.error !== "" ? Weather.error : Weather.ready ? `Showing ${Weather.place}, from Open-Meteo.` : "Under each day when you hover the clock; a week ahead."
                    value: Config.weather.enabled
                    onChanged: v => Config.weather.enabled = v
                }
                SettingRow {
                    label: "Location"
                    description: "A city name. Leave empty to use your time zone's city."
                    kind: "text"
                    value: Config.weather.location
                    onChanged: v => Config.weather.location = v
                }
                SettingRow {
                    label: "Temperature"
                    kind: "choice"
                    options: [
                        { label: "°C", value: "c" },
                        { label: "°F", value: "f" }
                    ]
                    value: Config.weather.unit
                    onChanged: v => Config.weather.unit = v
                }
            }
        }
    }

    Component {
        id: appearancePage
        Page {
            icon: Icons.palette
            title: "Appearance"
            subtitle: "Theme, wallpaper and type."

            Section {
                width: parent.width
                SettingRow {
                    label: "Theme"
                    description: `Or pick in the island: ${Meta.command} theme toggle`
                    kind: "picker"
                    options: Themes.list.map(t => ({ label: t.id, value: t.id, colors: Themes.resolve(t).colors }))
                    value: Config.appearance.theme
                    onChanged: v => Themes.apply(v)
                }
                SettingRow {
                    label: "Accent"
                    description: "The theme's own, or one you pick."
                    kind: "choice"
                    options: [
                        { label: "Theme", value: "theme" },
                        { label: "Custom", value: "custom" }
                    ]
                    value: Config.appearance.accentMode === "custom" ? "custom" : "theme"
                    onChanged: v => Config.appearance.accentMode = v
                }
                SettingRow {
                    visible: Config.appearance.accentMode === "custom"
                    label: "Custom accent"
                    kind: "color"
                    value: Config.appearance.customAccent
                    onChanged: v => Config.appearance.customAccent = v
                }
                SettingRow {
                    label: "Wallpaper folder"
                    description: "Empty uses the current wallpaper's folder. A sub-folder named after a theme is used with that theme."
                    kind: "text"
                    value: Config.appearance.wallpaperDir
                    onChanged: v => Config.appearance.wallpaperDir = v
                }
                SettingRow {
                    label: "Wallpaper transition"
                    kind: "choice"
                    options: [
                        { label: "Crossfade", value: "fade" },
                        { label: "None", value: "none" }
                    ]
                    value: Config.appearance.transition
                    onChanged: v => Config.appearance.transition = v
                }
                SettingRow {
                    label: "Font"
                    description: "Used throughout the shell."
                    kind: "picker"
                    options: Qt.fontFamilies().filter(f => !/emoji|symbols|icons|nerd font mono/i.test(f)).map(f => ({ label: f, value: f, font: f }))
                    value: Config.appearance.font
                    onChanged: v => Config.appearance.font = v
                }
            }
        }
    }

    Component {
        id: motionPage
        Page {
            icon: Icons.motion
            title: "Motion"
            subtitle: "How fast and how springy the island moves."

            Section {
                width: parent.width
                SettingRow {
                    label: "Speed"
                    kind: "slider"
                    from: 0.25
                    to: 2
                    step: 0.05
                    decimals: 2
                    suffix: "×"
                    value: Config.motion.speed
                    onChanged: v => Config.motion.speed = v
                }
                SettingRow {
                    label: "Bounce"
                    description: "Let panels overshoot a little as they open."
                    value: Config.motion.bounce
                    onChanged: v => Config.motion.bounce = v
                }
            }
        }
    }

    Component {
        id: launcherPage
        Page {
            icon: Icons.search
            title: "Launcher"
            subtitle: `${Meta.command} launcher toggle`

            Section {
                width: parent.width
                SettingRow {
                    label: "Results shown"
                    kind: "stepper"
                    from: 3
                    to: 12
                    step: 1
                    value: Config.launcher.maxResults
                    onChanged: v => Config.launcher.maxResults = v
                }
                SettingRow {
                    label: "Show descriptions"
                    value: Config.launcher.showDescriptions
                    onChanged: v => Config.launcher.showDescriptions = v
                }
                SettingRow {
                    label: "Terminal"
                    description: "For apps that run in a terminal."
                    kind: "text"
                    value: Config.launcher.terminal
                    onChanged: v => Config.launcher.terminal = v
                }
            }
            PillButton {
                text: "Forget launch history"
                onClicked: Apps.forget()
            }
        }
    }

    Component {
        id: notificationsPage
        Page {
            icon: Icons.bell
            title: "Notifications"
            subtitle: "Popups in the island and the list in the control center."

            Section {
                width: parent.width
                SettingRow {
                    label: "Show popups"
                    value: Config.notifications.popups
                    onChanged: v => Config.notifications.popups = v
                }
                SettingRow {
                    label: "Popup duration"
                    kind: "stepper"
                    from: 2
                    to: 15
                    step: 1
                    suffix: " s"
                    value: Config.notifications.popupSeconds
                    onChanged: v => Config.notifications.popupSeconds = v
                }
                SettingRow {
                    label: "Announce theme and wallpaper changes"
                    description: "A brief popup in the island; it isn't kept in the list."
                    value: Config.notifications.announceChanges
                    onChanged: v => Config.notifications.announceChanges = v
                }
                SettingRow {
                    label: "Silence in Game Mode"
                    description: "Critical notifications still come through."
                    value: Config.notifications.silenceInGameMode
                    onChanged: v => Config.notifications.silenceInGameMode = v
                }
                SettingRow {
                    label: "Focus"
                    description: "Keep notifications without popping them up."
                    value: Notifs.focus
                    onChanged: v => Notifs.focus = v
                }
            }
        }
    }

    Component {
        id: controlCenterPage
        Page {
            icon: Icons.tune
            title: "Control Center"
            subtitle: "Arrange, resize, add and remove the controls."

            LayoutEditor {
                width: parent.width
            }
        }
    }

    Component {
        id: lockPage
        Page {
            icon: Icons.lockFilled
            title: "Lock Screen"
            subtitle: `${Meta.command} lock lock`

            Section {
                width: parent.width
                SettingRow {
                    label: "Blur the wallpaper"
                    value: Config.lock.blur
                    onChanged: v => Config.lock.blur = v
                }
                SettingRow {
                    label: "Show the date"
                    value: Config.lock.showDate
                    onChanged: v => Config.lock.showDate = v
                }
                SettingRow {
                    label: "12-hour clock"
                    value: Config.lock.twelveHour
                    onChanged: v => Config.lock.twelveHour = v
                }
            }
            PillButton {
                text: "Preview"
                onClicked: Session.previewLock()
            }
        }
    }

    Component {
        id: systemPage
        Page {
            icon: Icons.cog
            title: "System"
            subtitle: "Night light, on-screen levels and session commands."

            Section {
                width: parent.width
                SettingRow {
                    label: "Night light temperature"
                    description: NightLight.available ? "Warmer is lower." : "Needs hyprsunset (pacman -S hyprsunset)."
                    kind: "slider"
                    from: 2500
                    to: 6000
                    step: 50
                    suffix: " K"
                    value: Config.system.nightLightTemp
                    onChanged: v => Config.system.nightLightTemp = v
                }
                SettingRow {
                    label: "Warn when the system is strained"
                    description: "The status ring turns red while CPU stays above 90% for ten seconds, or memory passes 90%."
                    value: Config.system.loadWarning
                    onChanged: v => Config.system.loadWarning = v
                }
                SettingRow {
                    label: "Brightness curve"
                    description: "How much finer the steps are at the dark end. 1 is linear; 4 matches brightnessctl -e4."
                    kind: "stepper"
                    from: 1
                    to: 5
                    step: 1
                    value: Config.system.brightnessCurve
                    onChanged: v => Config.system.brightnessCurve = v
                }
                SettingRow {
                    label: "Volume and brightness in the island"
                    value: Config.system.osd
                    onChanged: v => Config.system.osd = v
                }
                SettingRow {
                    label: "Log out command"
                    kind: "text"
                    value: Config.system.logoutCommand
                    onChanged: v => Config.system.logoutCommand = v
                }
            }
        }
    }
}
