import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// Games: when game mode comes on by itself and what it does (quiet, the frame steps away,
// the bar over fullscreen), the fps overlay, which apps count as games and the GoXLR profile
// while playing (only with a GoXLR). One block per page of the category (view.page).
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page

    spacing: Theme.spacing.medium

    // ── Game mode ──

    ConfigRow {
        visible: page.sub === "mode"
        title: Toggles.gameMode ? "Game mode is on" : "Game mode is off"
        subtitle: Toggles.inGame ? `playing ${Toggles.gameTitle}` : "the toggle in the control center works by hand too"
        icon: "sports_esports"

        Switch {
            checked: Toggles.gameMode
            onToggled: on => Toggles.setGameMode(on)
        }
    }
    ConfigSwitch {
        visible: page.sub === "mode"
        key: "gameModeAuto"
        title: "Game mode by itself"
        subtitle: "on while you are on the gaming workspace or a game has the focus fullscreen, off again after"
    }
    ConfigSwitch {
        visible: page.sub === "mode"
        key: "gameModeSilent"
        title: "Quiet while playing"
        subtitle: "what is set to \"not in game\" under Notifications waits; off: everything shows"
    }
    ConfigSwitch {
        visible: page.sub === "mode"
        key: "frameHidesInGame"
        title: "Frame steps away"
        subtitle: "the frame and the bar go and the game gets the whole screen"
    }
    ConfigSwitch {
        visible: page.sub === "mode"
        key: "barOverFullscreen"
        title: "Bar at the top edge over fullscreen"
        subtitle: "rest the mouse on the top edge in a game's menu and the bar comes down over it"
    }

    // ── Fps overlay ──

    ConfigSwitch {
        visible: page.sub === "fps"
        key: "fpsOverlay"
        title: "Fps, cpu and gpu over the game"
        subtitle: "a small line while game mode is on; fps needs MangoHud in the game (Steam: mangohud %command%), cpu and gpu come anyway"
    }
    ConfigChoice {
        visible: page.sub === "fps"
        key: "fpsOverlayPosition"
        title: "Corner"
        options: [["top-left", "top left"], ["top-right", "top right"], ["bottom-left", "bottom left"], ["bottom-right", "bottom right"]]
    }

    // ── Games ──

    GameList {
        visible: page.sub === "list"
    }

    // Only with a GoXLR to load it on (or one set before)
    ConfigText {
        visible: page.sub === "list" && (GoXLR.available || Audio.goxlr || Config.isSet("goxlrGameProfile"))
        key: "goxlrGameProfile"
        title: "GoXLR profile while playing"
        subtitle: "the one before comes back after; empty: none"
        placeholder: "e.g. Gaming"
    }

    StyledText {
        Layout.fillWidth: true
        visible: page.sub === "list" && Audio.virtualActive && Audio.outputRoutes.includes("game")
        text: "The game's sound goes on the Game channel (the @game rule under Sound)."
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
