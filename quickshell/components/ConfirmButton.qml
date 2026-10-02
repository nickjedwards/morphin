import QtQuick
import qs.common

// A quiet text button for something you can't undo ("Forget"). The first
// click arms it — it turns red and asks — and a second within a few seconds
// does it; otherwise it goes back to rest.
Item {
    id: button

    property string text
    property string confirmText: "Sure?"
    property bool armed: false

    signal confirmed

    implicitWidth: label.implicitWidth + Theme.u(10)
    implicitHeight: Theme.u(20)

    Label {
        id: label
        anchors.centerIn: parent
        text: button.armed ? button.confirmText : button.text
        size: Theme.u(8)
        font.weight: Font.Medium
        color: button.armed ? Theme.danger : mouse.containsMouse ? Theme.text : Theme.textDim
        Behavior on color { ColorAnimation { duration: Theme.fastDuration } }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: button.armed = false
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (button.armed) {
                button.armed = false;
                disarm.stop();
                button.confirmed();
            } else {
                button.armed = true;
                disarm.restart();
            }
        }
    }
}
