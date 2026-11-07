import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

// Apps: the facet modules (update what is there, add what is not, each in a terminal) and the
// settings of the apps around the shell: Spotify's Web API, the keyboard, the GoXLR lights.
// One block per page of the category (view.page).
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page

    spacing: Theme.spacing.medium

    // Name and what it holds, as `facet` describes them
    readonly property var modules: [
        ["core", "what every style shares: services, bridges, settings, Hyprland, wallpapers"],
        ["style-tui", "the tui style: bar, launcher, lockscreen and panels in square frames, login and boot screens"],
        ["style-bloom", "the bloom style: a rounded frame around the screen, panels sliding out of it, Material You colors"],
        ["terminal", "Ghostty, fish, Starship, fastfetch"],
        ["spotify", "Spotify themed, search and controls in the launcher"],
        ["discord", "Vesktop themed, calls and DMs in the shell"],
        ["steam", "Steam themed through Millennium, its popups in the shell"],
        ["keyboard", "lighting and keys for supported keyboards"],
        ["zed", "Zed themed"],
        ["zen", "Zen themed, with the start page"],
        ["dolphin", "Dolphin and Qt apps themed"]
    ]

    // ── Modules ──

    StyledText {
        Layout.fillWidth: true
        visible: page.sub === "modules"
        text: "only what is installed is downloaded"
        dim: true
        font.pixelSize: Theme.size.small
    }

    Repeater {
        model: page.sub === "modules" ? page.modules : []

        delegate: ConfigRow {
            id: mod

            required property var modelData
            readonly property bool isInstalled: page.view.installed.includes(modelData[0])

            title: modelData[0]
            subtitle: isInstalled ? modelData[1] : `not installed · ${modelData[1]}`
            icon: isInstalled ? "check_circle" : "download"

            Button {
                visible: mod.isInstalled
                text: "Update"
                icon: "sync"
                variant: "plain"
                onClicked: page.view.inTerminal(`facet update ${mod.modelData[0]}`, [page.view.facet, "update", mod.modelData[0]])
            }
            Button {
                visible: !mod.isInstalled
                text: "Add"
                icon: "add"
                variant: "tonal"
                onClicked: page.view.inTerminal(`facet add ${mod.modelData[0]}`, [page.view.facet, "add", mod.modelData[0]])
            }
        }
    }

    // ── App settings ──

    ConfigRow {
        visible: page.sub === "settings"
        title: "Hotkeys"
        subtitle: "show all keyboard shortcuts"
        icon: "keyboard_keys"

        Button {
            text: "Open"
            icon: "open_in_new"
            variant: "tonal"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "hotkeys", "toggle"])
        }
    }
    ConfigSwitch {
        visible: page.sub === "settings"
        key: "hotkeysOnHold"
        title: "Show hotkeys when holding Super"
        subtitle: "open the shortcut menu after holding Super for 1.5 seconds"
    }
    ConfigSwitch {
        visible: page.sub === "settings"
        key: "keyboardHotkeyHints"
        title: "Hotkey lighting on the keyboard"
        subtitle: "highlight bound keys on supported physical keyboards while modifiers are held"
    }

    ConfigRow {
        visible: page.sub === "settings"
        title: "Spotify Web API"
        subtitle: "search and control from the launcher (s) without the app in front"
        icon: "music_note"

        Button {
            text: "Connect"
            icon: "link"
            variant: "plain"
            onClicked: page.view.inTerminal("facet spotify login", [page.view.facet, "spotify", "login"])
        }
    }
    ConfigRow {
        visible: page.sub === "settings"
        title: "Keyboard"
        subtitle: "lighting, Fn keys and key colors (Super+K)"
        icon: "keyboard"
        interactive: true
        onClicked: page.view.keyboardRequested()

        Button {
            text: "Open"
            icon: "arrow_forward"
            variant: "tonal"
            onClicked: page.view.keyboardRequested()
        }
    }
    ConfigSwitch {
        visible: page.sub === "settings"
        key: "keyboardLive"
        title: "Keyboard live"
        subtitle: "off: the keyboard app only shows what it would send"
    }
    // Only where a GoXLR answers
    ConfigRow {
        visible: page.sub === "settings" && GoXLR.available
        title: "GoXLR lights"
        subtitle: "faders, buttons and the animation in the theme's colors"
        icon: "tune"

        Button {
            text: "Apply"
            icon: "palette"
            variant: "plain"
            onClicked: page.view.runFacet(["goxlr"], "GoXLR lights")
        }
    }
}
