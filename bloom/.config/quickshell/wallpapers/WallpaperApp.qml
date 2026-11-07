import QtQuick
import Quickshell
import Quickshell.Io

// Super+W, the control center and the launcher share one wallpaper menu.
Scope {
    id: root
    required property var controller
    readonly property bool open: controller.open && controller.wallBig

    function show() { controller.show("wall"); }
    function hide() { if (open) controller.hide(); }
    function toggle() { if (open) hide(); else show(); }

    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
    }
}
