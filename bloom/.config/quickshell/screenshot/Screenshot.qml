import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

// STUB (screenshot part): Print freezes the screens, you drag a region or click a window,
// Enter takes the screen, Esc cancels; Super+Shift+R picks what to record (Recorder). In
// bloom the picker's toolbar is a Drawer out of the bottom edge with SegmentedButtons
// (region, window, screen; picture or recording). tui's screenshot/Screenshot.qml has the
// capture side (grim, the frozen frame, ffmpeg, the notification with open / folder /
// delete) to keep. Stopping a recording already works here.
// Keep: hidden, open, recordMode, show(), close(), captureOutput(name) and the IPC target
// "screenshot".
Scope {
    id: root

    property bool hidden: false
    property bool open: false
    property bool recordMode: false

    function show() {
        console.warn(`bloom: the screenshot picker is not built yet (screenshot/Screenshot.qml)${recordMode ? ", recording" : ""}`);
    }

    function close() {
        open = false;
    }

    function captureOutput(name) {
        console.warn(`bloom: screenshots are not built yet (screen ${name})`);
    }

    IpcHandler {
        target: "screenshot"

        function region(): void {
            root.recordMode = false;
            root.show();
        }

        // Pick what to record; while a recording runs, the same call stops it
        function record(): void {
            if (Recorder.recording) {
                Recorder.stop();
                return;
            }
            root.recordMode = true;
            root.show();
        }

        function toggle(): void {
            if (root.open)
                root.close();
            else
                root.show();
        }

        // The focused screen, no questions asked
        function screen(): void {
            const name = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
            if (name !== "")
                root.captureOutput(name);
        }

        function close(): void {
            root.close();
        }
    }
}
