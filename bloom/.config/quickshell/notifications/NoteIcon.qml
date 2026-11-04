import QtQuick
import qs.components
import qs.config

// A notification's picture: the sender's avatar or the app's icon (entry.image is a path, a
// URL or an icon name), a symbol for the shell's own ✓ / ✕ notices, or the first letter.
// A ringing call sends two green rings out of it until it is answered.
//
//   NoteIcon { entry: modelData; size: 46; ripple: entry.kind === "call" }
Item {
    id: root

    required property var entry
    property real size: 46
    property bool round: false
    property bool ripple: false

    readonly property string image: entry.image ?? ""
    readonly property bool isPath: /^(\/|file:|https?:|image:|qrc:)/.test(image)
    // The services' glyphs for their own notices, as symbols
    readonly property var symbols: ({ "✓": "check", "✕": "close", "✗": "close", "★": "star", "↓": "download" })
    readonly property string symbol: image === "" ? (symbols[entry.glyph] ?? "") : ""
    readonly property real radius: round ? size / 2 : Math.round(size * 0.35)

    implicitWidth: size
    implicitHeight: size

    AppIcon {
        id: picture

        anchors.fill: parent
        visible: root.symbol === ""
        size: root.size
        round: root.round
        // Absolute paths need file:// and their parts escaped (spaces in screenshot names)
        source: root.isPath ? (root.image.startsWith("/") ? "file://" + root.image.split("/").map(encodeURIComponent).join("/") : root.image) : ""
        name: root.isPath ? "" : root.image
        letter: root.entry.glyph || (root.entry.app || "?").charAt(0).toUpperCase()
        // One color per app for the letter, so all of Discord's look alike
        tint: root.entry.critical ? Theme.errorContainer : Qt.hsla(picture.hue(root.entry.app || "app"), 0.45, 0.45, 1)
    }

    Rectangle {
        anchors.fill: parent
        visible: root.symbol !== ""
        radius: root.radius
        color: root.entry.critical ? Theme.errorContainer : Theme.primaryContainer

        Icon {
            anchors.centerIn: parent
            icon: root.symbol
            size: root.size * 0.5
            color: root.entry.critical ? Theme.textOnErrorContainer : Theme.textOnPrimaryContainer
        }
    }

    // ── Ripple: calls ────────────────────────────────────────

    Repeater {
        model: root.ripple && Theme.animated ? 2 : 0

        delegate: Rectangle {
            id: ring

            required property int index

            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.width: 2
            border.color: Theme.ok
            opacity: 0

            // The second ring runs half a beat behind the first
            SequentialAnimation {
                running: true

                PauseAnimation {
                    duration: ring.index * Theme.anim.slow
                }
                SequentialAnimation {
                    loops: Animation.Infinite

                    ParallelAnimation {
                        Anim {
                            target: ring
                            property: "scale"
                            from: 1
                            to: 1.6
                            duration: Theme.anim.slow * 2
                        }
                        Anim {
                            target: ring
                            property: "opacity"
                            from: 0.9
                            to: 0
                            duration: Theme.anim.slow * 2
                        }
                    }
                }
            }
        }
    }
}
