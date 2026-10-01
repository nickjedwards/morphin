import QtQuick
import Quickshell.Widgets
import qs.common
import qs.components

// "Wallpaper": a carousel of the wallpaper folder. Arrows move, Enter
// applies — the wallpaper crossfades, then the picker puts itself away.
FocusScope {
    id: root

    signal done

    readonly property var files: Wallpaper.files
    readonly property string selectedFile: files[strip.currentIndex] ?? ""

    implicitWidth: Theme.u(830)
    implicitHeight: Theme.u(190)

    focus: true
    Component.onCompleted: {
        strip.currentIndex = Math.max(0, files.indexOf(Wallpaper.resolved));
        strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
        forceActiveFocus();
    }

    function apply(): void {
        if (!root.selectedFile)
            return;
        Wallpaper.set(root.selectedFile);
        closeTimer.restart();
    }

    // Let the crossfade start before the island closes over it.
    Timer {
        id: closeTimer
        interval: 450
        onTriggered: root.done()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:
        case Qt.Key_Backtab:
            strip.step(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
        case Qt.Key_Tab:
            strip.step(1);
            break;
        case Qt.Key_Home:
            strip.currentIndex = 0;
            break;
        case Qt.Key_End:
            strip.currentIndex = strip.count - 1;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.apply();
            break;
        case Qt.Key_Escape:
            root.done();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Label {
        x: Theme.u(15)
        y: Theme.u(13)
        text: "Wallpaper"
        size: Theme.u(12.5)
        font.weight: Font.Medium
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(15)
        y: Theme.u(15)
        text: Config.appearance.theme
        size: Theme.u(8)
        color: Theme.textDim
    }

    Label {
        anchors.centerIn: strip
        visible: strip.count === 0
        text: `No images in ${Wallpaper.dir}`
        size: Theme.u(9)
        color: Theme.textFaint
    }

    Carousel {
        id: strip
        x: Theme.u(4)
        y: Theme.u(46)
        width: parent.width - Theme.u(8)
        height: Theme.u(112)
        itemWidth: Theme.u(128)
        itemHeight: Theme.u(80)
        model: root.files

        delegate: Item {
            id: cell

            required property string modelData
            required property int index
            readonly property bool isSelected: ListView.isCurrentItem
            readonly property bool isCurrent: modelData === Wallpaper.resolved

            width: strip.itemWidth
            height: strip.height

            Item {
                anchors.centerIn: parent
                width: strip.itemWidth
                height: strip.itemHeight
                scale: cell.isSelected ? strip.selectedScale : 1
                Behavior on scale { Anim { curve: "hover" } }
                opacity: strip.emphasis(cell.index)
                Behavior on opacity { Anim { curve: "fade" } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.u(9)
                    color: Theme.surface

                    Image {
                        anchors.fill: parent
                        source: "file://" + cell.modelData
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: Theme.u(300)
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }
                }

                // Selection ring, drawn outside the image.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.u(1.5)
                    radius: Theme.u(10.5)
                    color: "transparent"
                    border.width: Theme.u(1.5)
                    border.color: Theme.accent
                    opacity: cell.isSelected ? 1 : 0
                    Behavior on opacity { Anim { curve: "fade" } }
                }

                // The wallpaper in use.
                Rectangle {
                    visible: cell.isCurrent
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.u(6)
                    width: Theme.u(6)
                    height: width
                    radius: width / 2
                    color: "white"
                    opacity: 0.85
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.3)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cell.isSelected)
                        root.apply();
                    else
                        strip.currentIndex = cell.index;
                }
                onDoubleClicked: {
                    strip.currentIndex = cell.index;
                    root.apply();
                }
            }
        }
    }

    Label {
        x: Theme.u(15)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u(10)
        width: parent.width / 2
        text: Wallpaper.nameOf(root.selectedFile)
        size: Theme.u(8)
        color: Theme.textDim
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(15)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u(10)
        text: strip.count > 0 ? `${strip.currentIndex + 1}/${strip.count}   ·   Enter to apply` : ""
        size: Theme.u(8)
        color: Theme.textDim
    }
}
