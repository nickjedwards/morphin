import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.components
import qs.services

// App search: a field on top, results underneath; arrows move, Enter runs.
FocusScope {
    id: root

    signal done

    property string query: ""
    property int selected: 0
    readonly property var results: Apps.search(query)
    readonly property int visibleRows: Math.min(Config.launcher.maxResults, results.length)

    readonly property real rowHeight: Theme.u(35)
    readonly property real searchHeight: Theme.u(38)

    implicitWidth: Theme.u(396)
    implicitHeight: searchHeight + Theme.u(9) + (visibleRows > 0 ? visibleRows * (rowHeight + Theme.u(2)) + Theme.u(6) : Theme.u(30))

    onQueryChanged: selected = 0

    function launchSelected(): void {
        const app = root.results[root.selected];
        if (app) {
            Apps.launch(app);
            root.done();
        }
    }

    Component.onCompleted: field.forceActiveFocus()

    Icon {
        x: Theme.u(15)
        y: (root.searchHeight - height) / 2 + Theme.u(3)
        text: Icons.search
        size: Theme.u(12)
        color: Theme.textDim
    }

    TextInput {
        id: field
        x: Theme.u(35)
        y: Theme.u(3)
        width: parent.width - x - Theme.u(15)
        height: root.searchHeight
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accentMuted
        font.family: Theme.font
        font.pixelSize: Theme.u(11)
        clip: true
        focus: true
        onTextChanged: root.query = text

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: !field.text
            text: "Search…"
            size: Theme.u(11)
            color: Theme.textFaint
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Down:
            case Qt.Key_Tab:
                root.selected = Math.min(root.results.length - 1, root.selected + 1);
                event.accepted = true;
                break;
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                root.selected = Math.max(0, root.selected - 1);
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.launchSelected();
                event.accepted = true;
                break;
            case Qt.Key_Escape:
                root.done();
                event.accepted = true;
                break;
            }
        }
    }

    Rectangle {
        x: Theme.u(12)
        y: root.searchHeight + Theme.u(4)
        width: parent.width - Theme.u(24)
        height: 1
        color: Theme.surface
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.searchHeight + Theme.u(14)
        visible: root.results.length === 0
        text: "No matches"
        size: Theme.u(9)
        color: Theme.textFaint
    }

    ListView {
        id: list
        x: Theme.u(12)
        y: root.searchHeight + Theme.u(10)
        width: parent.width - Theme.u(24)
        height: root.visibleRows * (root.rowHeight + spacing)
        clip: true
        spacing: Theme.u(2)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.selected
        highlightMoveDuration: 120
        highlightFollowsCurrentItem: true
        model: root.results

        highlight: Rectangle {
            radius: Theme.u(9)
            color: Theme.surface

            Rectangle {
                x: -Theme.u(1)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(2.5)
                height: parent.height * 0.55
                radius: width / 2
                color: Theme.accent
            }
        }

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            width: list.width
            height: root.rowHeight

            Rectangle {
                id: iconBox
                x: Theme.u(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u(24)
                height: width
                radius: Theme.u(7)
                color: Theme.cardItem

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Theme.u(16)
                    source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                    asynchronous: true
                }
            }

            Column {
                anchors.left: iconBox.right
                anchors.leftMargin: Theme.u(10)
                anchors.right: parent.right
                anchors.rightMargin: Theme.u(8)
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: row.modelData.name
                    size: Theme.u(9.5)
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    visible: Config.launcher.showDescriptions && text !== ""
                    text: row.modelData.comment || row.modelData.genericName || ""
                    size: Theme.u(7.5)
                    color: Theme.textDim
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = row.index
                onClicked: root.launchSelected()
            }
        }
    }
}
