import QtQuick
import qs.common
import qs.components

// One settings row: label and description on the left, a control on the
// right. `kind` picks the control; the row reads and writes `value`.
Item {
    id: row

    property string label
    property string description
    property string kind: "switch"   // switch | slider | choice | text | color | stepper
    property var value
    property var options: []         // choice: [{ label, value }]
    property real from: 0
    property real to: 1
    property real step: 0.05
    property string suffix: ""
    property int decimals: 0

    signal changed(var value)

    width: parent?.width ?? 0
    implicitHeight: Math.max(Theme.u(34), texts.implicitHeight + Theme.u(14))

    Column {
        id: texts
        x: Theme.u(12)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - control.width - Theme.u(28)
        spacing: Theme.u(1)

        Label {
            width: parent.width
            text: row.label
            size: Theme.u(9)
            font.weight: Font.Medium
        }
        Label {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            size: Theme.u(7.5)
            color: Theme.textDim
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
    }

    Item {
        id: control
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(12)
        anchors.verticalCenter: parent.verticalCenter
        width: loader.item?.implicitWidth ?? 0
        height: loader.item?.implicitHeight ?? 0

        Loader {
            id: loader
            sourceComponent: {
                switch (row.kind) {
                case "switch":
                    return switchControl;
                case "slider":
                    return sliderControl;
                case "choice":
                    return choiceControl;
                case "text":
                    return textControl;
                case "color":
                    return colorControl;
                case "stepper":
                    return stepperControl;
                }
                return null;
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        x: Theme.u(12)
        width: parent.width - Theme.u(24)
        height: 1
        color: Theme.surface
        opacity: 0.6
    }

    Component {
        id: switchControl
        Switch {
            checked: !!row.value
            onToggled: row.changed(!row.value)
        }
    }

    Component {
        id: sliderControl
        Row {
            spacing: Theme.u(8)

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(150)
                implicitHeight: Theme.u(14)
                valueOnHover: false
                value: (row.value - row.from) / (row.to - row.from)
                onMoved: v => {
                    const raw = row.from + v * (row.to - row.from);
                    row.changed(Math.round(raw / row.step) * row.step);
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(38)
                horizontalAlignment: Text.AlignRight
                text: Number(row.value).toFixed(row.decimals) + row.suffix
                size: Theme.u(8)
                color: Theme.textDim
            }
        }
    }

    Component {
        id: choiceControl
        Rectangle {
            implicitWidth: choices.implicitWidth + Theme.u(4)
            implicitHeight: Theme.u(22)
            radius: height / 2
            color: Theme.surface

            Row {
                id: choices
                x: Theme.u(2)
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: row.options
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: row.value === modelData.value
                        width: choiceLabel.implicitWidth + Theme.u(16)
                        height: Theme.u(18)
                        radius: height / 2
                        color: current ? Theme.accent : choiceMouse.containsMouse ? Theme.surfaceHover : "transparent"

                        Label {
                            id: choiceLabel
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            size: Theme.u(7.5)
                            font.weight: Font.DemiBold
                            color: parent.current ? Theme.accentInk : Theme.text
                        }
                        MouseArea {
                            id: choiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.changed(parent.modelData.value)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: textControl
        Rectangle {
            implicitWidth: Theme.u(190)
            implicitHeight: Theme.u(22)
            radius: height / 2
            color: Theme.surface
            border.width: 1
            border.color: input.activeFocus ? Theme.accentMuted : "transparent"

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: Theme.u(10)
                anchors.rightMargin: Theme.u(10)
                verticalAlignment: TextInput.AlignVCenter
                text: row.value ?? ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.u(8.5)
                clip: true
                selectByMouse: true
                onEditingFinished: row.changed(text)
            }
        }
    }

    Component {
        id: colorControl
        Row {
            spacing: Theme.u(5)

            Repeater {
                model: ["#86c497", "#7fb4e0", "#b59be8", "#e8a07f", "#e0c26b", "#e07f9e", "#7fd1c7"]
                delegate: Rectangle {
                    required property string modelData
                    width: Theme.u(18)
                    height: width
                    radius: width / 2
                    color: modelData
                    border.width: Qt.colorEqual(row.value, modelData) ? Theme.u(2) : 0
                    border.color: Theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.changed(parent.modelData)
                    }
                }
            }
        }
    }

    Component {
        id: stepperControl
        Row {
            spacing: Theme.u(4)

            CircleButton {
                implicitWidth: Theme.u(22)
                icon: Icons.minus
                iconSize: Theme.u(9)
                onClicked: row.changed(Math.max(row.from, row.value - row.step))
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(46)
                horizontalAlignment: Text.AlignHCenter
                text: Number(row.value).toFixed(row.decimals) + row.suffix
                size: Theme.u(8.5)
                font.weight: Font.DemiBold
            }
            CircleButton {
                implicitWidth: Theme.u(22)
                icon: Icons.plus
                iconSize: Theme.u(9)
                onClicked: row.changed(Math.min(row.to, row.value + row.step))
            }
        }
    }
}
