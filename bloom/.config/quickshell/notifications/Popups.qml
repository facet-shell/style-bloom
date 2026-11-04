import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The notification popups on the focused screen, inside the hole where
// Config.notificationPosition says (top right by default), as NoteCards at
// Bloom.scale("notification"). On a side they step aside while a drawer is out there (the
// control center, the history); at the bottom the newest sits nearest the edge. In a game
// with Bloom.compact("notification") they turn into see-through pills close to the edge.
Scope {
    id: root

    property bool hidden: false

    readonly property string position: Config.notificationPosition
    readonly property string side: Config.side(position)
    readonly property bool top: Config.atTop(position)
    readonly property bool compact: Bloom.compact("notification")
    // Room inside the window for the cards' shadows and a call's glow; the window sits at
    // the hole's edge, so this is also the distance to it
    readonly property real pad: Theme.spacing.large

    HolePopup {
        id: popup

        screen: Bloom.focusedScreen
        position: root.position
        margin: 0
        insetLeft: root.side === "left" ? Bloom.inset(screen?.name ?? "", "left") : 0
        insetRight: root.side === "right" ? Bloom.inset(screen?.name ?? "", "right") : 0
        contentScale: Bloom.scale("notification")
        shown: !root.hidden && Notifications.popups.length > 0
        namespace: "qs-notifications"

        Behavior on insetLeft {
            Anim {
                duration: Theme.anim.drawerIn
            }
        }
        Behavior on insetRight {
            Anim {
                duration: Theme.anim.drawerIn
            }
        }

        Item {
            implicitWidth: column.width + root.pad * 2
            implicitHeight: column.implicitHeight + root.pad * 2

            Column {
                id: column

                x: root.pad
                y: root.pad
                width: root.compact ? 320 : Config.notificationWidth
                spacing: root.compact ? Theme.spacing.small + Theme.spacing.tiny : Theme.spacing.medium - Theme.spacing.tiny

                // ScriptModel keeps existing cards (and their timers) when the list changes
                Repeater {
                    model: ScriptModel {
                        values: root.top ? Notifications.popups : Notifications.popups.slice().reverse()
                    }

                    delegate: NoteCard {
                        required property var modelData

                        entry: modelData
                        side: root.side
                        top: root.top
                        compact: root.compact
                        compactWidth: column.width
                        cardWidth: column.width
                        // Narrower ones (minimal) sit on the side the popups are on
                        x: root.side === "left" ? 0 : root.side === "right" ? column.width - width : (column.width - width) / 2
                    }
                }

                move: Transition {
                    Anim {
                        properties: "y"
                    }
                }
            }
        }
    }
}
