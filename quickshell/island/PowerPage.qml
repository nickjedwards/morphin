import QtQuick
import Quickshell.Services.UPower
import qs.common
import qs.components
import qs.services

// Power: the three modes, what's holding one, the battery, and the rules
// for switching automatically.
Item {
    id: root

    implicitHeight: column.implicitHeight + Theme.u(20)

    Component.onCompleted: Battery.refresh()

    Column {
        id: column
        x: Theme.u(10)
        y: Theme.u(8)
        width: parent.width - Theme.u(20)
        spacing: Theme.u(4)

        PageHeader {
            width: parent.width
            title: "Power"
            onBack: IslandState.page = ""
        }

        // ── Mode ─────────────────────────────────────────────────────
        SectionLabel {
            width: parent.width
            text: "Mode"
        }

        Repeater {
            model: Power.modes

            delegate: DeviceRow {
                required property var modelData
                readonly property bool isCurrent: modelData.profile === Power.profile

                width: column.width
                icon: modelData.icon
                title: modelData.label
                subtitle: {
                    if (modelData.profile === PowerProfile.Performance && Power.degraded)
                        return `Limited: ${Power.degraded}`;
                    if (isCurrent && Power.autoActive)
                        return `Switched automatically (${Power.autoReason})`;
                    return modelData.description;
                }
                highlighted: isCurrent
                selected: isCurrent
                onClicked: Power.set(modelData.profile)
            }
        }

        // Apps asking for a mode (games wanting Performance, and so on).
        SectionLabel {
            visible: Power.holds.length > 0
            width: parent.width
            text: "Requested by apps"
        }

        Repeater {
            model: Power.holds

            delegate: DeviceRow {
                required property var modelData
                width: column.width
                icon: Power.modeFor(modelData.profile).icon
                title: modelData.applicationId || "An app"
                subtitle: `${Power.modeFor(modelData.profile).label}${modelData.reason ? " · " + modelData.reason : ""}`
                clickable: false
            }
        }

        // ── Battery ──────────────────────────────────────────────────
        SectionLabel {
            visible: Battery.available
            width: parent.width
            text: "Battery"
        }

        Rectangle {
            visible: Battery.available
            width: parent.width
            height: batteryColumn.implicitHeight + Theme.u(16)
            radius: Theme.u(14)
            color: Theme.cardItem

            Column {
                id: batteryColumn
                x: Theme.u(10)
                y: Theme.u(8)
                width: parent.width - Theme.u(20)
                spacing: Theme.u(8)

                Row {
                    spacing: Theme.u(10)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(Battery.level * 100)}%`
                        size: Theme.u(20)
                        font.weight: Font.DemiBold
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            text: Battery.status
                            size: Theme.u(8.5)
                            font.weight: Font.Medium
                        }
                        Label {
                            visible: Battery.rate > 0.05
                            text: `${Battery.charging ? "Charging at" : "Drawing"} ${Battery.rate.toFixed(1)} W`
                            size: Theme.u(7.5)
                            color: Theme.textDim
                        }
                    }
                }

                // Level bar, coloured by the current mode.
                Rectangle {
                    width: parent.width
                    height: Theme.u(6)
                    radius: height / 2
                    color: Theme.track

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Battery.level))
                        height: parent.height
                        radius: height / 2
                        color: Power.profile === PowerProfile.PowerSaver ? Theme.good : Power.profile === PowerProfile.Performance ? Theme.accent : Theme.text
                        Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
                    }
                }

                Row {
                    width: parent.width

                    Repeater {
                        model: [
                            { label: "Health", value: Battery.healthSupported ? `${Math.round(Battery.health * 100)}%` : "—" },
                            { label: "Cycles", value: Battery.cycles >= 0 ? String(Battery.cycles) : "—" },
                            { label: "Capacity", value: Battery.capacity > 0 ? `${Battery.capacity.toFixed(1)} Wh` : "—" },
                            { label: "Charge", value: Battery.energy > 0 ? `${Battery.energy.toFixed(1)} Wh` : "—" }
                        ]
                        delegate: Column {
                            required property var modelData
                            width: batteryColumn.width / 4

                            Label {
                                text: parent.modelData.value
                                size: Theme.u(10)
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

                // Charge limit: switchable when UPower can drive it,
                // otherwise just noted when the firmware is holding one.
                Item {
                    visible: Battery.thresholdSupported || Battery.holding
                    width: parent.width
                    height: Theme.u(24)

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            text: "Charge limit"
                            size: Theme.u(8.5)
                            font.weight: Font.Medium
                        }
                        Label {
                            text: Battery.thresholdSupported ? `Stops charging at ${Battery.thresholdEnd}%, resumes below ${Battery.thresholdStart}%` : `Set by the firmware · holding at ${Math.round(Battery.level * 100)}%`
                            size: Theme.u(7.5)
                            color: Theme.textDim
                        }
                    }
                    Switch {
                        visible: Battery.thresholdSupported
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Battery.thresholdEnabled
                        onToggled: Battery.setThreshold(!Battery.thresholdEnabled)
                    }
                }
            }
        }

        // ── Automatic ────────────────────────────────────────────────
        SectionLabel {
            visible: Battery.available
            width: parent.width
            text: "Automatic"
        }

        Rectangle {
            visible: Battery.available
            width: parent.width
            height: autoColumn.implicitHeight + Theme.u(8)
            radius: Theme.u(14)
            color: Theme.cardItem

            Column {
                id: autoColumn
                x: Theme.u(10)
                y: Theme.u(4)
                width: parent.width - Theme.u(20)

                AutoRow {
                    title: "Power Saver on battery"
                    subtitle: "When unplugged; your mode comes back when you plug in"
                    checked: Config.power.saverOnBattery
                    onToggled: Config.power.saverOnBattery = !Config.power.saverOnBattery
                }

                AutoRow {
                    title: "Power Saver on low battery"
                    subtitle: `At ${Config.power.lowBatteryThreshold}% or below, once per discharge`
                    checked: Config.power.saverOnLowBattery
                    onToggled: Config.power.saverOnLowBattery = !Config.power.saverOnLowBattery
                }

                Item {
                    visible: Config.power.saverOnLowBattery
                    width: parent.width
                    height: Theme.u(28)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Low battery at"
                        size: Theme.u(8.5)
                        font.weight: Font.Medium
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u(4)

                        CircleButton {
                            implicitWidth: Theme.u(20)
                            icon: Icons.minus
                            iconSize: Theme.u(9)
                            onClicked: Config.power.lowBatteryThreshold = Math.max(5, Config.power.lowBatteryThreshold - 5)
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.u(34)
                            horizontalAlignment: Text.AlignHCenter
                            text: `${Config.power.lowBatteryThreshold}%`
                            size: Theme.u(8.5)
                            font.weight: Font.DemiBold
                        }
                        CircleButton {
                            implicitWidth: Theme.u(20)
                            icon: Icons.plus
                            iconSize: Theme.u(9)
                            onClicked: Config.power.lowBatteryThreshold = Math.min(50, Config.power.lowBatteryThreshold + 5)
                        }
                    }
                }
            }
        }
    }

    component AutoRow: Item {
        id: autoRow

        property string title
        property string subtitle
        property bool checked
        signal toggled

        width: autoColumn.width
        height: Theme.u(36)

        Column {
            anchors.left: parent.left
            anchors.right: toggle.left
            anchors.rightMargin: Theme.u(8)
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: autoRow.title
                size: Theme.u(8.5)
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                text: autoRow.subtitle
                size: Theme.u(7.5)
                color: Theme.textDim
            }
        }
        Switch {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: autoRow.checked
            onToggled: autoRow.toggled()
        }
    }
}
