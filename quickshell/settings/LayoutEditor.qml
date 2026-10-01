import QtQuick
import qs.common
import qs.components
import qs.island
import "layout.js" as Layout

// The control-center layout editor: the real controls, drawn inert, on the
// same grid the island uses. Drag a control to move it, pull its corner to
// resize, right-click for every size it supports.
FocusScope {
    id: editor

    readonly property int columns: Config.controlCenter.columns
    readonly property var items: Config.controlCenter.items
    property int selected: -1
    property var undoStack: []

    readonly property real cell: Theme.u(46)
    readonly property real gap: Theme.u(9)
    readonly property real pitch: cell + gap
    readonly property int rows: Layout.rows(items)

    // Drag preview: where the selected control would land.
    property var ghost: null

    implicitHeight: column.implicitHeight

    function commit(next): void {
        editor.undoStack = editor.undoStack.concat([JSON.stringify(editor.items)]).slice(-50);
        Config.controlCenter.items = next;
    }
    function undo(): void {
        if (editor.undoStack.length === 0)
            return;
        Config.controlCenter.items = JSON.parse(editor.undoStack[editor.undoStack.length - 1]);
        editor.undoStack = editor.undoStack.slice(0, -1);
        editor.selected = -1;
    }
    function setColumns(n: int): void {
        editor.undoStack = editor.undoStack.concat([JSON.stringify(editor.items)]);
        const next = Layout.normalize(editor.items.map(it => {
            const size = Controls.snapSize(it.type, it.w, it.h, n);
            return Object.assign({}, it, { w: size[0], h: size[1] });
        }), n);
        Config.controlCenter.columns = n;
        Config.controlCenter.items = next;
    }
    function moveTo(index: int, target): void {
        editor.commit(Layout.place(editor.items, index, target, editor.columns));
    }
    function remove(index: int): void {
        editor.commit(Layout.remove(editor.items, index, editor.columns));
        editor.selected = -1;
    }
    function stepSize(index: int, dir: int): void {
        const it = editor.items[index];
        const sizes = Controls.sizesFor(it.type, editor.columns);
        const at = sizes.findIndex(s => s[0] === it.w && s[1] === it.h);
        const next = sizes[Math.max(0, Math.min(sizes.length - 1, (at < 0 ? 0 : at) + dir))];
        if (next)
            editor.moveTo(index, { w: next[0], h: next[1] });
    }
    function rectOf(it): rect {
        return Qt.rect(it.x * editor.pitch, it.y * editor.pitch, it.w * editor.pitch - editor.gap, it.h * editor.pitch - editor.gap);
    }
    function radiusFor(it): real {
        return Math.min((it.h * editor.pitch - editor.gap) / 2, Theme.u(22));
    }

    Keys.onPressed: event => {
        const i = editor.selected;
        if (i < 0 || i >= editor.items.length)
            return;
        const it = editor.items[i];
        switch (event.key) {
        case Qt.Key_Left:
            editor.moveTo(i, { x: it.x - 1 });
            break;
        case Qt.Key_Right:
            editor.moveTo(i, { x: it.x + 1 });
            break;
        case Qt.Key_Up:
            editor.moveTo(i, { y: it.y - 1 });
            break;
        case Qt.Key_Down:
            editor.moveTo(i, { y: it.y + 1 });
            break;
        case Qt.Key_BracketLeft:
            editor.stepSize(i, -1);
            break;
        case Qt.Key_BracketRight:
            editor.stepSize(i, 1);
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            editor.remove(i);
            break;
        case Qt.Key_Escape:
            editor.selected = -1;
            break;
        default:
            if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))
                editor.undo();
            else
                return;
        }
        event.accepted = true;
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.u(8)

        // ── Toolbar ──────────────────────────────────────────────────
        Label {
            x: Theme.u(2)
            text: "Layout"
            size: Theme.u(7.5)
            color: Theme.textDim
        }

        Item {
            width: parent.width
            height: Theme.u(20)

            Row {
                spacing: Theme.u(5)

                Rectangle {
                    width: colRow.implicitWidth + Theme.u(4)
                    height: Theme.u(20)
                    radius: height / 2
                    color: Theme.surface

                    Row {
                        id: colRow
                        x: Theme.u(2)
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [5, 6, 7, 8, 9]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool current: editor.columns === modelData
                                width: Theme.u(16)
                                height: width
                                radius: width / 2
                                color: current ? Theme.accent : colMouse.containsMouse ? Theme.surfaceHover : "transparent"

                                Label {
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    size: Theme.u(7.5)
                                    font.weight: Font.DemiBold
                                    color: parent.current ? Theme.accentInk : Theme.text
                                }
                                MouseArea {
                                    id: colMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editor.setColumns(parent.modelData)
                                }
                            }
                        }
                    }
                }
                PillButton {
                    text: "Tidy"
                    size: Theme.u(7.5)
                    onClicked: editor.commit(Layout.tidy(editor.items, editor.columns))
                }
                PillButton {
                    text: "Undo"
                    size: Theme.u(7.5)
                    opacity: editor.undoStack.length > 0 ? 1 : 0.5
                    onClicked: editor.undo()
                }
                PillButton {
                    text: "Reset"
                    size: Theme.u(7.5)
                    onClicked: {
                        editor.undoStack = editor.undoStack.concat([JSON.stringify(editor.items)]);
                        Config.controlCenter.columns = 7;
                        Config.controlCenter.items = Config.defaultLayout;
                        editor.selected = -1;
                    }
                }
            }

            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Drag to move · corner to resize · right-click for sizes"
                size: Theme.u(7)
                color: Theme.textDim
            }
        }

        // ── Grid ─────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: board.height + Theme.u(12)

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    editor.selected = -1;
                    sizeMenu.visible = false;
                }
            }

            Item {
                id: board
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u(6)
                width: editor.columns * editor.pitch - editor.gap
                height: (editor.rows + 1) * editor.pitch - editor.gap

                // Empty slots, one round cell each, with a spare row.
                Repeater {
                    model: editor.columns * (editor.rows + 1)
                    delegate: Rectangle {
                        required property int index
                        x: (index % editor.columns) * editor.pitch
                        y: Math.floor(index / editor.columns) * editor.pitch
                        width: editor.cell
                        height: editor.cell
                        radius: width / 2
                        color: Theme.card
                        opacity: 0.55
                    }
                }

                // Where a drag would drop.
                Rectangle {
                    visible: editor.ghost !== null
                    readonly property rect r: editor.ghost ? editor.rectOf(editor.ghost) : Qt.rect(0, 0, 0, 0)
                    x: r.x
                    y: r.y
                    width: r.width
                    height: r.height
                    radius: editor.ghost ? editor.radiusFor(editor.ghost) : 0
                    color: Theme.accentSoft
                    border.width: Theme.u(1.5)
                    border.color: Theme.accentMuted
                }

                Repeater {
                    model: editor.items

                    delegate: Item {
                        id: tile

                        required property var modelData
                        required property int index
                        readonly property rect r: editor.rectOf(modelData)
                        readonly property bool isSelected: editor.selected === index
                        property bool dragging: false
                        property point grab

                        x: r.x
                        y: r.y
                        width: r.width
                        height: r.height
                        z: dragging ? 10 : isSelected ? 5 : 1

                        Behavior on x { enabled: !tile.dragging; Anim { curve: "fade" } }
                        Behavior on y { enabled: !tile.dragging; Anim { curve: "fade" } }

                        ControlItem {
                            anchors.fill: parent
                            type: tile.modelData.type
                            interactive: false
                            opacity: tile.dragging ? 0.85 : 1
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Theme.u(2)
                            radius: editor.radiusFor(tile.modelData) + Theme.u(2)
                            color: "transparent"
                            border.width: Theme.u(1.5)
                            border.color: Theme.accent
                            visible: tile.isSelected
                        }

                        MouseArea {
                            id: body
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            preventStealing: true

                            onPressed: mouse => {
                                editor.selected = tile.index;
                                editor.forceActiveFocus();
                                sizeMenu.visible = false;
                                if (mouse.button === Qt.RightButton) {
                                    const p = mapToItem(board, mouse.x, mouse.y);
                                    sizeMenu.open(tile.index, p.x, p.y);
                                    return;
                                }
                                tile.grab = Qt.point(mouse.x, mouse.y);
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || !(pressedButtons & Qt.LeftButton))
                                    return;
                                if (!tile.dragging && Math.hypot(mouse.x - tile.grab.x, mouse.y - tile.grab.y) < Theme.u(4))
                                    return;
                                tile.dragging = true;
                                const p = mapToItem(board, mouse.x - tile.grab.x, mouse.y - tile.grab.y);
                                tile.x = p.x;
                                tile.y = p.y;
                                const gx = Math.max(0, Math.min(editor.columns - tile.modelData.w, Math.round(p.x / editor.pitch)));
                                const gy = Math.max(0, Math.round(p.y / editor.pitch));
                                editor.ghost = Object.assign({}, tile.modelData, { x: gx, y: gy });
                            }
                            onReleased: {
                                if (tile.dragging && editor.ghost) {
                                    const g = editor.ghost;
                                    editor.ghost = null;
                                    tile.dragging = false;
                                    tile.x = Qt.binding(() => tile.r.x);
                                    tile.y = Qt.binding(() => tile.r.y);
                                    editor.moveTo(tile.index, { x: g.x, y: g.y });
                                }
                                tile.dragging = false;
                            }
                        }

                        // Remove badge
                        Rectangle {
                            visible: tile.isSelected && !tile.dragging
                            x: -Theme.u(5)
                            y: -Theme.u(5)
                            width: Theme.u(13)
                            height: width
                            radius: width / 2
                            color: Theme.danger

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.5
                                height: Math.max(1.5, Theme.u(1.5))
                                radius: height / 2
                                color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.u(3)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: editor.remove(tile.index)
                            }
                        }

                        // Resize handle
                        Rectangle {
                            id: handle
                            visible: tile.isSelected && !tile.dragging
                            x: parent.width - width / 2 - Theme.u(3)
                            y: parent.height - height / 2 - Theme.u(3)
                            width: Theme.u(11)
                            height: width
                            radius: width / 2
                            color: Theme.accent
                            border.width: Theme.u(2)
                            border.color: Theme.bg

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.u(4)
                                cursorShape: Qt.SizeFDiagCursor
                                preventStealing: true
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    const p = mapToItem(board, mouse.x, mouse.y);
                                    const w = Math.max(1, Math.round((p.x - tile.r.x + editor.gap) / editor.pitch));
                                    const h = Math.max(1, Math.round((p.y - tile.r.y + editor.gap) / editor.pitch));
                                    const size = Controls.snapSize(tile.modelData.type, w, h, editor.columns);
                                    editor.ghost = Object.assign({}, tile.modelData, { w: size[0], h: size[1] });
                                }
                                onReleased: {
                                    const g = editor.ghost;
                                    editor.ghost = null;
                                    if (g && (g.w !== tile.modelData.w || g.h !== tile.modelData.h))
                                        editor.moveTo(tile.index, { w: g.w, h: g.h });
                                }
                            }
                        }
                    }
                }

                // Right-click: every size this control comes in.
                Rectangle {
                    id: sizeMenu

                    property int target: -1
                    readonly property var sizes: target >= 0 && target < editor.items.length ? Controls.sizesFor(editor.items[target].type, editor.columns) : []

                    function open(index: int, px: real, py: real): void {
                        sizeMenu.target = index;
                        sizeMenu.x = Math.min(px, board.width - width);
                        sizeMenu.y = py;
                        sizeMenu.visible = true;
                    }

                    visible: false
                    z: 100
                    width: Theme.u(150)
                    height: sizeFlow.implicitHeight + Theme.u(12)
                    radius: Theme.u(10)
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.surface

                    Flow {
                        id: sizeFlow
                        x: Theme.u(6)
                        y: Theme.u(6)
                        width: parent.width - Theme.u(12)
                        spacing: Theme.u(4)

                        Repeater {
                            model: sizeMenu.sizes
                            delegate: PillButton {
                                required property var modelData
                                readonly property var it: editor.items[sizeMenu.target]
                                text: `${modelData[0]}×${modelData[1]}`
                                size: Theme.u(7.5)
                                primary: it && it.w === modelData[0] && it.h === modelData[1]
                                onClicked: {
                                    editor.moveTo(sizeMenu.target, { w: modelData[0], h: modelData[1] });
                                    sizeMenu.visible = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Add ──────────────────────────────────────────────────────
        Label {
            x: Theme.u(2)
            text: "Add a control"
            size: Theme.u(7.5)
            color: Theme.textDim
        }

        Flow {
            width: parent.width
            spacing: Theme.u(5)

            Repeater {
                model: Controls.order.filter(t => !editor.items.some(it => it.type === t))

                delegate: Rectangle {
                    required property string modelData
                    readonly property var info: Controls.info(modelData)

                    width: addRow.implicitWidth + Theme.u(18)
                    height: Theme.u(22)
                    radius: height / 2
                    color: addMouse.containsMouse ? Theme.surfaceHover : Theme.surface

                    Row {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: Theme.u(5)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.info.icon
                            size: Theme.u(9)
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.info.label
                            size: Theme.u(8.5)
                            font.weight: Font.Medium
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${parent.parent.info.size[0]}×${parent.parent.info.size[1]}`
                            size: Theme.u(7)
                            color: Theme.textDim
                        }
                    }
                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const size = Controls.snapSize(parent.modelData, parent.info.size[0], parent.info.size[1], editor.columns);
                            editor.commit(Layout.add(editor.items, parent.modelData, size, editor.columns));
                            editor.selected = editor.items.length - 1;
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            text: "Drag a control to move it, pull its corner to resize, right-click for every size it supports. With one selected: arrows nudge, [ and ] step through sizes, Delete removes."
            size: Theme.u(7)
            color: Theme.textDim
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
    }
}
