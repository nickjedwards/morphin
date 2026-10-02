import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import qs.common
import qs.components
import qs.services

// The island: album-art bubble · clock pill · status bubble.
//
// The art bubble grows into the media card and the status bubble into the
// control center. Everything else — calendar, launcher, power menu, polkit,
// notifications, volume/brightness — grows out of the clock pill, pushing the
// two bubbles aside.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property bool isFocusedScreen: Quickshell.screens.length === 1 || IslandState.focusedScreen === screenName

    readonly property string panel: IslandState.screen === screenName ? IslandState.open : ""
    readonly property bool anyOpen: panel !== ""
    readonly property bool mediaOpen: panel === "media"
    readonly property bool ccOpen: panel === "controlcenter"
    readonly property bool needsKeyboard: panel === "launcher" || panel === "polkit" || panel === "power"

    readonly property bool barMode: Session.gameMode && Config.island.gameModeBar

    // Transient pill states, lowest priority first.
    property bool peek: false
    // Popups queue up rather than replacing each other: the one showing,
    // then the rest in the order they arrived.
    property var popupQueue: []
    readonly property Notification popup: popupQueue.length > 0 ? popupQueue[0] : null

    function nextPopup(): void {
        const shown = win.popupQueue[0] ?? null;
        win.popupQueue = win.popupQueue.slice(1).filter(n => Notifs.isLive(n));
        Notifs.finish(shown);
        if (win.popupQueue.length > 0)
            popupTimer.restart();
    }
    property string osdKind: ""

    readonly property string pillMode: {
        if (["calendar", "launcher", "power", "polkit", "wallpapers", "themes"].includes(panel))
            return panel;
        if (anyOpen)
            return "idle";
        if (osdKind === "workspaces")
            return "workspaces";
        if (osdKind !== "")
            return "osd";
        if (popup !== null)
            return "notification";
        if (peek)
            return "peek";
        return "idle";
    }

    screen: modelData
    anchors.top: true
    // Full width only for Game Mode's bar. Otherwise the window is just wide
    // enough for the widest arrangement: its render buffers cost memory by
    // area, so there's no point covering the whole top of the screen.
    anchors.left: barMode
    anchors.right: barMode
    implicitWidth: {
        const cols = Config.controlCenter.columns;
        const ccWidth = cols * 46 + (cols - 1) * 9 + 22;
        const half = Math.max(830 / 2 + 14 + 26, 73 / 2 + 14 + ccWidth, 73 / 2 + 14 + 309);
        return Math.min(modelData?.width ?? 2160, Theme.u(half * 2 + 72));
    }
    // Tall enough for the biggest panel; the mask keeps the rest click-through.
    implicitHeight: Math.min(modelData?.height ?? 1440, Math.max(Theme.u(420), (controlCenter.item?.implicitHeight ?? 0) + Theme.u(70)))
    color: "transparent"

    exclusionMode: ExclusionMode.Normal
    // Reserve exactly down to the bottom of the resting island; the space
    // between it and windows is Hyprland's gaps_out, nothing of ours.
    exclusiveZone: barMode ? stage.barHeight : stage.margin + stage.base

    WlrLayershell.namespace: Meta.name + "-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: anyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        Region { item: artBlob }
        Region { item: pill }
        Region { item: statusBlob }
        Region { item: bar }
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.anyOpen
        onCleared: {
            if (win.panel === "polkit")
                Polkit.cancel();
            IslandState.close();
        }
    }

    // ── Transient triggers ───────────────────────────────────────────
    // Startup fires a burst of volume/brightness changes; ignore those.
    property bool settled: false
    Timer {
        running: true
        interval: 2500
        onTriggered: win.settled = true
    }

    function showOsd(kind: string): void {
        if (!win.settled || !Config.system.osd || win.ccOpen || !win.isFocusedScreen)
            return;
        win.osdKind = kind;
        osdTimer.restart();
    }

    Connections {
        target: Audio
        function onVolumeTouched(): void {
            win.showOsd("volume");
        }
    }
    Connections {
        target: KeyboardLight
        function onTouched(): void {
            win.showOsd("keyboard");
        }
    }
    Connections {
        target: Displays
        function onBrightnessTouched(monitor: string): void {
            if (monitor === win.screenName)
                win.showOsd("brightness");
        }
    }
    Timer {
        id: osdTimer
        interval: win.osdKind === "workspaces" ? 1200 : 1600
        onTriggered: {
            // The workspace strip is clickable: keep it while the pointer's on it.
            if (win.osdKind === "workspaces" && pillMouse.containsMouse)
                restart();
            else
                win.osdKind = "";
        }
    }

    // The workspace strip, on the monitor whose workspace changed.
    function showWorkspaces(): void {
        if (!win.settled || Config.island.workspaces === "off" || win.anyOpen || win.barMode)
            return;
        win.osdKind = "workspaces";
        osdTimer.restart();
    }

    Connections {
        target: Workspaces
        function onSwitched(monitor: string): void {
            if (monitor === win.screenName)
                win.showWorkspaces();
        }
    }

    Connections {
        target: Notifs
        function onPopup(notification: Notification): void {
            if (!win.isFocusedScreen)
                return;
            // Ones dismissed since (an announcement replaced by a newer one)
            // drop out; if that leaves this one showing, its time starts now.
            const waiting = win.popupQueue.filter(n => Notifs.isLive(n) && n !== notification);
            win.popupQueue = waiting.concat([notification]);
            if (waiting.length === 0)
                popupTimer.restart();
        }
        // Dismissed or closed elsewhere while waiting or showing.
        function onCountChanged(): void {
            if (win.popupQueue.some(n => !Notifs.isLive(n))) {
                const wasShowing = win.popup;
                win.popupQueue = win.popupQueue.filter(n => Notifs.isLive(n));
                if (win.popup !== wasShowing && win.popup !== null)
                    popupTimer.restart();
            }
        }
    }
    Timer {
        id: popupTimer
        interval: Config.notifications.popupSeconds * 1000
        onTriggered: {
            if (pillMouse.containsMouse)
                restart();
            else
                win.nextPopup();
        }
    }

    // Hovering the clock peeks at the calendar; leaving puts it away.
    Timer {
        id: peekTimer
        interval: Config.island.hoverDelay
        onTriggered: win.peek = true
    }

    SystemClock {
        id: clock
        precision: Config.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property string timeText: {
        const fmt = (Config.clock.use24h ? "hh:mm" : "h:mm") + (Config.clock.showSeconds ? ":ss" : "") + (Config.clock.use24h ? "" : " AP");
        return Qt.formatTime(clock.date, fmt);
    }

    // A FocusScope, not a plain Item: when a panel opens, `focus` here turns
    // on, and a plain Item would take the keyboard for itself — away from the
    // picker that had just focused its own field, if that happened first.
    FocusScope {
        id: stage
        anchors.fill: parent
        focus: win.anyOpen
        Keys.onEscapePressed: {
            if (win.panel === "polkit")
                Polkit.cancel();
            IslandState.close();
        }

        readonly property real barHeight: Theme.u(24)
        readonly property real margin: win.barMode ? barHeight + Theme.u(5) : Theme.u(7)
        readonly property real base: Theme.u(26)
        readonly property bool pillWide: win.pillMode !== "idle"

        // Measured off the recording: the pill is ~2.8 bubbles wide with a
        // ~10u gap. Hovering it widens the gap so the bubbles get shoved out.
        property real gap: pillWide ? Theme.u(14) : pill.hovered ? Theme.u(12) : Theme.u(10)
        Behavior on gap {
            Anim {
                curve: pill.curve
            }
        }

        // ── Game-mode bar ────────────────────────────────────────────
        Rectangle {
            id: bar
            width: win.barMode ? parent.width : 0
            height: win.barMode ? stage.barHeight : 0
            visible: win.barMode
            color: Theme.bg

            Label {
                anchors.centerIn: parent
                text: win.timeText
                size: Theme.u(9)
                font.weight: Font.Normal
            }

            Loader {
                active: win.barMode && Config.island.workspaces !== "off"
                x: Theme.u(4)
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: PillWorkspaces {
                    monitor: win.screenName
                    implicitHeight: stage.barHeight
                }
            }

            // Where the bubbles would be, so the panels are still reachable.
            MouseArea {
                x: parent.width / 2 - Theme.u(110)
                width: Theme.u(60)
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.toggle("media", win.screenName)
            }
            MouseArea {
                x: parent.width / 2 - Theme.u(45)
                width: Theme.u(90)
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.toggle("calendar", win.screenName)
            }
            MouseArea {
                x: parent.width / 2 + Theme.u(50)
                width: Theme.u(60)
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.toggle("controlcenter", win.screenName)
            }
        }

        // ── Album art → media card ───────────────────────────────────
        Blob {
            id: artBlob

            expanded: win.mediaOpen
            width: expanded ? Theme.u(309) : stage.base
            height: expanded ? Theme.u(161) : stage.base
            x: pill.x - stage.gap - width
            y: stage.margin
            opacity: win.barMode ? Math.min(1, progress * 4) : 1
            // Hovered, a bubble swells slightly and slides out and down,
            // away from the pill.
            readonly property bool hovering: artMouse.containsMouse && !expanded && !win.barMode
            property real hoverT: hovering ? 1 : 0
            Behavior on hoverT {
                // Springs out, eases back without bouncing past rest.
                Anim {
                    curve: artBlob.hovering ? "hover" : "close"
                    duration: Theme.hoverDuration
                }
            }
            // The push down and out is held for as long as the panel is open:
            // it opens from where hovering left the bubble. Closing, it
            // shrinks and returns to rest in one motion — same curve, same
            // time as the panel's own closing.
            readonly property bool pushed: !win.barMode && (hovering || expanded)
            property real pushT: pushed ? 1 : 0
            Behavior on pushT {
                Anim {
                    curve: artBlob.pushed ? "hover" : "close"
                    duration: artBlob.pushed || artBlob.progress < 0.01 ? Theme.hoverDuration : Theme.closeDuration
                }
            }
            transform: [
                Scale {
                    origin.x: stage.base / 2
                    origin.y: stage.base / 2
                    xScale: 1 + 0.07 * artBlob.hoverT
                    yScale: xScale
                },
                Translate {
                    x: -1 * Theme.u(3.25) * artBlob.pushT
                    y: Theme.u(3.5) * artBlob.pushT
                }
            ]

            MouseArea {
                id: artMouse
                anchors.fill: parent
                enabled: !artBlob.expanded && !win.barMode
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                // Scroll over the bubble to switch between players.
                onWheel: wheel => Media.cycle(wheel.angleDelta.y > 0 ? -1 : 1)
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        Media.togglePlaying();
                    else
                        IslandState.toggle("media", win.screenName);
                }
            }

            ClippingRectangle {
                // Pinned to where the bubble was, so it doesn't drift as the card grows.
                x: artBlob.width - stage.base + Theme.u(2.5)
                y: Theme.u(2.5)
                width: stage.base - Theme.u(5)
                height: width
                radius: width / 2
                color: Theme.surface
                opacity: artBlob.idleOpacity
                visible: opacity > 0

                Icon {
                    anchors.centerIn: parent
                    visible: thumb.status !== Image.Ready || !thumb.visible
                    text: Icons.music
                    size: Theme.u(10)
                    color: Theme.textDim
                }
                Image {
                    id: thumb
                    anchors.fill: parent
                    visible: Config.island.showAlbumArt
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    asynchronous: true
                }

                // Play/pause, flashed over the cover when playback toggles.
                Rectangle {
                    id: flash

                    property bool playing: false
                    property bool shown: false

                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.55)
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { Anim { curve: flash.shown ? "fade" : "close" } }

                    Icon {
                        anchors.centerIn: parent
                        // Play's triangle sits visually left of centre.
                        anchors.horizontalCenterOffset: flash.playing ? Theme.u(0.7) : 0
                        text: flash.playing ? Icons.play : Icons.pause
                        size: Theme.u(12)
                        color: "white"
                        scale: flash.shown ? 1 : 0.6
                        Behavior on scale { Anim { curve: flash.shown ? "hover" : "close" } }
                    }

                    Timer {
                        id: flashTimer
                        interval: 900
                        onTriggered: flash.shown = false
                    }

                    Connections {
                        target: Media
                        function onPlaybackToggled(playing: bool): void {
                            if (!win.isFocusedScreen)
                                return;
                            flash.playing = playing;
                            flash.shown = true;
                            flashTimer.restart();
                        }
                    }
                }
            }

            Loader {
                active: artBlob.progress > 0
                x: artBlob.width - Theme.u(10) - width
                y: Theme.u(10)
                opacity: artBlob.contentOpacity
                sourceComponent: MediaCard {}
            }
        }

        // ── Clock pill ───────────────────────────────────────────────
        Blob {
            id: pill

            readonly property bool hovered: pillMouse.containsMouse && win.pillMode === "idle" && !win.anyOpen
            // In the peek, the part that opens the month: the week strip and
            // the weather under it, not the time above.
            readonly property real peekDaysTop: Theme.u(35)
            readonly property bool overPeekDays: win.pillMode === "peek" && pillMouse.containsMouse && pillMouse.mouseY >= peekDaysTop
            readonly property Item view: {
                switch (win.pillMode) {
                case "peek":
                    return peekView;
                case "calendar":
                    return calendarView;
                case "launcher":
                    return launcherView;
                case "power":
                    return powerView;
                case "polkit":
                    return polkitView;
                case "wallpapers":
                    return wallpaperView;
                case "themes":
                    return themeView;
                case "notification":
                    return notifView;
                case "osd":
                    return osdView;
                case "workspaces":
                    return workspacesView;
                }
                return null;
            }

            expanded: win.pillMode !== "idle"
            maxRadius: ["notification", "osd", "workspaces"].includes(win.pillMode) ? Math.min(height / 2, Theme.u(26)) : Theme.u(22)
            width: view ? view.targetWidth : hovered ? Theme.u(85) : Theme.u(73)
            height: view ? view.targetHeight : hovered ? Theme.u(30) : stage.base
            x: (stage.width - width) / 2
            // Hovered, the pill grows and drops a little, as if pressed down.
            // The drop is held while something opened from the pill is showing:
            // the week, the month, the launcher and the other panels open
            // from where hovering left the pill. Closing, the pill shrinks
            // and rises to rest in one motion — same curve, same time as its
            // own closing. Passing things — volume, a notification, the
            // workspace dots — don't dip it.
            readonly property bool panelMode: ["peek", "calendar", "launcher", "power", "polkit", "wallpapers", "themes"].includes(win.pillMode)
            readonly property bool dropped: !win.barMode && (hovered || panelMode)

            y: stage.margin + (dropped ? Theme.u(4) : 0)
            Behavior on y {
                Anim {
                    curve: pill.dropped ? "hover" : "close"
                    duration: pill.dropped || pill.progress < 0.01 ? Theme.hoverDuration : Theme.closeDuration
                }
            }
            opacity: win.barMode ? Math.min(1, progress * 4) : 1

            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: ["calendar", "launcher", "power", "polkit", "wallpapers", "themes"].includes(win.pillMode) || (win.pillMode === "peek" && !pill.overPeekDays) ? Qt.ArrowCursor : Qt.PointingHandCursor
                onContainsMouseChanged: {
                    if (containsMouse && Config.island.hoverCalendar && !win.anyOpen && !win.barMode)
                        peekTimer.restart();
                    else if (!containsMouse) {
                        peekTimer.stop();
                        win.peek = false;
                    }
                }
                // Scroll steps through workspaces, showing where you land.
                onWheel: wheel => {
                    if (!["idle", "peek", "workspaces"].includes(win.pillMode))
                        return;
                    peekTimer.stop();
                    win.peek = false;
                    Workspaces.step(win.screenName, wheel.angleDelta.y > 0 ? -1 : 1);
                }
                onClicked: {
                    switch (win.pillMode) {
                    case "notification":
                        for (const n of win.popupQueue)
                            Notifs.finish(n);
                        win.popupQueue = [];
                        IslandState.show("controlcenter", win.screenName);
                        break;
                    case "osd":
                        win.osdKind = "";
                        IslandState.show("controlcenter", win.screenName);
                        break;
                    case "peek":
                        // Only the week and the weather open the month; the
                        // time above them is just to look at.
                        if (!pill.overPeekDays)
                            break;
                        win.peek = false;
                        IslandState.toggle("calendar", win.screenName);
                        break;
                    case "idle":
                        win.peek = false;
                        IslandState.toggle("calendar", win.screenName);
                        break;
                    }
                }
            }

            // The clock grows from the pill into the peek's headline.
            Label {
                readonly property real t: peekView.t
                // Grown by scaling, not by font size: font sizes move in whole
                // pixels and step visibly. At rest it's drawn at its own size
                // so it stays crisp.
                readonly property real shown: Theme.u(10.5) + Theme.u(5) * t
                anchors.horizontalCenter: parent.horizontalCenter
                y: (pill.height - height) / 2 * (1 - t) + Theme.u(11) * t
                text: win.timeText
                size: t < 0.001 ? Theme.u(10.5) : Theme.u(15.5)
                scale: shown / size
                // Regular at rest, semi-bold as the peek's headline. With a
                // variable font the weight follows the peek continuously, so
                // it thickens as it grows and thins as it shrinks; a font
                // without a weight axis switches halfway, mid-motion, where
                // the jump is hidden.
                font.weight: t < 0.5 ? Font.Normal : Font.DemiBold
                font.variableAxes: ({ "wght": 400 + 200 * t })
                // Above the peek's hover highlight, which would otherwise
                // tint it grey.
                z: 1
                opacity: {
                    const others = Math.max(calendarView.t, launcherView.t, powerView.t, polkitView.t, notifView.t, osdView.t, wallpaperView.t, themeView.t, workspacesView.t);
                    return 1 - pill.smooth(others / 0.35);
                }
                visible: opacity > 0
            }

            PillView {
                id: peekView
                mode: "peek"
                // Taller when there's a forecast to show under the week.
                readonly property bool weather: Weather.enabled && Weather.ready
                fixedWidth: Theme.u(198)
                fixedHeight: Theme.u(88) + (weather ? Theme.u(29) : 0)
                content: Component {
                    Item {
                        implicitWidth: peekView.fixedWidth
                        implicitHeight: peekView.fixedHeight

                        // Hover hint: the week and weather are a button into the month.
                        Rectangle {
                            x: Theme.u(6)
                            y: pill.peekDaysTop
                            width: parent.width - Theme.u(12)
                            height: parent.height - y - Theme.u(6)
                            radius: Theme.u(16)
                            color: Theme.surface
                            opacity: pill.overPeekDays ? 0.55 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fastDuration } }
                        }

                        CalendarStrip {
                            id: weekStrip
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.u(41)
                            now: clock.date
                            contentBottom: peekView.weather ? weatherStrip.y - y + weatherStrip.inkBottom : -1
                        }

                        WeatherStrip {
                            id: weatherStrip
                            visible: peekView.weather
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: weekStrip.y + weekStrip.height + Theme.u(1)
                            width: weekStrip.width
                            strip: weekStrip
                            now: clock.date
                        }
                    }
                }
            }

            PillView {
                id: calendarView
                mode: "calendar"
                content: Component {
                    MonthCalendar {
                        now: clock.date
                    }
                }
            }

            PillView {
                id: launcherView
                mode: "launcher"
                content: Component {
                    Launcher {
                        onDone: IslandState.close()
                    }
                }
            }

            PillView {
                id: powerView
                mode: "power"
                content: Component {
                    PowerMenu {
                        onDone: IslandState.close()
                    }
                }
            }

            PillView {
                id: wallpaperView
                mode: "wallpapers"
                content: Component {
                    WallpaperPicker {
                        onDone: IslandState.close()
                    }
                }
            }

            PillView {
                id: themeView
                mode: "themes"
                content: Component {
                    ThemePicker {
                        onDone: IslandState.close()
                    }
                }
            }

            PillView {
                id: polkitView
                mode: "polkit"
                content: Component {
                    PolkitPrompt {}
                }
            }

            PillView {
                id: notifView
                mode: "notification"
                content: Component {
                    NotifPopup {
                        notification: win.popup
                        waiting: win.popupQueue.length - 1
                        onDone: win.nextPopup()
                    }
                }
            }

            PillView {
                id: workspacesView
                mode: "workspaces"
                content: Component {
                    PillWorkspaces {
                        monitor: win.screenName
                    }
                }
            }

            PillView {
                id: osdView
                mode: "osd"
                content: Component {
                    PillOsd {
                        kind: win.osdKind || "volume"
                    }
                }
            }
        }

        // ── Status bubble → control center ───────────────────────────
        Blob {
            id: statusBlob

            expanded: win.ccOpen
            width: expanded ? (controlCenter.item?.implicitWidth ?? stage.base) : stage.base
            height: expanded ? (controlCenter.item?.implicitHeight ?? stage.base) : stage.base
            x: pill.x + pill.width + stage.gap
            y: stage.margin
            opacity: win.barMode ? Math.min(1, progress * 4) : 1
            // Hovered, a bubble swells slightly and slides out and down,
            // away from the pill.
            readonly property bool hovering: statusMouse.containsMouse && !expanded && !win.barMode
            property real hoverT: hovering ? 1 : 0
            Behavior on hoverT {
                // Springs out, eases back without bouncing past rest.
                Anim {
                    curve: statusBlob.hovering ? "hover" : "close"
                    duration: Theme.hoverDuration
                }
            }
            // The push down and out is held for as long as the panel is open:
            // it opens from where hovering left the bubble. Closing, it
            // shrinks and returns to rest in one motion — same curve, same
            // time as the panel's own closing.
            readonly property bool pushed: !win.barMode && (hovering || expanded)
            property real pushT: pushed ? 1 : 0
            Behavior on pushT {
                Anim {
                    curve: statusBlob.pushed ? "hover" : "close"
                    duration: statusBlob.pushed || statusBlob.progress < 0.01 ? Theme.hoverDuration : Theme.closeDuration
                }
            }
            transform: [
                Scale {
                    origin.x: stage.base / 2
                    origin.y: stage.base / 2
                    xScale: 1 + 0.07 * statusBlob.hoverT
                    yScale: xScale
                },
                Translate {
                    x: 1 * Theme.u(3.25) * statusBlob.pushT
                    y: Theme.u(3.5) * statusBlob.pushT
                }
            ]

            MouseArea {
                id: statusMouse
                anchors.fill: parent
                enabled: !statusBlob.expanded && !win.barMode
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.toggle("controlcenter", win.screenName)
                onWheel: wheel => Audio.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }

            // Ring (battery or volume) around the network glyph.
            Item {
                width: stage.base
                height: stage.base
                opacity: statusBlob.idleOpacity
                visible: opacity > 0

                Shape {
                    id: ring
                    readonly property real diameter: stage.base - Theme.u(6)
                    readonly property real stroke: Math.max(1.5, Theme.u(1.3))
                    readonly property real level: Config.island.ring === "volume" ? Audio.volume : Config.island.ring === "none" ? 1 : Battery.level
                    anchors.centerIn: parent
                    width: diameter
                    height: diameter
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.15)
                        strokeWidth: ring.stroke
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: ring.diameter / 2
                            centerY: ring.diameter / 2
                            radiusX: (ring.diameter - ring.stroke) / 2
                            radiusY: radiusX
                            startAngle: -90
                            sweepAngle: 360
                        }
                    }
                    ShapePath {
                        // Red while the machine is under sustained strain (CPU pinned
                        // or memory nearly gone); otherwise the power mode shows through: green for Power Saver, the accent for
                        // Performance, plain for Balanced.
                        strokeColor: SystemStats.strained && (Config.system.loadWarning ?? true) ? Theme.red : Power.profile === PowerProfile.PowerSaver ? Theme.good : Power.profile === PowerProfile.Performance ? Theme.accent : Battery.charging && Config.island.ring === "battery" ? Theme.accent : Theme.ring
                        Behavior on strokeColor { ColorAnimation { duration: Theme.fastDuration } }
                        strokeWidth: ring.stroke
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: ring.diameter / 2
                            centerY: ring.diameter / 2
                            radiusX: (ring.diameter - ring.stroke) / 2
                            radiusY: radiusX
                            startAngle: -90
                            sweepAngle: 360 * Math.max(0, Math.min(1, ring.level))
                        }
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    text: Net.icon
                    size: Theme.u(9)
                    color: Theme.text
                }
            }

            // Only built while open (or closing): with its grid, notification
            // list and pages it's the heaviest thing in the island.
            Loader {
                id: controlCenter
                active: win.ccOpen || statusBlob.progress > 0
                opacity: statusBlob.contentOpacity
                visible: opacity > 0
                sourceComponent: ControlCenter {
                    active: win.ccOpen
                    screenName: win.screenName
                }
            }
        }
    }

    // One of the pill's faces. Loaded while visible; the pill sizes itself to
    // the face's implicit size so faces can grow (launcher results, polkit).
    component PillView: Item {
        id: view

        property string mode
        property Component content
        property real fixedWidth: 0
        property real fixedHeight: 0

        readonly property bool current: win.pillMode === mode
        readonly property real targetWidth: fixedWidth || (loader.item?.implicitWidth ?? Theme.u(66))
        readonly property real targetHeight: fixedHeight || (loader.item?.implicitHeight ?? Theme.u(26))

        property real t: current ? 1 : 0
        Behavior on t {
            Anim {
                curve: view.current ? "open" : "close"
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }

        anchors.horizontalCenter: parent.horizontalCenter
        width: targetWidth
        height: targetHeight
        opacity: pill.smooth((t - 0.3) / 0.6)
        visible: t > 0
        enabled: current

        Loader {
            id: loader
            active: view.current || view.t > 0
            focus: view.current
            sourceComponent: view.content
        }

        // Belt and braces for keyboard panels (launcher, pickers, power,
        // polkit): once this face is current and loaded, make sure it holds
        // the keyboard, whatever else changed focus in the same frame.
        readonly property bool wantsKeyboard: ["launcher", "power", "polkit", "wallpapers", "themes"].includes(mode)
        function claimFocus(): void {
            if (view.wantsKeyboard && view.current && loader.item && !loader.item.activeFocus)
                loader.item.forceActiveFocus();
        }
        onCurrentChanged: {
            if (current)
                Qt.callLater(view.claimFocus);
        }
        Connections {
            target: loader
            function onLoaded(): void {
                Qt.callLater(view.claimFocus);
            }
        }
    }
}
