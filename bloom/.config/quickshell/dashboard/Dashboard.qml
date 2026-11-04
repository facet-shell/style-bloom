import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config

// STUB (dashboard part, new in bloom): a drawer out of the top edge, under the clock, opened
// by the logo and the clock in the bar. Tabs: Dashboard (weather with the next hours, media,
// GitHub in short, calendar, the next timer), Media (big cover, controls, lyrics line),
// GitHub (you or an organisation: PRs, CI, reviews, the year as squares), Performance (CPU,
// GPU, RAM, temperature as gauges, the task manager). The mockup's #dash.
// Replace the content and keep: open, tab, show(screen, tab), hide(), toggle(screen) and the
// IPC target "dashboard". `qs ipc call controlcenter tasks` lands here on "performance".
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null
    // home, media, github or performance
    property string tab: "home"

    function show(screen, tab) {
        root.screen = screen ?? Bloom.focusedScreen;
        if (tab)
            root.tab = tab;
        open = true;
    }

    function hide() {
        open = false;
    }

    function toggle(screen) {
        if (open)
            hide();
        else
            show(screen, "");
    }

    Drawer {
        screen: root.screen
        edge: "top"
        open: root.open
        namespace: "qs-dashboard"
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.large

            Tabs {
                Layout.alignment: Qt.AlignHCenter
                model: [
                    { key: "home", label: "Dashboard", icon: "dashboard" },
                    { key: "media", label: "Media", icon: "music_note" },
                    { key: "github", label: "GitHub", icon: "commit" },
                    { key: "performance", label: "Performance", icon: "monitoring" }
                ]
                current: root.tab
                onSelected: key => root.tab = key
            }
            Card {
                Layout.preferredWidth: 864
                Layout.preferredHeight: 280

                StyledText {
                    anchors.centerIn: parent
                    text: `The dashboard is not built yet (dashboard/Dashboard.qml) · ${root.tab}`
                    dim: true
                }
            }
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show(null, "");
        }

        function close(): void {
            root.hide();
        }

        // home, media, github or performance
        function tab(name: string): void {
            root.show(null, name);
        }
    }
}
