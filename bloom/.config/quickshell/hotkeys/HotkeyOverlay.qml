import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// STUB (hotkeys part): hold Super for 1.5 seconds (hypr/frame/hotkeys.lua opens it, the
// release closes it) and every Super key shows, grouped (Binds). It takes no keyboard focus,
// so Super stays with Hyprland. In bloom a large drawer out of the bottom edge or a rounded
// card in the middle, keys as small rounded caps (Theme.high), groups as Cards. tui's
// hotkeys/ has the layout to port.
// Keep: hidden, open, show(), hide() and the IPC target "hotkeys".
Scope {
    id: root

    property bool hidden: false
    property bool open: false

    function show() {
        open = true;
    }

    function hide() {
        open = false;
    }

    IpcHandler {
        target: "hotkeys"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show();
        }
    }
}
