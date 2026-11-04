import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Notifications: what shows when, per kind (Config.notifyRules). "always" gets through game
// mode, "not in game" waits in the bell while playing. How the popups look and where they
// sit is in Popups.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    readonly property var whenOpen: [["always", "anyway"], ["unfocused", "not focused"], ["hidden", "on no screen"]]

    PageHeading {
        text: "What shows when"
    }

    StyledText {
        Layout.fillWidth: true
        text: "always gets through game mode; not in game waits in the bell while you play"
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    PageHeading {
        sub: true
        text: "System"
    }
    RuleRow {
        kind: "sys.apps"
        title: "Apps"
        subtitle: "downloads, mail, anything that sends one over D-Bus"
    }
    ConfigRow {
        title: "Critical ones"
        subtitle: "battery low, or the app says it is urgent"

        Chip {
            text: "always · can't be turned off"
            icon: "lock"
        }
    }
    RuleRow {
        kind: "sys.gamemode"
        title: "Game mode on and off"
    }

    PageHeading {
        sub: true
        text: "Discord"
    }
    RuleRow {
        kind: "dc.call"
        title: "Calls"
        subtitle: "someone rings you"
    }
    RuleRow {
        kind: "dc.dm"
        title: "Direct and group messages"
    }
    RuleRow {
        kind: "dc.mention"
        title: "Server mentions"
        subtitle: "@you or a reply in a server"
    }
    ConfigChoice {
        key: "discordMessagesWhen"
        title: "Messages while Discord is open"
        subtitle: "anyway, or not while you look at it: focused, or on any screen (the second one counts)"
        options: page.whenOpen
    }
    RuleRow {
        kind: "dc.voice"
        title: "Voice channels"
        subtitle: "people join or leave yours or one you watch"
    }
    RuleRow {
        kind: "dc.event"
        title: "Server events"
        subtitle: "a stage or event starts"
    }
    RuleRow {
        kind: "dc.self"
        title: "Mute and deafen"
        subtitle: "your own keys, and DMs sent from the launcher"
    }

    PageHeading {
        sub: true
        text: "Steam"
    }
    RuleRow {
        kind: "st.invite"
        title: "Game invites"
        subtitle: "a friend invites you, with join"
    }
    RuleRow {
        kind: "st.request"
        title: "Friend requests"
    }
    RuleRow {
        kind: "st.message"
        title: "Messages"
    }
    ConfigChoice {
        key: "steamMessagesWhen"
        title: "Messages while Steam is open"
        subtitle: "anyway, or not while you look at it: focused, or on any screen"
        options: page.whenOpen
    }
    RuleRow {
        kind: "st.friends"
        title: "Friends online or playing"
    }
    RuleRow {
        kind: "st.achievement"
        title: "Achievements"
        subtitle: "Steam shows its own in the game"
    }
    RuleRow {
        kind: "st.download"
        title: "Downloads ready"
    }

    PageHeading {
        sub: true
        text: "Spotify"
    }
    RuleRow {
        kind: "sp.song"
        title: "Next song popup"
        subtitle: "not when you skipped from the card under the bar"
    }

    PageHeading {
        text: "All rules"
    }
    ConfigRow {
        title: "Back to the defaults"
        subtitle: "the bell in the bar still holds back everything but calls and alarms"

        Button {
            text: "Reset all"
            icon: "restart_alt"
            variant: "tonal"
            disabled: !Config.isSet("notifyRules")
            onClicked: Config.reset("notifyRules")
        }
    }
    ConfigRow {
        title: "Look and place of the popups"
        subtitle: "corner, style, width, how long they stay"
        icon: "picture_in_picture"
        interactive: true
        onClicked: page.view.section = "popups"

        Icon {
            icon: "chevron_right"
            dim: true
        }
    }
}
