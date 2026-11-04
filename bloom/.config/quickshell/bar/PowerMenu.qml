import QtQuick
import Quickshell
import qs.components
import qs.config

// The power button's menu, out of the bar: lock, sleep, and log out, restart and shut down,
// which ask for a second click (the row turns red and says so for 3 seconds).
BarMenu {
    id: root

    // The action that waits for its second click
    property string armed: ""

    signal lockRequested()

    namespace: "qs-power-menu"
    menuWidth: 220
    title: "Power"
    entries: [
        { key: "lock", text: "Lock", icon: "lock" },
        { key: "suspend", text: "Sleep", icon: "bedtime" },
        { separator: true },
        { key: "logout", text: armed === "logout" ? "Log out? Click again" : "Log out", icon: "logout", danger: armed === "logout" },
        { key: "reboot", text: armed === "reboot" ? "Restart? Click again" : "Restart", icon: "restart_alt", danger: armed === "reboot" },
        { key: "poweroff", text: armed === "poweroff" ? "Shut down? Click again" : "Shut down", icon: "power_settings_new", danger: true }
    ]

    readonly property var commands: ({
        suspend: ["systemctl", "suspend"],
        logout: ["hyprctl", "dispatch", "hl.dsp.exit()"],
        reboot: ["systemctl", "reboot"],
        poweroff: ["systemctl", "poweroff"]
    })

    onOpenChanged: armed = ""

    onActivated: (index, entry) => {
        if (entry.key === "lock") {
            open = false;
            // Once the menu is in, so the lockscreen's snapshot does not show it
            lockLater.restart();
        } else if (entry.key === "suspend" || armed === entry.key) {
            // Sleep locks first by itself (lockscreen/Lock.qml listens to logind)
            open = false;
            Quickshell.execDetached(commands[entry.key]);
        } else {
            armed = entry.key;
            disarm.restart();
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    Timer {
        id: lockLater
        interval: Theme.anim.drawerOut + 80
        onTriggered: root.lockRequested()
    }
}
