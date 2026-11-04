import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// STUB (notifications part): the notification history, opened by the bell in the bar. Here a
// drawer out of the right edge; where it goes and how it looks is the notifications part's
// call (Notifications.history, markSeen(), clearHistory()).
// Keep: open, show(screen), hide(), toggle(screen) and the IPC target "notifications".
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null

    function show(screen) {
        root.screen = screen ?? Bloom.focusedScreen;
        open = true;
        Notifications.markSeen();
    }

    function hide() {
        open = false;
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
        namespace: "qs-notification-history"
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()

        ColumnLayout {
            anchors.fill: parent

            StyledText {
                Layout.preferredWidth: 360
                text: `${Notifications.history.length} in the history; not built yet (notifications/History.qml)`
                dim: true
                wrapMode: Text.WordWrap
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show(null);
        }

        function close(): void {
            root.hide();
        }
    }
}
