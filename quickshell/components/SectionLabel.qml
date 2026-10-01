import QtQuick
import qs.common

// "Networks", "Saved", "Output"… with an optional "• Scanning" on the right.
Item {
    id: section

    property string text
    property bool scanning: false

    implicitHeight: Theme.u(20)

    Label {
        x: Theme.u(2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u(3)
        text: section.text
        size: Theme.u(7.5)
        color: Theme.textDim
    }

    Row {
        visible: section.scanning
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u(3)
        spacing: Theme.u(4)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.u(4)
            height: width
            radius: width / 2
            color: Theme.accent

            SequentialAnimation on opacity {
                running: section.scanning
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        Label {
            text: "Scanning"
            size: Theme.u(7.5)
            color: Theme.textDim
        }
    }
}
