import QtQuick
import qs.common
import qs.components

// One settings row: label and description on the left, a control on the
// right. `kind` picks the control; the row reads and writes `value`.
Item {
    id: row

    property string label
    property string description
    property string kind: "switch"   // switch | slider | choice | picker | text | color | stepper
    property var value
    // choice, picker: [{ label, value }]. Picker options may add `colors`
    // (shown as dots) and `font` (the label is drawn in that family).
    property var options: []
    property real from: 0
    property real to: 1
    property real step: 0.05
    property string suffix: ""
    property int decimals: 0

    signal changed(var value)

    // The row proper; a picker unfolds its list underneath.
    readonly property real headHeight: Math.max(Theme.u(34), texts.implicitHeight + Theme.u(14))
    property bool pickerOpen: false
    property string pickerFilter: ""
    readonly property var pickerOptions: {
        const q = pickerFilter.trim().toLowerCase();
        return q ? options.filter(o => o.label.toLowerCase().includes(q)) : options;
    }
    readonly property var currentOption: options.find(o => o.value === value) ?? null

    width: parent?.width ?? 0
    implicitHeight: headHeight + (pickerOpen ? pickerArea.height + Theme.u(8) : 0)
    Behavior on implicitHeight { Anim { curve: "fade" } }
    clip: true

    onPickerOpenChanged: pickerFilter = ""

    Column {
        id: texts
        x: Theme.u(12)
        y: (row.headHeight - height) / 2
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
        y: (row.headHeight - height) / 2
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
                case "picker":
                    return pickerControl;
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

    // Picker: a button showing the current choice; the list opens below the
    // row, with a filter once there are enough options to want one.
    Component {
        id: pickerControl
        Rectangle {
            implicitWidth: Theme.u(190)
            implicitHeight: Theme.u(22)
            radius: height / 2
            color: pickerMouse.containsMouse || row.pickerOpen ? Theme.surfaceHover : Theme.surface

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.u(10)
                anchors.right: pickerChevron.left
                anchors.rightMargin: Theme.u(4)
                anchors.verticalCenter: parent.verticalCenter
                // A saved value that's no longer on offer is shown as it is.
                text: row.currentOption?.label ?? String(row.value ?? "")
                size: Theme.u(8.5)
                font.weight: Font.Medium
                color: row.currentOption ? Theme.text : Theme.danger
            }
            Icon {
                id: pickerChevron
                anchors.right: parent.right
                anchors.rightMargin: Theme.u(7)
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.chevronRight
                size: Theme.u(10)
                color: Theme.textDim
                rotation: row.pickerOpen ? 90 : 0
                Behavior on rotation { Anim { curve: "fade" } }
            }
            MouseArea {
                id: pickerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.pickerOpen = !row.pickerOpen
            }
        }
    }

    Rectangle {
        id: pickerArea
        visible: row.kind === "picker" && (row.pickerOpen || row.implicitHeight > row.headHeight + 1)
        x: Theme.u(12)
        y: row.headHeight
        width: parent.width - Theme.u(24)
        height: (pickerSearch.visible ? pickerSearch.height + Theme.u(4) : 0) + pickerList.height + Theme.u(8)
        radius: Theme.u(10)
        color: Theme.track

        readonly property real rowHeight: Theme.u(24)

        Rectangle {
            id: pickerSearch
            visible: row.options.length > 8
            x: Theme.u(4)
            y: Theme.u(4)
            width: parent.width - Theme.u(8)
            height: Theme.u(22)
            radius: height / 2
            color: Theme.surface

            Icon {
                id: pickerSearchIcon
                x: Theme.u(8)
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.search
                size: Theme.u(9)
                color: Theme.textDim
            }
            TextInput {
                id: pickerInput
                anchors.left: pickerSearchIcon.right
                anchors.leftMargin: Theme.u(6)
                anchors.right: parent.right
                anchors.rightMargin: Theme.u(10)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.u(8.5)
                clip: true
                text: row.pickerFilter
                onTextChanged: row.pickerFilter = text
                onVisibleChanged: if (visible && row.pickerOpen) forceActiveFocus()
                onAccepted: {
                    if (row.pickerOptions.length > 0) {
                        row.changed(row.pickerOptions[0].value);
                        row.pickerOpen = false;
                    }
                }
                Keys.onEscapePressed: row.pickerOpen = false

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !pickerInput.text
                    text: "Filter…"
                    size: Theme.u(8.5)
                    color: Theme.textFaint
                }
            }
        }

        Label {
            anchors.centerIn: pickerList
            visible: row.pickerOptions.length === 0
            text: "Nothing matches"
            size: Theme.u(8)
            color: Theme.textFaint
        }

        ListView {
            id: pickerList
            x: Theme.u(4)
            y: (pickerSearch.visible ? pickerSearch.height + Theme.u(4) : 0) + Theme.u(4)
            width: parent.width - Theme.u(8)
            height: Math.max(1, Math.min(6, row.pickerOptions.length)) * pickerArea.rowHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: row.pickerOpen ? row.pickerOptions : []

            delegate: Rectangle {
                id: option

                required property var modelData
                readonly property bool current: modelData.value === row.value

                width: pickerList.width
                height: pickerArea.rowHeight
                radius: Theme.u(8)
                color: optionMouse.containsMouse ? Theme.surface : "transparent"

                Label {
                    id: optionLabel
                    x: Theme.u(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.u(16) - optionTrail.width
                    text: option.modelData.label
                    size: Theme.u(8.5)
                    font.family: option.modelData.font ?? Theme.font
                    font.weight: option.current ? Font.DemiBold : Font.Normal
                    color: option.current ? Theme.accent : Theme.text
                }
                Row {
                    id: optionTrail
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u(2)

                    Repeater {
                        model: option.modelData.colors ?? []
                        delegate: Rectangle {
                            required property var modelData
                            width: Theme.u(7)
                            height: width
                            radius: width / 2
                            color: modelData
                        }
                    }
                    Icon {
                        visible: option.current
                        leftPadding: Theme.u(4)
                        text: Icons.check
                        size: Theme.u(10)
                        color: Theme.accent
                    }
                }
                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        row.changed(option.modelData.value);
                        row.pickerOpen = false;
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
