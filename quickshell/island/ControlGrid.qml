import QtQuick
import qs.common

// The control center's layout: controls placed on a grid of round cells.
// A 1×1 cell is exactly the round lock button; a tile spans three.
Item {
    id: grid

    property int columns: Config.controlCenter.columns
    property var items: Config.controlCenter.items
    property bool interactive: true

    readonly property real cell: Theme.u(46)
    readonly property real gap: Theme.u(9)
    readonly property int rows: items.reduce((m, it) => Math.max(m, it.y + it.h), 0)

    signal pageRequested(string page, rect source)

    implicitWidth: columns * cell + (columns - 1) * gap
    implicitHeight: rows > 0 ? rows * cell + (rows - 1) * gap : cell

    function span(n: int): real {
        return n * grid.cell + (n - 1) * grid.gap;
    }
    function rectOf(it): rect {
        const w = Math.min(it.w, grid.columns);
        const x = Math.min(it.x, grid.columns - w);
        return Qt.rect(x * (grid.cell + grid.gap), it.y * (grid.cell + grid.gap), grid.span(w), grid.span(it.h));
    }
    function sourceFor(page: string): rect {
        const it = grid.items.find(i => Controls.info(i.type).page === page);
        return it ? grid.rectOf(it) : Qt.rect(grid.width / 2 - grid.cell / 2, 0, grid.cell, grid.cell);
    }

    Repeater {
        model: grid.items

        delegate: ControlItem {
            required property var modelData
            readonly property rect r: grid.rectOf(modelData)

            x: r.x
            y: r.y
            width: r.width
            height: r.height
            type: modelData.type
            interactive: grid.interactive
            onPageRequested: page => grid.pageRequested(page, r)
        }
    }
}
