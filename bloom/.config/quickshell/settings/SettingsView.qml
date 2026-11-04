import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// The settings window's content (the mockup's #settings): the sections as pills on the left,
// the picked one's rows on the right. Shell settings go through Config (kept in
// ~/.config/frameshell/shell.json, the round arrow puts one back); style, theme and layout
// through the facet command; what needs sudo or shows output opens in a terminal of its own.
// Each page is its own file (LookPage.qml …) and gets this view as `view` for the commands
// and the state read here.
FocusScope {
    id: root

    signal closeRequested()
    signal wallpapersRequested()
    signal keyboardRequested()

    property string section: "look"
    // key, label, icon; the keys are tui's (and `qs ipc call settings section <key>`)
    readonly property var sections: [
        { key: "look", label: "Look", icon: "palette" },
        { key: "notifications", label: "Notifications", icon: "notifications" },
        { key: "popups", label: "Popups", icon: "picture_in_picture" },
        { key: "games", label: "Games", icon: "sports_esports" },
        { key: "sound", label: "Sound", icon: "graphic_eq" },
        { key: "launcher", label: "Launcher", icon: "search" },
        { key: "shell", label: "Lock and weather", icon: "lock" },
        { key: "apps", label: "Apps", icon: "widgets" },
        { key: "system", label: "System", icon: "settings" }
    ]
    // Other names people (and the mockup) use for a section
    readonly property var aliases: ({
        notify: "notifications",
        rules: "notifications",
        popup: "popups",
        game: "games",
        audio: "sound",
        theme: "look",
        themes: "look",
        style: "look",
        lock: "shell",
        weather: "shell",
        modules: "apps",
        about: "system",
        updates: "system"
    })

    readonly property string home: Quickshell.env("HOME")
    readonly property string facet: `${home}/.local/bin/facet`
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/frameshell`
    readonly property string modulesDir: `${Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"}/frameshell/modules`

    // [{ id, name, description, colors, tones }] from the facet command's themes
    property var themes: []
    property var installed: []
    property string about: ""
    property string status: ""

    readonly property string currentTheme: themeState.text().trim() || "periwinkle"
    readonly property string currentLayout: layoutState.text().trim() === "canvas" ? "canvas" : "tiling"
    // This file only runs in bloom, so bloom until the state file says otherwise
    readonly property string currentStyle: styleState.text().trim() || "bloom"

    // A section name from IPC to its key; unknown names keep the page that is open
    function sectionFor(name) {
        const n = String(name ?? "").trim().toLowerCase();
        const key = aliases[n] ?? n;
        return sections.some(s => s.key === key) ? key : section;
    }

    function refresh() {
        themesProc.running = true;
        modulesProc.running = true;
        aboutProc.running = true;
        themeState.reload();
        layoutState.reload();
        styleState.reload();
    }

    // The window just came up: the content grows in like the mockup's
    function arrive() {
        windowIn.restart();
    }

    // facet commands that need sudo or show output: their own Ghostty, open until Enter.
    // Detached, so a shell restart (facet style) does not take it down.
    function inTerminal(title, args) {
        Quickshell.execDetached(["ghostty", "--gtk-single-instance=false", `--title=${title}`, "-e", "sh", "-c",
            '"$@"; printf "\\nDone. Enter closes this window."; read _', "facet-settings"].concat(args));
    }

    // facet commands without questions: in the background, the last line as the status
    function runFacet(args, label) {
        if (facetProc.running)
            return;
        status = `${label}…`;
        facetProc.label = label;
        facetProc.command = [facet].concat(args);
        facetProc.running = true;
    }

    Keys.onEscapePressed: root.closeRequested()
    // Ctrl+Tab and Ctrl+Shift+Tab (or Ctrl+PgDown/PgUp) walk the sections
    Keys.onPressed: event => {
        if (!(event.modifiers & Qt.ControlModifier))
            return;
        const i = sections.findIndex(s => s.key === section);
        let d = 0;
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown)
            d = 1;
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp)
            d = -1;
        if (d === 0)
            return;
        section = sections[(i + d + sections.length) % sections.length].key;
        event.accepted = true;
    }

    // ── Files and commands ───────────────────────────────────

    Process {
        id: themesProc
        command: ["sh", "-c", 'd="${XDG_DATA_HOME:-$HOME/.local/share}/frameshell/cli/themes/bloom"; jq -c -n \'[inputs | { id: (input_filename | split("/") | last | rtrimstr(".json")), name, description, colors, tones }]\' "$d"/*.json']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(this.text);
                } catch (e) {
                    root.themes = [];
                }
            }
        }
    }

    Process {
        id: modulesProc
        command: ["sh", "-c", 'for d in "$1"/*/; do [ -d "$d.git" ] && basename "$d"; done', "facet-settings", root.modulesDir]
        stdout: StdioCollector {
            onStreamFinished: root.installed = this.text.split("\n").filter(l => l !== "")
        }
    }

    Process {
        id: aboutProc
        command: ["sh", "-c", 'hyprctl version 2>/dev/null | head -1; qs --version 2>/dev/null | head -1; printf "kernel %s\\n" "$(uname -r)"; '
            + 'for d in "$1"/*/; do [ -d "$d.git" ] && printf "%s %s\\n" "$(basename "$d")" "$(git -C "$d" log -1 --format="%h · %cr" 2>/dev/null)"; done', "facet-settings", root.modulesDir]
        stdout: StdioCollector {
            onStreamFinished: root.about = this.text.trim()
        }
    }

    Process {
        id: facetProc

        property string label: ""

        stderr: StdioCollector {
            id: facetErr
        }
        onExited: code => {
            root.status = code === 0 ? `${label}: done` : `${label}: ${facetErr.text.trim().split("\n").pop() || "failed"}`;
            themeState.reload();
            layoutState.reload();
        }
    }

    FileView {
        id: themeState
        path: `${root.stateDir}/theme`
        printErrors: false
    }

    FileView {
        id: layoutState
        path: `${root.stateDir}/layout`
        printErrors: false
    }

    FileView {
        id: styleState
        path: `${root.stateDir}/style`
        printErrors: false
    }

    // ── Pages ────────────────────────────────────────────────

    Component {
        id: lookPage
        LookPage {
            view: root
        }
    }
    Component {
        id: notificationsPage
        NotificationsPage {
            view: root
        }
    }
    Component {
        id: popupsPage
        PopupsPage {
            view: root
        }
    }
    Component {
        id: gamesPage
        GamesPage {
            view: root
        }
    }
    Component {
        id: soundPage
        SoundPage {
            view: root
        }
    }
    Component {
        id: launcherPage
        LauncherPage {
            view: root
        }
    }
    Component {
        id: shellPage
        LockPage {
            view: root
        }
    }
    Component {
        id: appsPage
        AppsPage {
            view: root
        }
    }
    Component {
        id: systemPage
        SystemPage {
            view: root
        }
    }

    readonly property var pages: ({
        look: lookPage,
        notifications: notificationsPage,
        popups: popupsPage,
        games: gamesPage,
        sound: soundPage,
        launcher: launcherPage,
        shell: shellPage,
        apps: appsPage,
        system: systemPage
    })

    // ── Layout ───────────────────────────────────────────────

    // The window's content grows in from a little smaller, like the mockup's window
    ParallelAnimation {
        id: windowIn

        Anim {
            target: frame
            property: "opacity"
            from: 0
            to: 1
        }
        Anim {
            target: frame
            property: "scale"
            from: 0.96
            to: 1
            duration: Theme.anim.drawerIn
        }
    }

    RowLayout {
        id: frame

        anchors.fill: parent
        spacing: 0

        // ── Sections ──
        Rectangle {
            Layout.preferredWidth: 248
            Layout.fillHeight: true
            color: Theme.container

            Behavior on color {
                ColorAnim {
                    duration: Theme.anim.color
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding.normal
                anchors.topMargin: Theme.padding.drawer
                spacing: Theme.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding.normal
                    Layout.bottomMargin: Theme.spacing.medium
                    spacing: Theme.spacing.normal

                    Icon {
                        icon: "local_florist"
                        color: Theme.primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Settings"
                        font.pixelSize: Theme.size.medium + 1
                        font.weight: Font.DemiBold
                    }
                }

                // The pills, with one highlight that slides to the picked one
                Item {
                    Layout.fillWidth: true
                    implicitHeight: nav.implicitHeight

                    Rectangle {
                        readonly property Item target: navRepeater.count > 0 ? navRepeater.itemAt(Math.max(0, root.sections.findIndex(s => s.key === root.section))) : null

                        visible: target !== null
                        x: 0
                        y: target?.y ?? 0
                        width: parent.width
                        height: target?.height ?? 0
                        radius: height / 2
                        color: Theme.secondaryContainer

                        Behavior on y {
                            Anim {}
                        }
                    }

                    Column {
                        id: nav

                        width: parent.width
                        spacing: Theme.spacing.tiny

                        Repeater {
                            id: navRepeater

                            model: root.sections

                            delegate: Item {
                                id: navEntry

                                required property var modelData
                                readonly property bool picked: root.section === modelData.key

                                width: nav.width
                                height: Theme.control.button + Theme.spacing.small

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: "transparent"

                                    StateLayer {
                                        onClicked: root.section = navEntry.modelData.key
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.padding.card
                                    anchors.rightMargin: Theme.padding.card
                                    spacing: Theme.spacing.medium

                                    Icon {
                                        icon: navEntry.modelData.icon
                                        size: Theme.icon.normal - 1
                                        fill: navEntry.picked ? 1 : 0
                                        color: navEntry.picked ? Theme.text : Theme.dim
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: navEntry.modelData.label
                                        color: navEntry.picked ? Theme.text : Theme.dim
                                        font.pixelSize: Theme.size.small + 1
                                        font.weight: navEntry.picked ? Font.Medium : Font.Normal
                                    }
                                    // Something to do in the System page. The Badge sizes
                                    // itself, so it sits in an item the layout can measure
                                    Item {
                                        implicitWidth: dot.width
                                        implicitHeight: dot.height

                                        Badge {
                                            id: dot

                                            anchors.centerIn: parent
                                            shown: navEntry.modelData.key === "system" && Updates.total + Updates.frameCount > 0
                                            ringColor: Theme.container
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding.normal
                    Layout.rightMargin: Theme.padding.normal
                    visible: root.status !== ""
                    text: root.status
                    dim: true
                    font.pixelSize: Theme.size.tiny
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }

                Button {
                    Layout.fillWidth: true
                    text: "Close"
                    icon: "close"
                    variant: "plain"
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── The picked section ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: page

                anchors.fill: parent
                contentHeight: pageLoader.height + Theme.padding.drawer * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: pageLoader

                    x: Theme.padding.drawer + Theme.spacing.small
                    y: Theme.padding.drawer
                    width: page.width - x * 2
                    sourceComponent: root.pages[root.section] ?? lookPage
                    transform: Translate {
                        id: slide
                    }

                    onLoaded: {
                        page.contentY = 0;
                        pageIn.restart();
                    }
                }
            }

            // A thin thumb on the right while the page is longer than the window
            Rectangle {
                readonly property real track: parent.height - Theme.spacing.medium * 2

                visible: page.visibleArea.heightRatio < 1
                x: parent.width - width - Theme.spacing.small
                y: Theme.spacing.medium + page.visibleArea.yPosition * track
                width: Theme.spacing.small
                height: page.visibleArea.heightRatio * track
                radius: width / 2
                color: Theme.outline
                opacity: page.moving ? 1 : 0.5

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.small
                    }
                }
            }

            // A new page fades in and rises a little, like the mockup's rows
            ParallelAnimation {
                id: pageIn

                Anim {
                    target: pageLoader
                    property: "opacity"
                    from: 0
                    to: 1
                }
                Anim {
                    target: slide
                    property: "y"
                    from: 14
                    to: 0
                }
            }
        }
    }
}
