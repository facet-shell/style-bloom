import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// STUB (gallery part): the media app (Super+G), screenshots and recordings in one grid, filters
// as Chips, many deleted at once (into the trash), opened in the editor. In bloom a rounded
// window with tiles that spring a little on hover, the picked ones with a primary ring.
// tui's gallery/ has the app to port.
// Keep: open, show(), hide() and the IPC target "media".
Scope {
    id: root

    property bool open: false

    function show() {
        console.warn("bloom: the media app is not built yet (gallery/MediaApp.qml)");
    }

    function hide() {
        open = false;
    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }
    }
}
