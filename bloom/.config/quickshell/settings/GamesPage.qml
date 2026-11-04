import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// Games: when game mode comes on by itself, what it does (quiet, the frame steps away), which
// apps count as games, and the GoXLR profile while playing.
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
        subtitle: "rest the mouse on the top edge in a game's menu and the bar comes down over it (tui's bar; bloom's does not yet)"
    }

    PageHeading {
        text: "Games"
    }

    GameList {}

    ConfigText {
        key: "goxlrGameProfile"
        title: "GoXLR profile while playing"
        subtitle: "the one before comes back after; empty: none"
        placeholder: "e.g. Gaming"
    }
}
