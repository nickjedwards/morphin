import QtQuick
import qs.common
import qs.components
import qs.services

// "Authentication required": the polkit agent's password prompt.
FocusScope {
    id: root

    readonly property var flow: Polkit.flow
    property bool shaking: false

    implicitWidth: Theme.u(330)
    implicitHeight: column.implicitHeight + Theme.u(24)

    Component.onCompleted: field.forceActiveFocus()

    function submit(): void {
        if (!root.flow)
            return;
        Polkit.submit(field.text);
        field.text = "";
    }

    Connections {
        target: root.flow
        function onFailedChanged(): void {
            if (root.flow.failed)
                shake.restart();
        }
    }

    Column {
        id: column
        x: Theme.u(12)
        y: Theme.u(12)
        width: parent.width - Theme.u(24)
        spacing: Theme.u(8)

        Row {
            spacing: Theme.u(9)

            Rectangle {
                width: Theme.u(24)
                height: width
                radius: width / 2
                color: Theme.accent

                Icon {
                    anchors.centerIn: parent
                    text: Icons.lock
                    size: Theme.u(10)
                    color: Theme.accentInk
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Authentication required"
                size: Theme.u(11.5)
                font.weight: Font.Medium
            }
        }

        Rectangle {
            width: parent.width
            height: messageColumn.implicitHeight + Theme.u(16)
            radius: Theme.u(12)
            color: Theme.card

            Column {
                id: messageColumn
                x: Theme.u(10)
                y: Theme.u(8)
                width: parent.width - Theme.u(20)
                spacing: Theme.u(2)

                Label {
                    width: parent.width
                    text: root.flow?.message ?? ""
                    size: Theme.u(9)
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                }
                Label {
                    width: parent.width
                    text: root.flow?.actionId ?? ""
                    size: Theme.u(7.5)
                    color: Theme.textDim
                }
            }
        }

        Label {
            text: root.flow?.failed ? "Wrong password, try again" : (root.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
            size: Theme.u(7.5)
            color: root.flow?.failed ? Theme.danger : Theme.textDim
        }

        Rectangle {
            id: inputBox
            width: parent.width
            height: Theme.u(28)
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: field.activeFocus ? Theme.accentMuted : Theme.surface

            transform: Translate { id: shakeOffset }

            Rectangle {
                id: lockDot
                x: Theme.u(4)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(20)
                height: width
                radius: width / 2
                color: field.text ? Theme.accent : Theme.surface

                Icon {
                    anchors.centerIn: parent
                    text: Icons.lock
                    size: Theme.u(8)
                    color: field.text ? Theme.accentInk : Theme.textDim
                }
            }

            TextInput {
                id: field
                anchors.left: lockDot.right
                anchors.leftMargin: Theme.u(8)
                anchors.right: parent.right
                anchors.rightMargin: Theme.u(12)
                anchors.verticalCenter: parent.verticalCenter
                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.u(9.5)
                focus: true
                onAccepted: root.submit()
                Keys.onEscapePressed: Polkit.cancel()

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !field.text
                    text: "Enter your password"
                    size: Theme.u(9.5)
                    color: Theme.textFaint
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.u(6)

            PillButton {
                text: "Cancel"
                onClicked: Polkit.cancel()
            }
            PillButton {
                text: "Authenticate"
                primary: true
                onClicked: root.submit()
            }
        }
    }

    SequentialAnimation {
        id: shake
        loops: 1
        NumberAnimation { target: shakeOffset; property: "x"; to: Theme.u(8); duration: 50 }
        NumberAnimation { target: shakeOffset; property: "x"; to: -Theme.u(8); duration: 80 }
        NumberAnimation { target: shakeOffset; property: "x"; to: Theme.u(4); duration: 70 }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60 }
    }
}
