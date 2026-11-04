import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// STUB (draw part): Super+P, drawing on the live desktop. In bloom the toolbar is a Drawer
// out of the bottom edge of the focused screen (IconButtons for the tools, the color as a
// round swatch, SegmentedButtons for the width). tui's draw/ has the engine (DrawCanvas,
// DrawDoc with draw.json, DrawEngine.js, the canvas coordinates) to keep as it is and the
// toolbar to restyle.
// Keep: hidden, open, show(), hide(), toggle() and the IPC target "draw".
Scope {
    id: root

    property bool hidden: false
    property bool open: false

    function show() {
        console.warn("bloom: drawing is not built yet (draw/DrawOverlay.qml)");
    }

    function hide() {
        open = false;
    }

    function toggle() {
        if (open)
            hide();
        else
            show();
    }

    IpcHandler {
        target: "draw"

        function toggle(): void {
            root.toggle();
        }

        function show(): void {
            root.show();
        }

        function hide(): void {
            root.hide();
        }

        // Super+Shift+P; undo brings it back while drawing
        function clear(): void {}

        function through(): void {}
    }
}
