import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Notifications: how the popups look and where they sit, the groups and the reply field,
// and what shows when, per kind (Config.notifyRules) with one page per app. "always" gets
// through game mode, "not in game" waits in the bell while playing. One block per page of
// the category (view.page).
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page
    readonly property bool rules: ["system", "discord", "steam", "spotify"].includes(sub)

    spacing: Theme.spacing.medium

    readonly property var whenOpen: [["always", "anyway"], ["unfocused", "not focused"], ["hidden", "on no screen"]]

    // ── Popups ──

    ConfigSize {
        visible: page.sub === "popups"
        key: "notificationSize"
        hint: "corner, style and width are below"
    }
    ConfigSwitch {
        visible: page.sub === "popups"
        key: "notificationCompactInGame"
        title: "Compact in a game"
        subtitle: "a see-through pill, one line, no frame; calls and invites keep small buttons"
    }
    PositionPicker {
        visible: page.sub === "popups"
        key: "notificationPosition"
    }
    ConfigChoice {
        visible: page.sub === "popups"
        key: "notificationStyle"
        title: "Style"
        subtitle: "card: picture, buttons, time left · line: one line · minimal: who and what"
        options: [["card", "card"], ["line", "line"], ["minimal", "minimal"]]
    }
    ConfigNumber {
        visible: page.sub === "popups"
        key: "notificationWidth"
        title: "Width"
        min: 340
        max: 680
        step: 20
        unit: " px"
    }
    ConfigNumber {
        visible: page.sub === "popups"
        key: "notificationTimeout"
        title: "Stay on screen"
        subtitle: "when the app does not say how long"
        min: 1
        max: 30
        factor: 1000
        unit: " s"
    }
    ConfigNumber {
        visible: page.sub === "popups"
        key: "notificationsMax"
        title: "At once"
        subtitle: "popups on screen at the same time"
        min: 1
        max: 6
    }

    // ── Groups and replies ──

    ConfigSwitch {
        visible: page.sub === "groups"
        key: "notificationGroupByApp"
        title: "One stack per app"
        subtitle: "more popups from the same app sit behind the newest with a count; a click unfolds them. The bell's history groups the same way"
    }
    ConfigSwitch {
        visible: page.sub === "groups"
        key: "notificationInlineReply"
        title: "Reply from the card"
        subtitle: "a Discord message gets a reply field right in the popup, Enter sends; not in a game's compact pill"
    }

    // ── What shows when ──

    StyledText {
        Layout.fillWidth: true
        visible: page.rules
        text: "always gets through game mode; not in game waits in the bell while you play"
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    RuleRow {
        visible: page.sub === "system"
        kind: "sys.apps"
        title: "Apps"
        subtitle: "downloads, mail, anything that sends one over D-Bus"
    }
    ConfigRow {
        visible: page.sub === "system"
        title: "Critical ones"
        subtitle: "battery low, or the app says it is urgent"

        Chip {
            text: "always · can't be turned off"
            icon: "lock"
        }
    }
    RuleRow {
        visible: page.sub === "system"
        kind: "sys.gamemode"
        title: "Game mode on and off"
    }

    RuleRow {
        visible: page.sub === "discord"
        kind: "dc.call"
        title: "Calls"
        subtitle: "someone rings you"
    }
    RuleRow {
        visible: page.sub === "discord"
        kind: "dc.dm"
        title: "Direct and group messages"
    }
    RuleRow {
        visible: page.sub === "discord"
        kind: "dc.mention"
        title: "Server mentions"
        subtitle: "@you or a reply in a server"
    }
    ConfigChoice {
        visible: page.sub === "discord"
        key: "discordMessagesWhen"
        title: "Messages while Discord is open"
        subtitle: "anyway, or not while you look at it: focused, or on any screen (the second one counts)"
        options: page.whenOpen
    }
    RuleRow {
        visible: page.sub === "discord"
        kind: "dc.voice"
        title: "Voice channels"
        subtitle: "people join or leave yours or one you watch"
    }
    RuleRow {
        visible: page.sub === "discord"
        kind: "dc.event"
        title: "Server events"
        subtitle: "a stage or event starts"
    }
    RuleRow {
        visible: page.sub === "discord"
        kind: "dc.self"
        title: "Mute and deafen"
        subtitle: "your own keys, and DMs sent from the launcher"
    }

    RuleRow {
        visible: page.sub === "steam"
        kind: "st.invite"
        title: "Game invites"
        subtitle: "a friend invites you, with join"
    }
    RuleRow {
        visible: page.sub === "steam"
        kind: "st.request"
        title: "Friend requests"
    }
    RuleRow {
        visible: page.sub === "steam"
        kind: "st.message"
        title: "Messages"
    }
    ConfigChoice {
        visible: page.sub === "steam"
        key: "steamMessagesWhen"
        title: "Messages while Steam is open"
        subtitle: "anyway, or not while you look at it: focused, or on any screen"
        options: page.whenOpen
    }
    RuleRow {
        visible: page.sub === "steam"
        kind: "st.friends"
        title: "Friends online or playing"
    }
    RuleRow {
        visible: page.sub === "steam"
        kind: "st.achievement"
        title: "Achievements"
        subtitle: "Steam shows its own in the game"
    }
    RuleRow {
        visible: page.sub === "steam"
        kind: "st.download"
        title: "Downloads ready"
    }

    RuleRow {
        visible: page.sub === "spotify"
        kind: "sp.song"
        title: "Next song popup"
        subtitle: "not when you skipped from the card under the bar, or while Spotify has the focus"
    }
    ConfigRow {
        visible: page.sub === "spotify"
        title: "Look and place of the song popup"
        subtitle: "size, corner, format, how long it stays"
        icon: "music_note"
        interactive: true
        onClicked: page.view.goTo("popups/spotify")

        Icon {
            icon: "chevron_right"
            dim: true
        }
    }

    PageHeading {
        visible: page.rules
        text: "All rules"
    }
    ConfigRow {
        visible: page.rules
        title: "Back to the defaults"
        subtitle: "every rule, not only this page's; the bell in the bar still holds back everything but calls and alarms"

        Button {
            text: "Reset all"
            icon: "restart_alt"
            variant: "tonal"
            disabled: !Config.isSet("notifyRules")
            onClicked: Config.reset("notifyRules")
        }
    }
}
