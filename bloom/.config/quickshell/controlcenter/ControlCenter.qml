import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// STUB (control center part): a drawer out of the right edge, under the status pill. Tabs:
// Quick (tiles: Wi-Fi, Bluetooth, game mode, silent, stay awake …; volume and brightness
// sliders; lock, wallpapers, keyboard, settings) and App mixer (every app on its GoXLR
// channel, a thin slider each). The mockup's #cc. The task manager lives in the dashboard's
// Performance tab in bloom: tasks() asks for it with tasksRequested().
// Replace the content and keep: open, show(screen), hide(), toggle(screen), the signals and
// the IPC target "controlcenter".
Scope {
    id: root

    signal lockRequested()
    signal wallpapersRequested()
    signal keyboardRequested()
    signal settingsRequested()
    signal tasksRequested()

    property bool open: false
    property ShellScreen screen: null

    function show(screen) {
        root.screen = screen ?? Bloom.focusedScreen;
        open = true;
        // The faders are read more often while the mixer could be on screen
        GoXLR.fast = true;
    }

    function hide() {
        open = false;
        GoXLR.fast = false;
    }

    function toggle(screen) {
        if (open)
            hide();
        else
            show(screen);
    }

    Drawer {
        screen: root.screen
        edge: "right"
        align: "start"
        offset: 70
        open: root.open
        namespace: "qs-controlcenter"
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.medium

            Tabs {
                model: [
                    { key: "quick", label: "Quick", icon: "tune" },
                    { key: "mixer", label: "App mixer", icon: "equalizer" }
                ]
                current: "quick"
            }
            Card {
                Layout.preferredWidth: 394
                Layout.preferredHeight: 220

                StyledText {
                    anchors.centerIn: parent
                    text: "Not built yet (controlcenter/)"
                    dim: true
                }
            }
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show(null);
        }

        function close(): void {
            root.hide();
        }

        // The task manager: the dashboard's Performance tab in bloom
        function tasks(): void {
            root.hide();
            root.tasksRequested();
        }
    }
}
