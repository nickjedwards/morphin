import QtQuick
import qs.common

// A horizontal strip that keeps the selected item centred and slides the rest
// past it. The selected item is scaled up rather than resized, so spacing
// stays even while the selection moves; items dim with distance from it.
ListView {
    id: carousel

    property real itemWidth: Theme.u(128)
    property real itemHeight: Theme.u(80)
    property real selectedScale: 1.17

    // Emitted for a click on the selected item (or a double-click anywhere).
    signal activated(int index)

    orientation: ListView.Horizontal
    spacing: Theme.u(28)
    clip: true
    interactive: false
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: (width - itemWidth) / 2
    preferredHighlightEnd: (width + itemWidth) / 2
    highlightMoveDuration: Theme.hoverDuration
    highlightMoveVelocity: -1
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: itemWidth * 4

    function step(delta: int): void {
        if (carousel.count > 0)
            carousel.currentIndex = Math.max(0, Math.min(carousel.count - 1, carousel.currentIndex + delta));
    }

    // How far item `index` is from the selection, for dimming.
    function emphasis(index: int): real {
        const d = Math.abs(index - carousel.currentIndex);
        return d === 0 ? 1 : d === 1 ? 0.8 : d === 2 ? 0.5 : 0.3;
    }

    // Wheel steps one item per notch; trackpads accumulate.
    property real wheelRemainder: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.x !== 0 ? -event.angleDelta.x : -event.angleDelta.y;
            carousel.wheelRemainder += delta;
            while (Math.abs(carousel.wheelRemainder) >= 120) {
                carousel.step(carousel.wheelRemainder > 0 ? 1 : -1);
                carousel.wheelRemainder -= carousel.wheelRemainder > 0 ? 120 : -120;
            }
        }
    }
}
