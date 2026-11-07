pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The few settings the login screen needs, in place of core's Config: Theme.qml reads
// corners, animations and colorMode, the backdrop lockBlur. The greeter user cannot read
// ~/.config/facet/shell.json, so `facet login` may copy those keys into greeter.json;
// without them it looks like the defaults.
Singleton {
    id: root

    property var user: ({})

    // The wallpaper's colors live in your home too, so always the theme's
    readonly property string colorMode: "theme"
    readonly property string corners: user.corners ?? "round"
    readonly property string animations: user.animations ?? "full"
    readonly property real lockBlur: user.lockBlur ?? 1.0

    FileView {
        // One folder up: greeter.json sits next to shell.qml
        path: Qt.resolvedUrl("../greeter.json").toString().replace("file://", "")
        printErrors: false
        onLoaded: {
            try {
                root.user = JSON.parse(text()) ?? {};
            } catch (e) {
                root.user = {};
            }
        }
    }
}
