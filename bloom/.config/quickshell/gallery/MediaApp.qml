import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The media app (Super+G): screenshots and recordings in one grid, filters as chips, many
// deleted at once (into the trash), opened in the editor (MediaView). A real window, so it
// tiles, takes files dropped from Dolphin and closes with Super+Q.
// `qs ipc call media toggle`, also open and close.
Scope {
    id: root

    property bool open: false

    function show() {
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
        title: "facet · media"
        implicitWidth: 1320
        implicitHeight: 860
        color: Theme.page

        // Closed from Hyprland (Super+Q) instead of the close button
        onVisibleChanged: {
            if (!visible && root.open)
                root.hide();
        }

        MediaView {
            id: view

            anchors.fill: parent
            onCloseRequested: root.hide()
        }
    }

    IpcHandler {
        target: "media"

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
