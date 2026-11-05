import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The settings as their own window: Super+, or "settings" in the control center,
// `qs ipc call settings toggle`, `qs ipc call settings section sound` (a category, or a
// page as "shell/weather"). The content is SettingsView: the categories as pills on the
// left, the picked one's menu or page on the right.
Scope {
    id: root

    property bool open: false

    signal wallpapersRequested()
    signal keyboardRequested()

    function show(section) {
        if (section)
            view.goTo(section);
        open = true;
        view.refresh();
        view.forceActiveFocus();
    }

    function hide() {
        open = false;
    }

    FloatingWindow {
        id: window

        visible: root.open
        title: "facet · settings"
        implicitWidth: 1120
        implicitHeight: 760
        color: Theme.surface

        // Closed from Hyprland (Super+Q) instead of the close button
        onVisibleChanged: {
            if (!visible && root.open)
                root.hide();
            else if (visible)
                view.arrive();
        }

        SettingsView {
            id: view

            anchors.fill: parent
            focus: true
            onCloseRequested: root.hide()
            onWallpapersRequested: root.wallpapersRequested()
            onKeyboardRequested: root.keyboardRequested()
        }
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
