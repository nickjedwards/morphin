import QtQuick
import Quickshell.Services.Pipewire
import qs.common
import qs.components
import qs.services

Item {
    id: root

    implicitHeight: column.implicitHeight + Theme.u(20)

    Component.onCompleted: Audio.streamWatchers++
    Component.onDestruction: Audio.streamWatchers--

    Column {
        id: column
        x: Theme.u(10)
        y: Theme.u(8)
        width: parent.width - Theme.u(20)
        spacing: Theme.u(4)

        PageHeader {
            width: parent.width
            title: "Audio"
            onBack: IslandState.page = ""
        }

        SectionLabel {
            width: parent.width
            text: "Output"
        }

        Repeater {
            model: Audio.sinks
            delegate: DeviceRow {
                required property PwNode modelData
                width: column.width
                icon: Audio.deviceIcon(modelData)
                title: Audio.nodeName(modelData)
                highlighted: modelData === Audio.sink
                selected: modelData === Audio.sink
                onClicked: Audio.setDefault(modelData)
            }
        }

        LevelSlider {
            width: parent.width
            icon: Audio.icon
            value: Audio.muted ? 0 : Audio.volume
            onMoved: v => Audio.setVolume(v)
        }

        SectionLabel {
            visible: Audio.sources.length > 0
            width: parent.width
            text: "Input"
        }

        Repeater {
            model: Audio.sources
            delegate: DeviceRow {
                required property PwNode modelData
                width: column.width
                icon: Icons.microphone
                title: Audio.nodeName(modelData)
                highlighted: modelData === Audio.source
                selected: modelData === Audio.source
                onClicked: Audio.setDefault(modelData)
            }
        }

        LevelSlider {
            visible: Audio.source !== null
            width: parent.width
            icon: Icons.microphone
            value: Audio.inputMuted ? 0 : Audio.inputVolume
            onMoved: v => Audio.setInputVolume(v)
        }

        SectionLabel {
            visible: Audio.streams.length > 0
            width: parent.width
            text: "Apps"
        }

        Repeater {
            model: Audio.streams
            delegate: Rectangle {
                id: app

                required property PwNode modelData

                width: column.width
                height: Theme.u(46)
                radius: Theme.u(14)
                color: Theme.cardItem

                Label {
                    x: Theme.u(10)
                    y: Theme.u(5)
                    height: Theme.u(14)
                    width: parent.width - Theme.u(20)
                    text: Audio.streamName(app.modelData)
                    size: Theme.u(9)
                    font.weight: Font.DemiBold
                }
                LevelSlider {
                    x: Theme.u(8)
                    y: Theme.u(22)
                    width: parent.width - Theme.u(16)
                    icon: Audio.iconFor(app.modelData.audio?.volume ?? 0, app.modelData.audio?.muted ?? false)
                    value: app.modelData.audio?.muted ? 0 : (app.modelData.audio?.volume ?? 0)
                    onMoved: v => Audio.setNodeVolume(app.modelData, v)
                }
            }
        }
    }
}
