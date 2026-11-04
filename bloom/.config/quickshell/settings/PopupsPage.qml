import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// Popups: for each thing that pops up (notifications, the Spotify bloom, the GoXLR faders
// and volume, the voice overlay) and the panels out of the frame, its size and whether it
// turns into a see-through pill in a game (Bloom.scale, Bloom.compact); then each one's own
// look and place.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    readonly property string compactHint: "a see-through pill, one line, no frame"

    // ── Notifications ──

    PageHeading {
        text: "Notifications"
    }
    ConfigSize {
        key: "notificationSize"
        hint: "corner, style and width are below"
    }
    ConfigSwitch {
        key: "notificationCompactInGame"
        title: "Compact in a game"
        subtitle: `${page.compactHint}; calls and invites keep small buttons`
    }
    PositionPicker {
        key: "notificationPosition"
    }
    ConfigChoice {
        key: "notificationStyle"
        title: "Style"
        subtitle: "card: picture, buttons, time left · line: one line · minimal: who and what"
        options: [["card", "card"], ["line", "line"], ["minimal", "minimal"]]
    }
    ConfigNumber {
        key: "notificationWidth"
        title: "Width"
        min: 340
        max: 680
        step: 20
        unit: " px"
    }
    ConfigNumber {
        key: "notificationTimeout"
        title: "Stay on screen"
        subtitle: "when the app does not say how long"
        min: 1
        max: 30
        factor: 1000
        unit: " s"
    }
    ConfigNumber {
        key: "notificationsMax"
        title: "At once"
        subtitle: "popups on screen at the same time"
        min: 1
        max: 6
    }

    // ── Spotify ──

    PageHeading {
        text: "Spotify bloom"
    }
    ConfigSize {
        key: "spotifySize"
        hint: "the song popup when the next one starts"
    }
    ConfigSwitch {
        key: "spotifyCompactInGame"
        title: "Compact in a game"
        subtitle: `${page.compactHint}: title and artist`
    }
    PositionPicker {
        key: "spotifyPosition"
    }
    ConfigChoice {
        key: "spotifyFormat"
        title: "Format"
        subtitle: "wide: cover beside the song · tall: big cover on top · strip: one thin line"
        options: [["wide", "wide"], ["tall", "tall"], ["strip", "strip"]]
    }
    ConfigNumber {
        key: "spotifySeconds"
        title: "Stays"
        subtitle: "longer while the mouse is on it, shorter in a game"
        min: 2
        max: 20
        unit: " s"
    }

    // ── OSD ──

    PageHeading {
        text: "GoXLR faders and volume"
    }
    ConfigSize {
        key: "osdSize"
        hint: "only the fader that moved, at the bottom"
    }
    ConfigSwitch {
        key: "osdCompactInGame"
        title: "Compact in a game"
        subtitle: `${page.compactHint}, gone after a second`
    }

    // ── Voice ──

    PageHeading {
        text: "Discord voice overlay"
    }
    ConfigSize {
        key: "voiceOverlaySize"
        hint: "faces and names, no frame or background"
    }
    ConfigSwitch {
        key: "voiceOverlayCompactInGame"
        title: "Compact in a game"
        subtitle: "smaller faces on a see-through pill"
    }
    ConfigChoice {
        key: "voiceOverlayWhen"
        title: "Shows"
        subtitle: "only while you are in a voice channel"
        options: [["always", "always"], ["hidden", "Discord on no screen"], ["game", "in game"], ["never", "never"]]
    }
    ConfigChoice {
        key: "voiceOverlayLook"
        title: "Look"
        subtitle: "compact: faces in a row, names only while talking"
        options: [["list", "list"], ["compact", "compact"], ["talking", "only who talks"]]
    }
    ConfigChoice {
        key: "voiceOverlayFeed"
        title: "Joins, leaves, your mute"
        subtitle: "your own channel; watched channels stay notifications"
        options: [["overlay", "in the overlay"], ["notify", "notification"], ["both", "both"]]
    }
    ConfigSwitch {
        key: "voiceOverlayDim"
        title: "Dim the quiet ones"
        subtitle: "list look: who talks stays bright"
    }
    ConfigRow {
        key: "voiceOverlayPos"
        title: "Place"
        subtitle: "Super+Shift+V, then drag it; Esc keeps the spot (per screen). The round arrow puts it back: left, under the bar"

        Button {
            text: "Move"
            icon: "open_with"
            variant: "tonal"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "voice", "move"])
        }
    }

    // ── Panels ──

    PageHeading {
        text: "Panels"
    }
    ConfigSize {
        key: "panelSize"
        hint: "dashboard, control center and launcher"
    }
    ConfigSwitch {
        key: "panelsCompactInGame"
        title: "Smaller in a game"
        subtitle: "the panels open smaller while game mode is on"
    }
}
