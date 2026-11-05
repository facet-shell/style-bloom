import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The notification popups on the focused screen, inside the hole where
// Config.notificationPosition says (top right by default), as NoteCards at
// Bloom.scale("notification"). On a side they step aside while a drawer is out there (the
// control center, the history); at the bottom the newest sits nearest the edge. In a game
// with Bloom.compact("notification") they turn into see-through pills close to the edge.
// With Config.notificationGroupByApp the cards of one app sit together and stack: only the
// newest shows, the rest hide under it with a count until the stack is opened. The window
// takes the keyboard only while a card's reply field is open.
Scope {
    id: root

    property bool hidden: false

    readonly property string position: Config.notificationPosition
    readonly property string side: Config.side(position)
    readonly property bool atTop: Config.atTop(position)
    readonly property bool compact: Bloom.compact("notification")
    // Room inside the window for the cards' shadows and a call's glow; the window sits at
    // the hole's edge, so this is also the distance to it
    readonly property real pad: Theme.spacing.large

    // The popups by app, each group's newest first, and where every popup sits in its
    // group (uid → { index, size, key }). Off: one group per popup, the list as it is.
    readonly property var groups: Notifications.groups(Notifications.popups)
    readonly property var ordered: groups.flatMap(g => g.entries)
    readonly property var places: Notifications.places(Notifications.popups)
    // Keys of the groups opened with their count
    property var unfolded: ({})
    // Reply fields open right now; the window has the keyboard while there is one
    property int replyOpen: 0

    function toggleGroup(key) {
        const next = Object.assign({}, unfolded);
        if (next[key])
            delete next[key];
        else
            next[key] = true;
        unfolded = next;
    }

    // Nothing on screen: forget which groups were open
    Connections {
        target: Notifications

        function onPopupsChanged() {
            if (Notifications.popups.length === 0 && Object.keys(root.unfolded).length > 0)
                root.unfolded = {};
        }
    }

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
        keyboard: root.replyOpen > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
                        values: root.atTop ? root.ordered : root.ordered.slice().reverse()
                    }

                    delegate: NoteCard {
                        required property var modelData

                        readonly property var place: root.places[modelData.uid] ?? ({ index: 0, size: 1, key: "" })

                        entry: modelData
                        side: root.side
                        atTop: root.atTop
                        compact: root.compact
                        compactWidth: column.width
                        cardWidth: column.width
                        stackIndex: place.index
                        stackSize: place.size
                        groupOpen: root.unfolded[place.key] === true
                        // Narrower ones (minimal) sit on the side the popups are on
                        x: root.side === "left" ? 0 : root.side === "right" ? column.width - width : (column.width - width) / 2
                        onGroupToggled: root.toggleGroup(place.key)
                        onReplyToggled: opened => root.replyOpen += opened ? 1 : -1
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
