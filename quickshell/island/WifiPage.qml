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
            title: "Wi-Fi"
            hasSwitch: true
            checked: Net.enabled
            onBack: IslandState.page = ""
            onToggled: Net.toggle()
        }

        // The network we're on, as its own card.
        Rectangle {
            visible: Net.network !== null
            width: parent.width
            height: Theme.u(46)
            radius: Theme.u(14)
            color: Theme.cardItem

            Rectangle {
                id: onDot
                x: Theme.u(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(30)
                height: width
                radius: width / 2
                color: Theme.accent

                Icon {
                    anchors.centerIn: parent
                    text: Icons.wifi
                    size: Theme.u(12)
                    color: Theme.accentInk
                }
            }
            Column {
                anchors.left: onDot.right
                anchors.leftMargin: Theme.u(9)
                anchors.right: forgetCurrent.left
                anchors.rightMargin: Theme.u(8)
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: Net.network?.name ?? ""
                    size: Theme.u(10.5)
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    text: Net.detail(Net.network)
                    size: Theme.u(8)
                    color: Theme.textDim
                }
            }
            ConfirmButton {
                id: forgetCurrent
                anchors.right: disconnect.left
                anchors.rightMargin: Theme.u(4)
                anchors.verticalCenter: parent.verticalCenter
                text: "Forget"
                onConfirmed: Net.network?.forget()
            }
            PillButton {
                id: disconnect
                anchors.right: parent.right
                anchors.rightMargin: Theme.u(10)
                anchors.verticalCenter: parent.verticalCenter
                text: "Disconnect"
                onClicked: Net.disconnect()
            }
        }

        SectionLabel {
            width: parent.width
            text: "Networks"
            scanning: Net.scanning && Net.enabled
        }

        Label {
            visible: !Net.enabled || Net.networks.length === 0
            width: parent.width
            height: Theme.u(28)
            horizontalAlignment: Text.AlignHCenter
            text: !Net.enabled ? "Wi-Fi is off" : "Looking for networks…"
            size: Theme.u(8)
            color: Theme.textFaint
        }

        Repeater {
            model: Net.enabled ? Net.networks : []

            delegate: Column {
                id: entry

                required property var modelData
                readonly property bool asking: Net.pending === modelData

                width: column.width
                spacing: Theme.u(3)

                DeviceRow {
                    width: parent.width
                    icon: Net.isSecure(entry.modelData) && !entry.modelData.known ? Icons.wifiLock : Net.signalIcon(entry.modelData)
                    title: entry.modelData.name
                    subtitle: Net.detail(entry.modelData)
                    action: entry.modelData.stateChanging ? "…" : entry.asking ? "Cancel" : "Connect"
                    onActionClicked: entry.asking ? (Net.pending = null) : Net.activate(entry.modelData)
                    secondary: entry.modelData.known ? "Forget" : ""
                    onSecondaryConfirmed: entry.modelData.forget()
                }

                // Password, inline, for a new secured network.
                Rectangle {
                    visible: entry.asking
                    width: parent.width
                    height: Theme.u(28)
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: password.activeFocus ? Theme.accentMuted : Theme.surface

                    TextInput {
                        id: password
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.u(12)
                        anchors.right: join.left
                        anchors.rightMargin: Theme.u(8)
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.u(9)
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: Net.connectWithPassword(text)

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !password.text
                            text: "Password"
                            size: Theme.u(9)
                            color: Theme.textFaint
                        }
                    }
                    PillButton {
                        id: join
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u(4)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Join"
                        primary: true
                        onClicked: Net.connectWithPassword(password.text)
                    }
                }

                Label {
                    visible: entry.asking && Net.error !== ""
                    width: parent.width
                    text: Net.error
                    size: Theme.u(7.5)
                    color: Theme.danger
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
            }
        }

        // A network that doesn't announce itself: typed in by name.
        Column {
            id: hidden

            property bool open: false

            visible: Net.enabled
            width: column.width
            spacing: Theme.u(3)

            DeviceRow {
                width: parent.width
                icon: Icons.plus
                title: "Other network…"
                subtitle: "Join a hidden network by name"
                action: hidden.open ? "Cancel" : Net.joining ? "…" : "Join"
                onActionClicked: {
                    hidden.open = !hidden.open;
                    Net.hiddenError = "";
                }
            }

            Repeater {
                model: hidden.open ? ["Network name", "Password (leave empty if open)"] : []

                delegate: Rectangle {
                    required property string modelData
                    required property int index

                    width: hidden.width
                    height: Theme.u(28)
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: field.activeFocus ? Theme.accentMuted : Theme.surface

                    TextInput {
                        id: field
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.u(12)
                        anchors.right: parent.right
                        anchors.rightMargin: index === 1 ? joinHidden.width + Theme.u(12) : Theme.u(12)
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: index === 1 ? TextInput.Password : TextInput.Normal
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.u(9)
                        clip: true
                        Component.onCompleted: if (index === 0) forceActiveFocus()
                        onTextChanged: index === 0 ? (hidden.ssid = text) : (hidden.password = text)
                        onAccepted: hidden.join()

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !field.text
                            text: modelData
                            size: Theme.u(9)
                            color: Theme.textFaint
                        }
                    }
                    PillButton {
                        id: joinHidden
                        visible: index === 1
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u(4)
                        anchors.verticalCenter: parent.verticalCenter
                        text: Net.joining ? "Joining…" : "Join"
                        primary: true
                        onClicked: hidden.join()
                    }
                }
            }

            property string ssid: ""
            property string password: ""

            function join(): void {
                if (hidden.ssid.trim() !== "" && !Net.joining)
                    Net.joinHidden(hidden.ssid.trim(), hidden.password);
            }

            Connections {
                target: Net
                function onHiddenJoined(): void {
                    hidden.open = false;
                }
            }

            Label {
                visible: Net.hiddenError !== ""
                width: parent.width
                text: Net.hiddenError
                size: Theme.u(7.5)
                color: Theme.danger
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
    }
}
