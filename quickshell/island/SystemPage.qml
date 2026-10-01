import QtQuick
import qs.common
import qs.components
import qs.services

// System: the last minute of CPU use and each core, where the memory has
// gone, and what's using the most right now.
Item {
    id: root

    implicitHeight: column.implicitHeight + Theme.u(20)

    Component.onCompleted: SystemStats.detailWatchers++
    Component.onDestruction: SystemStats.detailWatchers--

    readonly property color cpuColor: SystemStats.cpuStrained ? Theme.red : Theme.accent
    readonly property color memColor: SystemStats.memStrained ? Theme.red : Theme.accent

    Column {
        id: column
        x: Theme.u(10)
        y: Theme.u(8)
        width: parent.width - Theme.u(20)
        spacing: Theme.u(4)

        PageHeader {
            width: parent.width
            title: "System"
            onBack: IslandState.page = ""
        }

        // ── Processor ────────────────────────────────────────────────
        SectionLabel {
            width: parent.width
            text: "Processor"
        }

        Rectangle {
            width: parent.width
            height: cpuColumn.implicitHeight + Theme.u(16)
            radius: Theme.u(14)
            color: Theme.cardItem

            Column {
                id: cpuColumn
                x: Theme.u(10)
                y: Theme.u(8)
                width: parent.width - Theme.u(20)
                spacing: Theme.u(8)

                Item {
                    width: parent.width
                    height: Theme.u(26)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(SystemStats.cpu * 100)}%`
                        size: Theme.u(20)
                        font.weight: Font.DemiBold
                        color: SystemStats.cpuStrained ? Theme.red : Theme.text
                    }
                    Column {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            anchors.right: parent.right
                            visible: SystemStats.temperature > 0
                            text: `${Math.round(SystemStats.temperature)}°C`
                            size: Theme.u(9.5)
                            font.weight: Font.Medium
                        }
                        Label {
                            anchors.right: parent.right
                            text: `${SystemStats.cores.length} threads`
                            size: Theme.u(7.5)
                            color: Theme.textDim
                        }
                    }
                }

                // The last minute, newest at the right.
                Canvas {
                    id: graph
                    width: parent.width
                    height: Theme.u(40)

                    readonly property var samples: SystemStats.history
                    readonly property color stroke: root.cpuColor
                    onSamplesChanged: requestPaint()
                    onStrokeChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const n = SystemStats.historyLength;
                        const data = graph.samples;
                        const step = width / (n - 1);
                        const inset = Math.max(1, Theme.u(1));
                        const yOf = v => height - inset - v * (height - inset * 2);

                        // Faint guides at 50% and 100%.
                        ctx.strokeStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07);
                        ctx.lineWidth = 1;
                        for (const g of [0.5, 1]) {
                            ctx.beginPath();
                            ctx.moveTo(0, Math.round(yOf(g)) + 0.5);
                            ctx.lineTo(width, Math.round(yOf(g)) + 0.5);
                            ctx.stroke();
                        }
                        if (data.length < 2)
                            return;

                        const x0 = width - (data.length - 1) * step;
                        ctx.beginPath();
                        ctx.moveTo(x0, yOf(data[0]));
                        for (let i = 1; i < data.length; i++)
                            ctx.lineTo(x0 + i * step, yOf(data[i]));
                        ctx.lineWidth = Math.max(1.5, Theme.u(1.4));
                        ctx.lineJoin = "round";
                        ctx.strokeStyle = graph.stroke;
                        ctx.stroke();

                        ctx.lineTo(width, height);
                        ctx.lineTo(x0, height);
                        ctx.closePath();
                        ctx.fillStyle = Qt.rgba(graph.stroke.r, graph.stroke.g, graph.stroke.b, 0.14);
                        ctx.fill();
                    }
                }

                // One bar per thread.
                Row {
                    id: coreRow
                    width: parent.width
                    height: Theme.u(22)
                    spacing: Theme.u(3)

                    Repeater {
                        model: SystemStats.cores

                        delegate: Rectangle {
                            required property real modelData
                            width: (coreRow.width - coreRow.spacing * (SystemStats.cores.length - 1)) / Math.max(1, SystemStats.cores.length)
                            height: coreRow.height
                            radius: Math.min(width / 2, Theme.u(3))
                            color: Theme.track

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(parent.radius * 2, parent.height * parent.modelData)
                                radius: parent.radius
                                color: parent.modelData >= SystemStats.cpuLimit ? Theme.red : Theme.accent
                                opacity: 0.35 + 0.65 * parent.modelData
                                Behavior on height { Anim { curve: "fade"; duration: 400 } }
                            }
                        }
                    }
                }
            }
        }

        // ── Memory ───────────────────────────────────────────────────
        SectionLabel {
            width: parent.width
            text: "Memory"
        }

        Rectangle {
            width: parent.width
            height: memColumn.implicitHeight + Theme.u(16)
            radius: Theme.u(14)
            color: Theme.cardItem

            Column {
                id: memColumn
                x: Theme.u(10)
                y: Theme.u(8)
                width: parent.width - Theme.u(20)
                spacing: Theme.u(8)

                Item {
                    width: parent.width
                    height: Theme.u(26)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(SystemStats.mem * 100)}%`
                        size: Theme.u(20)
                        font.weight: Font.DemiBold
                        color: SystemStats.memStrained ? Theme.red : Theme.text
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${SystemStats.gib(SystemStats.memUsed)} of ${SystemStats.gib(SystemStats.memTotal)} GB`
                        size: Theme.u(9.5)
                        font.weight: Font.Medium
                    }
                }

                // Used, then cache (which is given back when apps need it).
                Rectangle {
                    id: memBar
                    width: parent.width
                    height: Theme.u(6)
                    radius: height / 2
                    color: Theme.track

                    readonly property real cachedShare: SystemStats.memTotal > 0 ? Math.min(1 - SystemStats.mem, SystemStats.memCached / SystemStats.memTotal) : 0

                    Rectangle {
                        width: parent.width * Math.min(1, SystemStats.mem + memBar.cachedShare)
                        height: parent.height
                        radius: height / 2
                        color: Qt.rgba(root.memColor.r, root.memColor.g, root.memColor.b, 0.3)
                    }
                    Rectangle {
                        width: parent.width * SystemStats.mem
                        height: parent.height
                        radius: height / 2
                        color: root.memColor
                        Behavior on width { Anim { curve: "fade"; duration: 400 } }
                    }
                }

                Row {
                    width: parent.width

                    Repeater {
                        model: [
                            { label: "In use", value: `${SystemStats.gib(SystemStats.memUsed)} GB` },
                            { label: "Cache", value: `${SystemStats.gib(SystemStats.memCached)} GB` },
                            { label: "Free", value: `${SystemStats.gib(Math.max(0, SystemStats.memTotal - SystemStats.memUsed))} GB` },
                            { label: "Swap", value: SystemStats.swapTotal > 0 ? `${SystemStats.gib(SystemStats.swapUsed)} / ${SystemStats.gib(SystemStats.swapTotal)} GB` : "None" }
                        ]
                        delegate: Column {
                            required property var modelData
                            width: memColumn.width / 4

                            Label {
                                text: parent.modelData.value
                                size: Theme.u(9.5)
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: parent.modelData.label
                                size: Theme.u(7.5)
                                color: Theme.textDim
                            }
                        }
                    }
                }
            }
        }

        // ── Processes ────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Theme.u(24)

            Label {
                x: Theme.u(2)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.u(3)
                text: "Using the most"
                size: Theme.u(7.5)
                color: Theme.textDim
            }
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.u(4)

                PillButton {
                    text: "CPU"
                    size: Theme.u(7.5)
                    implicitHeight: Theme.u(18)
                    primary: SystemStats.sortBy === "cpu"
                    onClicked: SystemStats.sortBy = "cpu"
                }
                PillButton {
                    text: "Memory"
                    size: Theme.u(7.5)
                    implicitHeight: Theme.u(18)
                    primary: SystemStats.sortBy === "mem"
                    onClicked: SystemStats.sortBy = "mem"
                }
            }
        }

        Label {
            visible: SystemStats.processes.length === 0
            width: parent.width
            // The height of the five rows that replace it, so the panel
            // doesn't jump when the first sample arrives.
            height: 5 * Theme.u(24) + 4 * column.spacing
            horizontalAlignment: Text.AlignHCenter
            text: "Sampling…"
            size: Theme.u(8)
            color: Theme.textFaint
        }

        Repeater {
            model: SystemStats.processes

            delegate: Rectangle {
                id: proc

                required property var modelData

                width: column.width
                height: Theme.u(24)
                radius: Theme.u(9)
                color: Theme.cardItem

                Label {
                    x: Theme.u(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.u(120)
                    text: proc.modelData.name
                    size: Theme.u(9)
                    font.weight: Font.Medium
                }
                Label {
                    anchors.right: memLabel.left
                    anchors.rightMargin: Theme.u(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.u(44)
                    horizontalAlignment: Text.AlignRight
                    text: `${proc.modelData.cpu.toFixed(0)}% cpu`
                    size: Theme.u(8)
                    color: SystemStats.sortBy === "cpu" ? Theme.text : Theme.textDim
                }
                Label {
                    id: memLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.u(50)
                    horizontalAlignment: Text.AlignRight
                    text: `${(proc.modelData.mem * SystemStats.memTotal / 100).toFixed(1)} GB`
                    size: Theme.u(8)
                    color: SystemStats.sortBy === "mem" ? Theme.text : Theme.textDim
                }
            }
        }
    }
}
