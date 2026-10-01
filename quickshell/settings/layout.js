.pragma library

// Grid layout helpers for the control-center editor. A layout is a list of
// { type, x, y, w, h } in cells. Nothing here mutates its input.

function clone(items) {
    return items.map(it => Object.assign({}, it));
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function fits(placed, it, columns) {
    if (it.x < 0 || it.y < 0 || it.x + it.w > columns)
        return false;
    return !placed.some(p => overlaps(p, it));
}

// First free spot scanning row by row.
function firstFit(placed, it, columns) {
    const w = Math.min(it.w, columns);
    for (let y = 0; y < 200; y++) {
        for (let x = 0; x + w <= columns; x++) {
            const candidate = Object.assign({}, it, { x, y, w });
            if (fits(placed, candidate, columns))
                return candidate;
        }
    }
    return Object.assign({}, it, { x: 0, y: 200, w });
}

// Keep every item inside the grid, then push anything overlapping down.
function normalize(items, columns) {
    const sorted = clone(items).sort((a, b) => a.y - b.y || a.x - b.x);
    const placed = [];
    for (const it of sorted) {
        it.w = Math.min(it.w, columns);
        it.x = Math.max(0, Math.min(it.x, columns - it.w));
        it.y = Math.max(0, it.y);
        while (!fits(placed, it, columns))
            it.y++;
        placed.push(it);
    }
    return placed;
}

// Pull everything up as far as it will go, keeping its column.
function compact(items, columns) {
    const sorted = clone(items).sort((a, b) => a.y - b.y || a.x - b.x);
    const placed = [];
    for (const it of sorted) {
        while (it.y > 0 && fits(placed, Object.assign({}, it, { y: it.y - 1 }), columns))
            it.y--;
        placed.push(it);
    }
    return placed;
}

// Tidy: repack in reading order, filling holes from the top left.
function tidy(items, columns) {
    const sorted = clone(items).sort((a, b) => a.y - b.y || a.x - b.x);
    const placed = [];
    for (const it of sorted)
        placed.push(firstFit(placed, it, columns));
    return placed;
}

// Move (or resize) item `index` to `target`, pushing whatever it lands on
// downwards. Gaps are left alone; that's what Tidy is for.
function place(items, index, target, columns) {
    const moved = Object.assign({}, items[index], target, { _moved: true });
    moved.w = Math.min(moved.w, columns);
    moved.x = Math.max(0, Math.min(moved.x, columns - moved.w));
    moved.y = Math.max(0, moved.y);

    const others = clone(items).filter((_, i) => i !== index).sort((a, b) => a.y - b.y || a.x - b.x);
    const placed = [moved];
    for (const it of others) {
        while (!fits(placed, it, columns))
            it.y++;
        placed.push(it);
    }
    // Put the moved item back at its original index so selection survives.
    const result = placed;
    const at = result.findIndex(it => it._moved);
    const movedResult = result.splice(at, 1)[0];
    delete movedResult._moved;
    result.splice(index, 0, movedResult);
    return result;
}

function add(items, type, size, columns) {
    const it = firstFit(items, { type, x: 0, y: 0, w: size[0], h: size[1] }, columns);
    return items.concat([it]);
}

function remove(items, index, columns) {
    return items.filter((_, i) => i !== index);
}

function rows(items) {
    return items.reduce((m, it) => Math.max(m, it.y + it.h), 0);
}
