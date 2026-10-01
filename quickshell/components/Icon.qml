import QtQuick
import qs.common

Text {
    property real size: Theme.u(12)

    color: Theme.text
    font.family: Theme.iconFont
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
