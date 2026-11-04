import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The apps that count as games (Config.gameClasses), as a block like the mockup's: what is on
// the list as chips (× takes one off), and three ways to add one: typed in (a class,
// *pattern* or title:…), picked from the windows open right now, or a suggestion.
Rectangle {
    id: games

    readonly property var list: Config.gameClasses
    property bool picking: false

    // Already on it, any case
    function has(entry) {
        return list.some(x => String(x).toLowerCase() === String(entry).toLowerCase());
    }

    function add(entry) {
        const e = String(entry).trim();
        if (e !== "" && !has(e))
            Config.set("gameClasses", list.concat([e]));
    }

    function remove(entry) {
        const next = list.filter(x => x !== entry);
        if (next.length === 0)
            Config.reset("gameClasses");
        else
            Config.set("gameClasses", next);
    }

    // The window classes are guesses until checked with hyprctl clients; the GeForce NOW
    // and Minecraft ones are patterns for that reason
    readonly property var suggestions: [
        ["org.vinegarhq.Sober", "Sober (Roblox)"],
        ["*geforce*", "GeForce NOW app"],
        ["title:*GeForce NOW*", "GeForce NOW in the browser"],
        ["Minecraft*", "Minecraft"],
        ["osu!", "osu!"],
        ["retroarch", "RetroArch"]
    ].filter(s => !has(s[0]))

    // One entry per class of the windows open now, without the shell and what already counts
    readonly property var openWindows: {
        const seen = new Set();
        const out = [];
        for (const t of ToplevelManager.toplevels.values) {
            const id = String(t.appId ?? "");
            if (id === "" || seen.has(id.toLowerCase()) || id.startsWith("org.quickshell") || Toggles.isGame(id, t.title))
                continue;
            seen.add(id.toLowerCase());
            out.push([id, t.title ?? ""]);
        }
        return out;
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Theme.padding.normal * 2
    radius: Theme.rounding.medium
    color: Theme.container

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.padding.normal
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: Theme.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.tiny

            StyledText {
                Layout.fillWidth: true
                text: "Apps that are games"
            }
            StyledText {
                Layout.fillWidth: true
                text: "Steam games and gamescope count by themselves; add the rest here: a window class (any case, * matches anything) or title:… for the window title"
                dim: true
                font.pixelSize: Theme.size.small
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            StyledText {
                visible: games.list.length === 0
                height: Theme.control.chip
                text: "nothing on the list yet"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Repeater {
                model: games.list

                delegate: Chip {
                    required property var modelData

                    text: String(modelData)
                    icon: "sports_esports"
                    selected: true
                    closable: true
                    onCloseClicked: games.remove(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            TextBox {
                id: entry

                Layout.preferredWidth: 300
                placeholder: "class, *pattern* or title:…"
                onAccepted: {
                    games.add(text);
                    text = "";
                }
            }
            Button {
                text: "Add"
                icon: "add"
                variant: "tonal"
                disabled: entry.text.trim() === ""
                onClicked: {
                    games.add(entry.text);
                    entry.text = "";
                }
            }
            Chip {
                text: "from open windows"
                icon: "select_window"
                selected: games.picking
                onClicked: games.picking = !games.picking
            }
            Item {
                Layout.fillWidth: true
            }
        }

        // The open windows: a click puts the class on the list
        Flow {
            Layout.fillWidth: true
            visible: games.picking
            spacing: Theme.spacing.normal

            StyledText {
                visible: games.openWindows.length === 0
                height: Theme.control.chip
                text: "no other windows open; start the game, then look here again"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Repeater {
                model: games.picking ? games.openWindows : []

                delegate: Chip {
                    required property var modelData

                    icon: "add"
                    text: modelData[1] !== "" ? `${modelData[0]} · ${modelData[1].slice(0, 28)}` : modelData[0]
                    onClicked: {
                        games.add(modelData[0]);
                        games.picking = false;
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: games.suggestions.length > 0
            spacing: Theme.spacing.normal

            StyledText {
                height: Theme.control.chip
                text: "suggestions"
                dim: true
                font.pixelSize: Theme.size.tiny
            }
            Repeater {
                model: games.suggestions

                delegate: Chip {
                    required property var modelData

                    icon: "add"
                    text: modelData[1]
                    onClicked: games.add(modelData[0])
                }
            }
        }
    }
}
