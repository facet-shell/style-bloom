import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// STUB (wallpapers part): the wallpaper app (Super+W). In bloom it is the launcher's big
// wallpaper menu grown out of the bottom edge (the mockup's .wbig: a large preview with
// "apply", tabs All / Still / Moving / Folders, a grid of rounded tiles, fit, moving ones,
// pause in games, "colors from it" = Config.colorMode "dynamic"). The Wallpapers service and
// frame-wallpaper do the work; Backdrop.qml next to this is tui's and already draws the still
// wallpapers. tui's wallpapers/WallpaperView.qml has the app to port.
// Keep: open, show(), hide() and the IPC target "wallpapers".
Scope {
    id: root

    property bool open: false

    function show() {
        console.warn("bloom: the wallpaper app is not built yet (wallpapers/WallpaperApp.qml)");
    }

    function hide() {
        open = false;
    }

    IpcHandler {
        target: "wallpapers"

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
