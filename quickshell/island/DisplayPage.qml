import QtQuick
import qs.common
import qs.components
import qs.services

Item {
    id: root

    implicitHeight: column.implicitHeight + Theme.u(20)

    Component.onCompleted: {
        Displays.refresh();
        Displays.refreshBrightness();
    }

    Column {
        id: column
        x: Theme.u(10)
        y: Theme.u(8)
        width: parent.width - Theme.u(20)
        spacing: Theme.u(6)

        PageHeader {
            width: parent.width
            title: "Display"
            onBack: IslandState.page = ""
        }

        Repeater {
            model: Displays.monitors

            delegate: Rectangle {
                id: card

                required property var modelData
                property bool pickingMode: false
                readonly property bool hasBrightness: Displays.hasBrightness(modelData.name)

                width: column.width
                height: inner.implicitHeight + Theme.u(16)
                radius: Theme.u(16)
                color: Theme.cardItem

                Column {
                    id: inner
                    x: Theme.u(8)
                    y: Theme.u(8)
                    width: parent.width - Theme.u(16)
                    spacing: Theme.u(6)

                    Item {
                        width: parent.width
                        height: Theme.u(26)

                        Rectangle {
                            id: monDot
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.u(24)
                            height: width
                            radius: width / 2
                            color: card.modelData.focused ? Theme.accent : Theme.surface

                            Icon {
                                anchors.centerIn: parent
                                text: Icons.monitor
                                size: Theme.u(10)
                                color: card.modelData.focused ? Theme.accentInk : Theme.textDim
                            }
                        }
                        Column {
                            anchors.left: monDot.right
                            anchors.leftMargin: Theme.u(8)
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                text: card.modelData.name
                                size: Theme.u(9.5)
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: Displays.describe(card.modelData)
                                size: Theme.u(7.5)
                                color: Theme.textDim
                            }
                        }
                        Label {
                            visible: card.modelData.focused && Displays.monitors.length > 1
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "focused"
                            size: Theme.u(7.5)
                            color: Theme.accent
                        }
                    }

                    LevelSlider {
                        visible: card.hasBrightness
                        width: parent.width
                        icon: Icons.brightness
                        value: Displays.brightnessOf(card.modelData.name)
                        onMoved: v => Displays.setBrightness(card.modelData.name, v)
                    }

                    Row {
                        spacing: Theme.u(4)

                        Repeater {
                            model: [1.0, 1.25, 1.5, 1.75, 2.0]
                            delegate: PillButton {
                                required property real modelData
                                readonly property bool current: Math.abs(card.modelData.scale - modelData) < 0.01
                                text: `${modelData % 1 === 0 ? modelData.toFixed(1) : modelData}×`
                                primary: current
                                implicitHeight: Theme.u(18)
                                size: Theme.u(7.5)
                                onClicked: Displays.setScale(card.modelData, modelData)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.u(18)

                        Label {
                            x: Theme.u(2)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Resolution"
                            size: Theme.u(7.5)
                            color: Theme.textDim
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u(4)

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: `${card.modelData.width}×${card.modelData.height} @ ${Math.round(card.modelData.refreshRate)} Hz`
                                size: Theme.u(8)
                                font.weight: Font.DemiBold
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.chevronRight
                                size: Theme.u(9)
                                color: Theme.textDim
                                rotation: card.pickingMode ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: Theme.fastDuration } }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.pickingMode = !card.pickingMode
                        }
                    }

                    Column {
                        visible: card.pickingMode
                        width: parent.width
                        spacing: Theme.u(2)

                        Repeater {
                            model: card.pickingMode ? Displays.modesOf(card.modelData) : []
                            delegate: DeviceRow {
                                required property var modelData
                                width: parent.width
                                implicitHeight: Theme.u(24)
                                icon: Icons.monitor
                                title: modelData.label
                                selected: modelData.key === `${card.modelData.width}x${card.modelData.height}@${Math.round(card.modelData.refreshRate)}`
                                onClicked: {
                                    Displays.setMode(card.modelData, modelData.mode);
                                    card.pickingMode = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Keyboard backlight
        Rectangle {
            visible: KeyboardLight.available
            width: column.width
            height: keyboardInner.implicitHeight + Theme.u(16)
            radius: Theme.u(16)
            color: Theme.cardItem

            Column {
                id: keyboardInner
                x: Theme.u(8)
                y: Theme.u(8)
                width: parent.width - Theme.u(16)
                spacing: Theme.u(6)

                Item {
                    width: parent.width
                    height: Theme.u(26)

                    Rectangle {
                        id: keyDot
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u(24)
                        height: width
                        radius: width / 2
                        color: KeyboardLight.raw > 0 ? Theme.accent : Theme.surface

                        Icon {
                            anchors.centerIn: parent
                            text: Icons.keyboard
                            size: Theme.u(10)
                            color: KeyboardLight.raw > 0 ? Theme.accentInk : Theme.textDim
                        }
                    }
                    Column {
                        anchors.left: keyDot.right
                        anchors.leftMargin: Theme.u(8)
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            text: "Keyboard"
                            size: Theme.u(9.5)
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: KeyboardLight.label
                            size: Theme.u(7.5)
                            color: Theme.textDim
                        }
                    }
                    Switch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: KeyboardLight.raw > 0
                        onToggled: KeyboardLight.toggle()
                    }
                }

                Slider {
                    width: parent.width
                    icon: Icons.keyboard
                    value: KeyboardLight.value
                    onMoved: v => KeyboardLight.set(v)
                }
            }
        }

        // Night light
        Rectangle {
            width: column.width
            height: nightInner.implicitHeight + Theme.u(16)
            radius: Theme.u(16)
            color: Theme.cardItem

            Column {
                id: nightInner
                x: Theme.u(8)
                y: Theme.u(8)
                width: parent.width - Theme.u(16)
                spacing: Theme.u(6)

                Item {
                    width: parent.width
                    height: Theme.u(26)

                    Rectangle {
                        id: moonDot
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u(24)
                        height: width
                        radius: width / 2
                        color: NightLight.enabled ? Theme.accent : Theme.surface

                        Icon {
                            anchors.centerIn: parent
                            text: Icons.nightLight
                            size: Theme.u(10)
                            color: NightLight.enabled ? Theme.accentInk : Theme.textDim
                        }
                    }
                    Column {
                        anchors.left: moonDot.right
                        anchors.leftMargin: Theme.u(8)
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            text: "Night Light"
                            size: Theme.u(9.5)
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: NightLight.available ? `${NightLight.temperature} K` : "Install hyprsunset to use night light"
                            size: Theme.u(7.5)
                            color: Theme.textDim
                        }
                    }
                    Switch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: NightLight.enabled
                        onToggled: NightLight.toggle()
                    }
                }

                Slider {
                    width: parent.width
                    icon: Icons.nightLight
                    valueOnHover: false
                    value: NightLight.warmth
                    onMoved: v => NightLight.setWarmth(v)
                }
            }
        }
    }
}
