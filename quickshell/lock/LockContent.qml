import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common
import qs.components
import qs.services

// What the lock screen shows: the wallpaper blurred, the date and a big clock
// at the top, and the user with a password pill at the bottom.
FocusScope {
    id: root

    required property var context   // LockScreen, which owns the PAM state

    // Sizes follow the screen, as measured off a 631px-tall reference.
    readonly property real k: height / 631

    focus: true

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Image {
        id: wall
        anchors.fill: parent
        source: Wallpaper.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: !Config.lock.blur
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: Config.lock.blur
        blurEnabled: true
        blur: 1
        blurMax: 64
        autoPaddingEnabled: false
        brightness: -0.04
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.12
    }

    // Top right: battery and network.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.k
        y: 6 * root.k
        spacing: 8 * root.k

        Icon {
            visible: Battery.available
            text: Battery.icon
            size: 11 * root.k
            rotation: 90
            color: Qt.rgba(1, 1, 1, 0.8)
        }
        Icon {
            text: Net.icon
            size: 10 * root.k
            color: Qt.rgba(1, 1, 1, 0.8)
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 70 * root.k
        spacing: -4 * root.k

        Label {
            visible: Config.lock.showDate
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
            size: 15 * root.k
            font.weight: Font.Medium
            color: Qt.rgba(1, 1, 1, 0.72)
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, Config.lock.twelveHour ? "h:mm" : "H:mm")
            size: 92 * root.k
            font.family: "Inter Display"
            font.weight: Font.DemiBold
            font.letterSpacing: -2 * root.k
            color: Qt.rgba(1, 1, 1, 0.72)
        }
    }

    Column {
        id: userColumn
        anchors.horizontalCenter: parent.horizontalCenter
        y: 489 * root.k
        spacing: 7 * root.k

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34 * root.k
            height: width
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            Icon {
                anchors.centerIn: parent
                text: Icons.account
                size: 17 * root.k
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.user
            size: 11 * root.k
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.9)
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 116 * root.k
            height: 18 * root.k

            Label {
                anchors.centerIn: parent
                visible: !root.context.typing
                text: root.context.message || "Press Any Key to Enter Password"
                size: 8.5 * root.k
                font.weight: Font.Medium
                color: root.context.failed ? "#ffb4ab" : Qt.rgba(1, 1, 1, 0.6)
            }

            Rectangle {
                id: pill
                anchors.fill: parent
                visible: root.context.typing
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.22)
                transform: Translate { id: shakeOffset }

                Row {
                    x: 7 * root.k
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.k

                    Repeater {
                        model: Math.min(root.context.buffer.length, 14)
                        delegate: Rectangle {
                            width: 5.5 * root.k
                            height: width
                            radius: width / 2
                            color: "white"
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 9 * root.k
                        color: "white"
                        visible: !root.context.busy

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: pill.visible
                            NumberAnimation { to: 0; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root.context
        function onRejected(): void {
            shake.restart();
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeOffset; property: "x"; to: 9 * root.k; duration: 50 }
        NumberAnimation { target: shakeOffset; property: "x"; to: -9 * root.k; duration: 80 }
        NumberAnimation { target: shakeOffset; property: "x"; to: 5 * root.k; duration: 70 }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60 }
    }

    Keys.onPressed: event => {
        if (root.context.busy)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.context.submit();
        } else if (event.key === Qt.Key_Backspace) {
            root.context.buffer = event.modifiers & Qt.ControlModifier ? "" : root.context.buffer.slice(0, -1);
        } else if (event.key === Qt.Key_Escape) {
            root.context.buffer = "";
        } else if (event.text && event.text.charCodeAt(0) >= 32) {
            root.context.buffer += event.text;
        }
        root.context.typing = true;
        event.accepted = true;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.forceActiveFocus();
            root.context.typing = true;
        }
    }
}
