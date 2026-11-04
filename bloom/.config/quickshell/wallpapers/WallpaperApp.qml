import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The wallpaper app (Super+W): the launcher's big wallpaper menu as its own drawer out of the
// bottom edge. A large preview with "apply", tabs and a grid of tiles beside it, the backend's
// options under them (WallpaperView). The Wallpapers service and frame-wallpaper do the work;
// Backdrop.qml next to this draws the still ones.
// `qs ipc call wallpapers toggle`, also open and close.
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null

    function show() {
        if (open)
            return;
        screen = Bloom.focusedScreen;
        open = true;
        view.reset();
    }

    function hide() {
        open = false;
    }

    Drawer {
        screen: root.screen
        edge: "bottom"
        open: root.open
        namespace: "qs-wallpapers"
        // Opened on purpose (Super+W), so it shows over a fullscreen window too
        windowLayer: WlrLayer.Overlay
        // The search field takes typing
        keyboard: WlrKeyboardFocus.Exclusive
        onDismissed: root.hide()

        WallpaperView {
            id: view

            anchors.fill: parent
            // As wide as the mockup's big menu, narrower on small screens; the joints and the
            // hole's corners stay free
            implicitWidth: Math.min(1180, (root.screen?.width ?? 1920) - Theme.frame.border * 2
                - (Theme.rounding.fillet + Theme.rounding.hole) * 2 - Theme.padding.drawer * 2)
            onCloseRequested: root.hide()
        }
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
