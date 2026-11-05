import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// Overlays: for each thing that comes over the desktop (the Spotify bloom, the GoXLR faders
// and volume, the voice overlay) and the panels out of the frame, its size and whether it
// turns into a see-through pill in a game (Bloom.scale, Bloom.compact); then each one's own
// look and place. One block per page of the category (view.page); the notification popups
// have their own page under Notifications.
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page

    spacing: Theme.spacing.medium

    readonly property string compactHint: "a see-through pill, one line, no frame"

    // ── Spotify ──

    ConfigRow {
        visible: page.sub === "spotify"
        title: "Try it"
        subtitle: "the bloom with the song playing now, or a made-up one"

        Button {
            text: "show a test"
            icon: "music_note"
            onClicked: Bloom.preview("spotify")
        }
    }
    ConfigSize {
        visible: page.sub === "spotify"
        key: "spotifySize"
        hint: "the song popup when the next one starts"
    }
    ConfigSwitch {
        visible: page.sub === "spotify"
        key: "spotifyCompactInGame"
        title: "Compact in a game"
        subtitle: `${page.compactHint}: title and artist`
    }
    PositionPicker {
        visible: page.sub === "spotify"
        key: "spotifyPosition"
    }
    ConfigChoice {
        visible: page.sub === "spotify"
        key: "spotifyFormat"
        title: "Format"
        subtitle: "wide: cover beside the song · tall: big cover on top · strip: one thin line"
        options: [["wide", "wide"], ["tall", "tall"], ["strip", "strip"]]
    }
    ConfigNumber {
        visible: page.sub === "spotify"
        key: "spotifySeconds"
        title: "Stays"
        subtitle: "longer while the mouse is on it, shorter in a game"
        min: 2
        max: 20
        unit: " s"
    }
    ConfigRow {
        visible: page.sub === "spotify"
        title: "Colors from the album cover"
        subtitle: Config.albumColors ? "on: the popup takes its accent from the cover (Appearance › Colors)" : "off: the theme's colors (Appearance › Colors)"
        icon: "palette"
        interactive: true
        onClicked: page.view.goTo("look/colors")

        Icon {
            icon: "chevron_right"
            dim: true
        }
    }

    // ── OSD ──

    ConfigSize {
        visible: page.sub === "osd"
        key: "osdSize"
        hint: "only the fader that moved, at the bottom"
    }
    ConfigSwitch {
        visible: page.sub === "osd"
        key: "osdCompactInGame"
        title: "Compact in a game"
        subtitle: `${page.compactHint}, gone after a second`
    }

    // ── Voice ──

    ConfigSize {
        visible: page.sub === "voice"
        key: "voiceOverlaySize"
        hint: "faces and names, no frame or background"
    }
    ConfigSwitch {
        visible: page.sub === "voice"
        key: "voiceOverlayCompactInGame"
        title: "Compact in a game"
        subtitle: "smaller faces on a see-through pill"
    }
    ConfigChoice {
        visible: page.sub === "voice"
        key: "voiceOverlayWhen"
        title: "Shows"
        subtitle: "only while you are in a voice channel"
        options: [["always", "always"], ["hidden", "Discord on no screen"], ["game", "in game"], ["never", "never"]]
    }
    ConfigChoice {
        visible: page.sub === "voice"
        key: "voiceOverlayLook"
        title: "Look"
        subtitle: "compact: faces in a row, names only while talking"
        options: [["list", "list"], ["compact", "compact"], ["talking", "only who talks"]]
    }
    ConfigChoice {
        visible: page.sub === "voice"
        key: "voiceOverlayFeed"
        title: "Joins, leaves, your mute"
        subtitle: "your own channel; watched channels stay notifications"
        options: [["overlay", "in the overlay"], ["notify", "notification"], ["both", "both"]]
    }
    ConfigSwitch {
        visible: page.sub === "voice"
        key: "voiceOverlayDim"
        title: "Dim the quiet ones"
        subtitle: "list look: who talks stays bright"
    }
    ConfigRow {
        visible: page.sub === "voice"
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

    ConfigSize {
        visible: page.sub === "panels"
        key: "panelSize"
        hint: "dashboard, control center and launcher"
    }
    ConfigSwitch {
        visible: page.sub === "panels"
        key: "panelsCompactInGame"
        title: "Smaller in a game"
        subtitle: "the panels open smaller while game mode is on"
    }
}
