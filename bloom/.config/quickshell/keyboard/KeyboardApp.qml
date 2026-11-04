import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// STUB (keyboard part): the AULA F75 app (Super+K): lighting, Fn keys and per-key colors. In
// bloom a rounded window, the board drawn with round keys, effects as Chips, colors as round
// swatches. tui's keyboard/ has the app to port (Keyboard service, frame-keyboard).
// `mods` already works: Hyprland reports held modifiers through it (hypr/frame/hotkeys.lua).
// Keep: open, show(), hide() and the IPC target "keyboard".
Scope {
    id: root

    property bool open: false

    function show() {
        console.warn("bloom: the keyboard app is not built yet (keyboard/KeyboardApp.qml)");
    }

    function hide() {
        open = false;
    }

    IpcHandler {
        target: "keyboard"

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

        // From Hyprland while modifier keys are held (hypr/frame/hotkeys.lua): "super+shift", "" on release
        function mods(text: string): void {
            Keyboard.setHeldMods(text);
        }
    }
}
