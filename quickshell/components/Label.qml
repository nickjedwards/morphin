import QtQuick
import qs.common

Text {
    property real size: Theme.u(10)

    color: Theme.text
    font.family: Theme.font
    font.pixelSize: size
    font.features: { "tnum": 1 }
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
