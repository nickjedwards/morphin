import QtQuick
import qs.common
import qs.components

// Theme search and carousel. Typing filters; arrows move; Enter applies.
FocusScope {
    id: root

    signal done

    property string query: ""
    readonly property var themes: {
        const q = query.trim().toLowerCase();
        return Themes.list.filter(t => !q || t.id.includes(q)).map(t => Themes.resolve(t));
    }
    readonly property var selected: themes[strip.currentIndex] ?? null

    implicitWidth: Theme.u(660)
    implicitHeight: Theme.u(181)

    Component.onCompleted: {
        strip.currentIndex = Math.max(0, themes.findIndex(t => t.id === Config.appearance.theme));
        strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
        field.forceActiveFocus();
    }

    onQueryChanged: {
        const at = themes.findIndex(t => t.id === Config.appearance.theme);
        strip.currentIndex = query ? 0 : Math.max(0, at);
    }

    function apply(): void {
        if (!root.selected)
            return;
        Themes.apply(root.selected.id);
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 450
        onTriggered: root.done()
    }

    function mixed(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    Icon {
        x: Theme.u(15)
        y: Theme.u(12)
        height: Theme.u(20)
        text: Icons.search
        size: Theme.u(11)
        color: Theme.textDim
    }

    TextInput {
        id: field
        x: Theme.u(35)
        y: Theme.u(12)
        width: parent.width - x - Theme.u(60)
        height: Theme.u(20)
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accentMuted
        font.family: Theme.font
        font.pixelSize: Theme.u(10.5)
        clip: true
        focus: true
        onTextChanged: root.query = text

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: !field.text
            text: "Search themes…"
            size: Theme.u(10.5)
            color: Theme.textFaint
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_Backtab:
                strip.step(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_Tab:
                strip.step(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.apply();
                break;
            case Qt.Key_Escape:
                if (field.text)
                    field.text = "";
                else
                    root.done();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(15)
        y: Theme.u(12)
        height: Theme.u(20)
        text: strip.count > 0 ? `${strip.currentIndex + 1}/${strip.count}` : "0/0"
        size: Theme.u(8)
        color: Theme.textDim
    }

    Label {
        anchors.centerIn: strip
        visible: strip.count === 0
        text: "No themes match"
        size: Theme.u(9)
        color: Theme.textFaint
    }

    Carousel {
        id: strip
        x: Theme.u(4)
        y: Theme.u(44)
        width: parent.width - Theme.u(8)
        height: Theme.u(104)
        itemWidth: Theme.u(150)
        itemHeight: Theme.u(79)
        selectedScale: 1.04
        spacing: Theme.u(9)
        model: root.themes

        delegate: Item {
            id: cell

            required property var modelData
            required property int index
            readonly property bool isSelected: ListView.isCurrentItem
            readonly property bool isCurrent: modelData.id === Config.appearance.theme
            readonly property color cardColor: root.mixed(modelData.bg, modelData.fg, 0.06)

            width: strip.itemWidth
            height: strip.height

            Rectangle {
                anchors.centerIn: parent
                width: strip.itemWidth
                height: strip.itemHeight
                radius: Theme.u(10)
                // Each card wears its own theme's background.
                color: cell.isSelected ? root.mixed(cell.modelData.bg, cell.modelData.fg, 0.1) : cell.cardColor
                border.width: Theme.u(1.5)
                border.color: cell.isSelected ? cell.modelData.accent : "transparent"
                scale: cell.isSelected ? strip.selectedScale : 1
                Behavior on scale { Anim { curve: "hover" } }
                opacity: strip.emphasis(cell.index)
                Behavior on opacity { Anim { curve: "fade" } }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.3
                    spacing: Theme.u(3)

                    Repeater {
                        model: cell.modelData.colors
                        delegate: Rectangle {
                            required property color modelData
                            width: Theme.u(11)
                            height: width
                            radius: width / 2
                            color: modelData
                        }
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.62
                    text: cell.modelData.id
                    size: Theme.u(8.5)
                    font.weight: Font.DemiBold
                    color: root.mixed(cell.modelData.fg, cell.cardColor, 0.15)
                }

                // The theme in use.
                Rectangle {
                    visible: cell.isCurrent
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.u(6)
                    width: Theme.u(5)
                    height: width
                    radius: width / 2
                    color: cell.modelData.fg
                    opacity: 0.7
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
            }
        }
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.u(15)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u(10)
        text: "Enter to apply"
        size: Theme.u(8)
        color: Theme.textFaint
    }
}
