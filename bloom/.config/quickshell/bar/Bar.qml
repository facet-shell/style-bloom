import QtQuick
import Quickshell
import qs.components

// The bar: the top edge of the frame on every screen (ScreenFrame). From the left: the logo
// and the clock open the dashboard, the system tray (only apps with a tray icon; gone while
// there are none), then on the right the launcher, the canvas overview, the bell, the status
// pill (network, volume, mic, battery; opens the control center) and power. No workspaces and
// no window list: the canvas overview is where windows are found.
//
// shell.qml routes the requests to the parts and tells the bar which ones are out, so their
// buttons are drawn "on". While `hidden` (the lockscreen) the frame and the bar step away.
Scope {
    id: root

    property bool hidden: false
    property bool dashboardOpen: false
    property bool controlCenterOpen: false
    property bool launcherOpen: false
    property bool historyOpen: false
    property bool overviewOpen: false

    readonly property var trayMenu: trayMenuDrawer
    readonly property var powerMenu: powerMenuDrawer

    signal dashboardRequested(var screen)
    signal controlCenterRequested(var screen)
    signal launcherRequested(var screen)
    signal historyRequested(var screen)
    signal overviewRequested(var screen)
    signal lockRequested()

    ScreenFrame {
        hidden: root.hidden

        bar: Component {
            BarContent {
                bar: root
            }
        }
    }

    // One of each for all screens: they open on the screen whose button was clicked
    TrayMenu {
        id: trayMenuDrawer
    }

    PowerMenu {
        id: powerMenuDrawer
        onLockRequested: root.lockRequested()
    }

    // The menus go with the bar
    onHiddenChanged: {
        if (hidden) {
            trayMenuDrawer.open = false;
            powerMenuDrawer.open = false;
        }
    }
}
