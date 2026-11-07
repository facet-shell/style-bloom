import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// One screen's bar, inside the frame's top edge (ScreenFrame sets screen and frameWindow).
//   [logo] [tray]            [ 14:32  Wed 4 Nov ]            [search] [canvas] [bell] [status] [power]
Item {
    id: root

    property ShellScreen screen: null
    property var frameWindow: null
    // The Bar scope: its signals, which panels are out, the menus
    property var bar: null

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Stay awake (control center): one inhibitor is enough, it lives on the first screen
    IdleInhibitor {
        window: root.frameWindow
        enabled: Toggles.stayAwake && root.frameWindow !== null && root.screen === Quickshell.screens[0]
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        IconButton {
            icon: "local_florist"
            size: 38
            iconSize: Theme.icon.large
            iconColor: Theme.primary
            active: root.bar?.dashboardOpen ?? false
            onClicked: root.bar.dashboardRequested(root.screen)
        }

        Tray {
            screen: root.screen
            menu: root.bar?.trayMenu ?? null
        }

        VoicePill {
            Layout.maximumWidth: Math.max(0, (root.width / 2) - 300)
            availableWidth: Math.max(0, (root.width / 2) - 300)
        }
    }

    // The clock in the middle of the screen, whatever the sides hold
    Pill {
        anchors.centerIn: parent
        interactive: true
        active: root.bar?.dashboardOpen ?? false
        padding: 16
        onClicked: root.bar.dashboardRequested(root.screen)

        StyledText {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            tabular: true
            font.weight: Font.DemiBold
        }
        StyledText {
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            dim: true
            font.pixelSize: Theme.size.small
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        IconButton {
            icon: "search"
            active: root.bar?.launcherOpen ?? false
            onClicked: root.bar.launcherRequested(root.screen)
        }

        // Only with the infinite canvas (facet layout canvas); Super+wheel does the same
        IconButton {
            visible: CanvasLayout.enabled
            icon: "grid_view"
            active: root.bar?.overviewOpen ?? false
            onClicked: root.bar.overviewRequested(root.screen)
        }

        IconButton {
            icon: "notifications"
            active: root.bar?.historyOpen ?? false
            badge: Notifications.missed > 0
            onClicked: root.bar.historyRequested(root.screen)
        }

        StatusPill {
            Layout.leftMargin: 4
            active: root.bar?.controlCenterOpen ?? false
            onClicked: root.bar.controlCenterRequested(root.screen)
        }

        IconButton {
            id: power

            icon: "power_settings_new"
            iconColor: Theme.error
            active: (root.bar?.powerMenu.open ?? false) && root.bar.powerMenu.anchorItem === power
            onClicked: {
                const menu = root.bar.powerMenu;
                if (menu.open && menu.anchorItem === power)
                    menu.open = false;
                else
                    menu.popup(root.screen, power);
            }
        }
    }
}
