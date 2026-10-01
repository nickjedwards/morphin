import QtQuick
import qs.common
import qs.components
import qs.services

// The control center: the grid, and over it the detail page that grows out
// of whichever control opened it. Pages sit on the bottom of the panel; a
// page taller than the grid makes the whole panel taller.
Item {
    id: root

    property bool active: false
    property string screenName

    readonly property real pad: Theme.u(11)
    readonly property string page: active && IslandState.screen === screenName ? IslandState.page : ""

    // The page last shown, kept while it shrinks away.
    property string shownPage: ""
    property rect source: Qt.rect(0, 0, 0, 0)

    readonly property real pageHeight: pageLoader.item ? Math.min(pageLoader.item.implicitHeight, Theme.u(560)) : 0
    readonly property real contentHeight: Math.max(grid.implicitHeight, page !== "" ? pageHeight : 0)

    implicitWidth: grid.implicitWidth + pad * 2
    implicitHeight: contentHeight + pad * 2

    onPageChanged: {
        if (page !== "") {
            source = grid.sourceFor(page);
            shownPage = page;
        }
        // Scan only while someone is looking.
        Net.setScanning(page === "wifi");
        Bt.setScanning(page === "bluetooth");
        if (page !== "wifi")
            Net.pending = null;
    }

    onActiveChanged: {
        if (!active)
            IslandState.page = "";
    }

    ControlGrid {
        id: grid
        x: root.pad
        y: root.pad
        opacity: root.page !== "" ? 0.3 : 1
        enabled: root.page === ""
        Behavior on opacity { Anim { curve: "fade"; duration: Theme.openDuration } }
        onPageRequested: (page, source) => {
            root.source = source;
            IslandState.page = page;
        }
    }

    // ── Detail page ──────────────────────────────────────────────────
    Rectangle {
        id: card

        property real t: root.page !== "" ? 1 : 0
        Behavior on t {
            Anim {
                curve: root.page !== "" ? "open" : "close"
            }
        }

        readonly property rect target: Qt.rect(0, Math.max(0, root.contentHeight - root.pageHeight), grid.implicitWidth, root.pageHeight)

        function lerp(a: real, b: real): real {
            return a + (b - a) * t;
        }

        visible: t > 0.001
        x: root.pad + lerp(root.source.x, target.x)
        y: root.pad + lerp(root.source.y, target.y)
        width: lerp(root.source.width, target.width)
        height: Math.max(0, lerp(root.source.height, target.height))
        radius: Theme.u(22)
        color: Theme.card
        clip: true

        onTChanged: {
            if (t === 0)
                root.shownPage = "";
        }

        // Swallow clicks so they don't reach the dimmed grid.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Flickable {
            width: card.target.width
            height: card.height
            contentHeight: pageLoader.item?.implicitHeight ?? 0
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height + 1
            opacity: Math.max(0, Math.min(1, (card.t - 0.35) / 0.55))

            Loader {
                id: pageLoader
                width: card.target.width
                active: root.shownPage !== ""
                sourceComponent: {
                    switch (root.shownPage) {
                    case "wifi":
                        return wifiPage;
                    case "bluetooth":
                        return bluetoothPage;
                    case "audio":
                    case "sound":   // the page's old name, still accepted over IPC
                        return audioPage;
                    case "display":
                        return displayPage;
                    case "power":
                        return powerPage;
                    case "system":
                        return systemPage;
                    }
                    return null;
                }
            }
        }
    }

    Component {
        id: wifiPage
        WifiPage {}
    }
    Component {
        id: bluetoothPage
        BluetoothPage {}
    }
    Component {
        id: audioPage
        AudioPage {}
    }
    Component {
        id: displayPage
        DisplayPage {}
    }
    Component {
        id: powerPage
        PowerPage {}
    }
    Component {
        id: systemPage
        SystemPage {}
    }
}
