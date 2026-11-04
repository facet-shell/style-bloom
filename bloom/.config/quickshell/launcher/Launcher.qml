import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config

// STUB (launcher part): an empty drawer out of the bottom edge where the launcher goes
// (the mockup's #launcher: search pill, results, the modes, Claude, the big wallpaper menu).
// Replace the drawer's content and keep the rest: the IPC target and its functions, open,
// show(preset), hide(), and the layer name "qs-launcher" (hypr/frame/shell.lua looks for it
// to send Ctrl+Alt+Q's @ here through `type`). tui's launcher/ has the modes to port.
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null

    // preset: text to start with, e.g. "; " for the clipboard history
    function show(preset) {
        if (!open) {
            screen = Bloom.focusedScreen;
            // Fresh window list, so Enter on a running app finds its window (Apps.windowOf)
            Hyprland.refreshToplevels();
            open = true;
        }
        if (preset)
            field.text = preset;
        field.focusField();
    }

    function hide() {
        open = false;
    }

    function toggle(screen) {
        if (open) {
            hide();
        } else {
            show("");
            if (screen)
                root.screen = screen;
        }
    }

    Drawer {
        screen: root.screen
        edge: "bottom"
        open: root.open
        namespace: "qs-launcher"
        keyboard: WlrKeyboardFocus.Exclusive
        onDismissed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.medium

            SearchField {
                id: field

                Layout.preferredWidth: 684
                placeholder: "Search apps · > for commands · wall for wallpapers"
                hint: "stub"
                onEscaped: root.hide()
            }
            StyledText {
                text: "The bloom launcher is not built yet (launcher/Launcher.qml)."
                dim: true
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show("");
        }

        // Super+V: the clipboard history (frame-clip), like Windows
        function clipboard(): void {
            root.show("; ");
        }

        // Opens with text already typed, e.g. `qs ipc call launcher search "/ notes"`
        function search(text: string): void {
            root.show(text);
        }

        // Opens with that text typed, e.g. `qs ipc call launcher mode "s daft punk"`
        function mode(text: string): void {
            root.show(text);
        }

        // Types into the open launcher; Ctrl+Alt+Q (frame/shell.lua) sends its @ here, the
        // launcher is no window that sendshortcut could reach
        function type(text: string): void {
            if (root.open)
                field.input.insert(field.input.cursorPosition, text);
        }

        function close(): void {
            root.hide();
        }
    }
}
