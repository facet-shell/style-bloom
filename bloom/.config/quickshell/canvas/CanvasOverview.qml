import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// STUB (canvas part): the zoomed-out infinite canvas (facet layout canvas), opened by
// Super+wheel and the canvas button in the bar. In bloom it fills the hole with the surface
// at 70 % over a blur, windows as rounded cards (radius 18, a primary ring on hover), a
// minimap bottom right (the mockup's .canvas). tui's canvas/CanvasOverview.qml has all the
// behavior to keep (zoom around the cursor, drag windows across screens, keys F, Enter, Q).
// CanvasDesk.qml and CanvasThumbs.qml next to this are tui's and already work.
// Keep: hidden, open, show(), close(), zoomIn(), zoomOut() and the IPC target "overview".
Scope {
    id: root

    property bool hidden: false
    property bool open: false

    function show() {
        console.warn("bloom: the canvas overview is not built yet (canvas/CanvasOverview.qml)");
    }

    function close() {
        open = false;
    }

    function zoomIn() {}

    // Super+wheel down opens the overview
    function zoomOut() {
        if (!open)
            show();
    }

    IpcHandler {
        target: "overview"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            if (root.open)
                root.close();
            else
                root.show();
        }

        // Super+wheel from Hyprland: around wherever the cursor is
        function zoomIn(): void {
            root.zoomIn();
        }

        function zoomOut(): void {
            root.zoomOut();
        }
    }
}
