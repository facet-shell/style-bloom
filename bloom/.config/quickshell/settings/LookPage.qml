import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Look: the style (tui or bloom), the colors (the themes as swatch cards, or taken from the
// wallpaper), how windows are laid out, the corners, the animations and the wallpaper app.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    // ── Style ──

    PageHeading {
        text: "Style"
    }

    ConfigRow {
        title: "Style"
        subtitle: "the look of the whole desktop: tui's square frames or bloom's rounded one; the colors stay. Opens a terminal, the shell restarts with the new one"

        SegmentedButtons {
            model: [
                { key: "tui", label: "tui", icon: "terminal" },
                { key: "bloom", label: "bloom", icon: "local_florist" }
            ]
            current: page.view.currentStyle
            onSelected: key => {
                if (key !== page.view.currentStyle)
                    page.view.inTerminal(`facet style ${key}`, [page.view.facet, "style", key]);
            }
        }
    }

    // ── Colors ──

    PageHeading {
        text: "Colors"
    }

    StyledText {
        Layout.fillWidth: true
        text: "Every app, the boot screen and the keyboard follow the theme"
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    GridLayout {
        id: grid

        Layout.fillWidth: true
        columns: 3
        columnSpacing: Theme.spacing.medium - 2
        rowSpacing: Theme.spacing.medium - 2

        // The colors from the wallpaper: its strip is the colors in use, which are the
        // wallpaper's once something writes them
        ThemeCard {
            Layout.fillWidth: true
            name: "From the wallpaper"
            description: Config.colorMode === "dynamic" && !Theme.dynamic ? "waiting for its colors" : "dynamic"
            icon: "wallpaper"
            swatch: [Theme.primary, Theme.tertiary, Theme.secondaryContainer, Theme.container]
            picked: Config.colorMode === "dynamic"
            onClicked: Config.set("colorMode", "dynamic")
        }

        Repeater {
            model: page.view.themes

            delegate: ThemeCard {
                required property var modelData
                readonly property var tones: modelData.tones ?? {}
                readonly property var colors: modelData.colors ?? {}

                Layout.fillWidth: true
                name: modelData.name ?? modelData.id
                description: modelData.description ?? ""
                // A theme without tones gets them made by facet; its plain colors stand in here
                swatch: [
                    tones.primary ?? colors.primary,
                    tones.tertiary ?? colors.accent,
                    tones.secondaryContainer ?? colors.surface2,
                    tones.container ?? colors.surface
                ]
                picked: Config.colorMode !== "dynamic" && page.view.currentTheme === modelData.id
                onClicked: {
                    if (Config.isSet("colorMode"))
                        Config.reset("colorMode");
                    if (page.view.currentTheme !== modelData.id)
                        page.view.runFacet(["theme", "set", modelData.id], `theme ${modelData.name ?? modelData.id}`);
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Config.colorMode === "dynamic" && !Theme.dynamic
        text: "Nothing has taken colors from the wallpaper yet, so the theme's stay until it does."
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    // ── Layout ──

    PageHeading {
        text: "Layout"
    }

    ConfigRow {
        title: "Windows"
        subtitle: "Hyprland's tiling, or the infinite canvas where windows float on an endless plane"

        SegmentedButtons {
            model: [
                { key: "tiling", label: "tiling", icon: "grid_view" },
                { key: "canvas", label: "canvas", icon: "open_with" }
            ]
            current: page.view.currentLayout
            onSelected: key => {
                if (key !== page.view.currentLayout)
                    page.view.runFacet(["layout", key], `layout ${key}`);
            }
        }
    }

    ConfigChoice {
        key: "corners"
        title: "Corners"
        subtitle: "how round the frame, the panels and the cards are"
        options: [["small", "small"], ["round", "round"], ["veryRound", "very round"]]
    }

    ConfigChoice {
        key: "animations"
        title: "Animations"
        subtitle: Theme.motion === "off" && Config.animations !== "off"
            ? "off for now: the system asks for less motion (gsettings enable-animations)"
            : "calm is the same without the bounce; the system's reduced motion counts as off"
        options: [["off", "off"], ["calm", "calm"], ["full", "full"]]
    }

    // ── Wallpaper ──

    PageHeading {
        text: "Wallpaper"
    }

    ConfigRow {
        title: "Wallpaper"
        subtitle: "pictures, videos and Wallpaper Engine scenes (Super+W)"
        icon: "wallpaper"
        interactive: true
        onClicked: page.view.wallpapersRequested()

        Button {
            text: "Open"
            icon: "arrow_forward"
            variant: "tonal"
            onClicked: page.view.wallpapersRequested()
        }
    }
}
