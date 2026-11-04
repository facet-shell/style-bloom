import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// Games: when game mode comes on by itself, what it does (quiet, the frame steps away), which
// apps count as games, and the GoXLR profile while playing (only with a GoXLR).
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    PageHeading {
        text: "Game mode"
    }

    ConfigRow {
        title: Toggles.gameMode ? "Game mode is on" : "Game mode is off"
        subtitle: Toggles.gameRunning ? `playing ${Toggles.gameTitle}` : "the toggle in the control center works by hand too"
        icon: "sports_esports"

        Switch {
            checked: Toggles.gameMode
            onToggled: on => Toggles.setGameMode(on)
        }
    }
    ConfigSwitch {
        key: "gameModeAuto"
        title: "Game mode by itself"
        subtitle: "on while a Steam game, gamescope or one from the list below runs, off again after"
    }
    ConfigSwitch {
        key: "gameModeSilent"
        title: "Quiet while playing"
        subtitle: "what is set to \"not in game\" under Notifications waits; off: everything shows"
    }
    ConfigSwitch {
        key: "frameHidesInGame"
        title: "Frame steps away"
        subtitle: "the frame and the bar go and the game gets the whole screen"
    }
    ConfigSwitch {
        key: "barOverFullscreen"
        title: "Bar at the top edge over fullscreen"
        subtitle: "rest the mouse on the top edge in a game's menu and the bar comes down over it (tui and bloom)"
    }

    PageHeading {
        text: "Games"
    }

    GameList {}

    // Only with a GoXLR to load it on (or one set before)
    ConfigText {
        visible: GoXLR.available || Audio.goxlr || Config.isSet("goxlrGameProfile")
        key: "goxlrGameProfile"
        title: "GoXLR profile while playing"
        subtitle: "the one before comes back after; empty: none"
        placeholder: "e.g. Gaming"
    }

    StyledText {
        Layout.fillWidth: true
        visible: Audio.virtualActive && Audio.outputRoutes.includes("game")
        text: "The game's sound goes on the Game channel (the @game rule under Sound)."
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
