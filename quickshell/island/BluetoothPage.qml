import QtQuick
import qs.common
import qs.components
import qs.services

Item {
    id: root

    implicitHeight: column.implicitHeight + Theme.u(20)

    Column {
        id: column
        x: Theme.u(10)
        y: Theme.u(8)
        width: parent.width - Theme.u(20)
        spacing: Theme.u(4)

        PageHeader {
            width: parent.width
            title: "Bluetooth"
            hasSwitch: true
            checked: Bt.enabled
            onBack: IslandState.page = ""
            onToggled: Bt.toggle()
        }

        SectionLabel {
            visible: Bt.saved.length > 0
            width: parent.width
            text: "Saved"
        }

        Repeater {
            model: Bt.enabled ? Bt.saved : []

            delegate: DeviceRow {
                required property var modelData
                width: column.width
                icon: Bt.deviceIcon(modelData)
                title: modelData.name
                subtitle: Bt.deviceState(modelData)
                highlighted: modelData.connected
                action: modelData.connected ? "Disconnect" : "Connect"
                onActionClicked: Bt.act(modelData)
                secondary: "Forget"
                onSecondaryConfirmed: modelData.forget()
            }
        }

        SectionLabel {
            width: parent.width
            text: "Nearby"
            scanning: Bt.scanning
        }

        Label {
            visible: !Bt.enabled || Bt.nearby.length === 0
            width: parent.width
            height: Theme.u(28)
            text: !Bt.enabled ? "Bluetooth is off" : "Looking for devices…  put the device in pairing mode"
            size: Theme.u(8)
            color: Theme.textDim
        }

        Repeater {
            model: Bt.enabled ? Bt.nearby : []

            delegate: DeviceRow {
                required property var modelData
                width: column.width
                icon: Bt.deviceIcon(modelData)
                title: modelData.name
                subtitle: Bt.deviceState(modelData)
                action: modelData.pairing ? "…" : "Pair"
                onActionClicked: Bt.act(modelData)
            }
        }
    }
}
