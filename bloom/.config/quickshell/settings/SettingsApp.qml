import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// STUB (settings part): the settings as their own window (Super+,), in bloom a rounded window
// with the nav on the left (Look, Notifications, Popups, Games, Sound, System) like the
// mockup's #settings: themes as swatch cards plus "From the wallpaper" (Config.colorMode),
// corners and animations (Config.corners, Config.animations), per popup its size and
// "compact in a game" (CONTRACT.md lists the keys), the notification rules, the game list.
// tui's settings/SettingsView.qml has every setting to port.
// Keep: open, show(section), hide(), the two signals and the IPC target "settings".
Scope {
    id: root

    property bool open: false

    signal wallpapersRequested()
    signal keyboardRequested()

    function show(section) {
        console.warn(`bloom: the settings are not built yet (settings/SettingsApp.qml)${section ? ", section " + section : ""}`);
    }

    function hide() {
        open = false;
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show("");
        }

        function open(): void {
            root.show("");
        }

        function section(name: string): void {
            root.show(name);
        }

        function close(): void {
            root.hide();
        }
    }
}
