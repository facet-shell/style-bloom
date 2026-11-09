import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// The settings window's content, laid out like Apple's: the categories as pills on the left
// with a search box above them, the picked category's menu on the right (MenuPage: its pages
// as rows with what each is set to), and a page opens over that menu with a back button.
// Shell settings go through Config (kept in ~/.config/facet/shell.json, the round arrow
// puts one back); style, theme and layout through the facet command; what needs sudo or
// shows output opens in a terminal of its own.
//
// One file per category (LookPage.qml …) holds all of its pages; it gets this view as `view`
// and shows the block for `view.page`. `qs ipc call settings section <name>` takes a category
// (tui's keys), a page as "category/page", or one of the aliases.
FocusScope {
    id: root

    signal closeRequested()
    signal wallpapersRequested()
    signal keyboardRequested()

    property string category: "look"
    // "" is the category's menu, else the key of one of its pages
    property string page: ""
    // +1 going deeper, -1 coming back: which way the content slides in
    property int direction: 1

    // key, label, icon, blurb; the pages, optionally in groups (group: "…" on a page starts
    // one), with `open` for rows that open an app instead of a page
    readonly property var categories: [
        { key: "look", label: "Appearance", icon: "palette", blurb: "The style, the colors, how windows lie, the wallpaper", pages: [
            { key: "style", label: "Style", icon: "auto_awesome", subtitle: "tui's square frames or bloom's rounded one" },
            { key: "colors", label: "Colors", icon: "palette", subtitle: "a theme, the wallpaper's colors, the album cover" },
            { key: "layout", label: "Layout and motion", icon: "grid_view", subtitle: "tiling or canvas, corners, animations" },
            { key: "wallpaper", label: "Wallpaper", icon: "wallpaper", subtitle: "pictures, videos and Wallpaper Engine scenes", open: "wallpapers" }
        ] },
        { key: "notifications", label: "Notifications", icon: "notifications", blurb: "How popups look, what comes through and when", pages: [
            { key: "popups", label: "Popups", icon: "picture_in_picture", subtitle: "corner, style, width, how long they stay" },
            { key: "groups", label: "Groups and replies", icon: "stacks", subtitle: "one stack per app, answer Discord from the card" },
            { key: "system", label: "System", icon: "desktop_windows", subtitle: "apps, critical ones, game mode", group: "What shows when" },
            { key: "discord", label: "Discord", icon: "forum", subtitle: "calls, messages, voice, events" },
            { key: "steam", label: "Steam", icon: "sports_esports", subtitle: "invites, friends, downloads" },
            { key: "spotify", label: "Spotify", icon: "music_note", subtitle: "the next song" }
        ] },
        { key: "popups", label: "Overlays", icon: "layers", blurb: "The things that come over the desktop: the song, the volume, the call, the panels", pages: [
            { key: "spotify", label: "Spotify bloom", icon: "music_note", subtitle: "the song popup: size, place, format" },
            { key: "osd", label: "Volume and faders", icon: "tune", subtitle: "the fader that moved, at the bottom" },
            { key: "voice", label: "Discord voice overlay", icon: "headset_mic", subtitle: "who is in the channel, over a game" },
            { key: "panels", label: "Panels", icon: "dock_to_bottom", subtitle: "dashboard, control center and launcher" }
        ] },
        { key: "games", label: "Games", icon: "sports_esports", blurb: "What changes while you play", pages: [
            { key: "mode", label: "Game mode", icon: "sports_esports", subtitle: "by itself, quiet, the frame steps away, the bar" },
            { key: "fps", label: "Fps overlay", icon: "speed", subtitle: "fps, cpu and gpu in a corner" },
            { key: "list", label: "Games", icon: "list", subtitle: "which apps count as games, the GoXLR profile" }
        ] },
        { key: "sound", label: "Sound", icon: "graphic_eq", blurb: "Where the sound goes, where it comes from, the channels", pages: [
            { key: "output", label: "Output", icon: "speaker", subtitle: "the device that plays" },
            { key: "input", label: "Input", icon: "mic", subtitle: "the microphone apps get" },
            { key: "channels", label: "Channels", icon: "tune", subtitle: "a GoXLR or virtual ones, and which app goes where" }
        ] },
        { key: "launcher", label: "Launcher", icon: "search", blurb: "What the launcher does with what you type", pages: [
            { key: "web", label: "Web search", icon: "language", subtitle: "the engine without a shortcut" },
            { key: "claude", label: "Claude", icon: "smart_toy", subtitle: "ask in the launcher, the model" },
            { key: "files", label: "Files and timers", icon: "folder", subtitle: "where file search looks, snooze" }
        ] },
        { key: "shell", label: "Lock screen", icon: "lock", blurb: "The lock, what it shows, the weather", pages: [
            { key: "lock", label: "Lock and screens", icon: "lock", subtitle: "blur, lock when idle, screens off" },
            { key: "ambient", label: "Ambient", icon: "bedtime", subtitle: "after a while the clock shrinks and drifts" },
            { key: "weather", label: "Weather", icon: "partly_cloudy_day", subtitle: "the city, how often" }
        ] },
        { key: "calendars", label: "Calendars", icon: "calendar_month", blurb: "iCloud and Google calendars in the dashboard", pages: [
            { key: "accounts", label: "Accounts", icon: "calendar_month", subtitle: "what is connected, remove one" },
            { key: "icloud", label: "Connect iCloud", icon: "cloud", subtitle: "Apple ID and an app-specific password", group: "Connect" },
            { key: "google", label: "Connect Google", icon: "account_circle", subtitle: "your own OAuth client, then the browser" }
        ] },
        { key: "apps", label: "Apps", icon: "widgets", blurb: "The facet modules and the apps around the shell", pages: [
            { key: "modules", label: "Modules", icon: "extension", subtitle: "update what is there, add what is not" },
            { key: "settings", label: "App settings", icon: "tune", subtitle: "Spotify's API, the keyboard, the GoXLR lights" }
        ] },
        { key: "system", label: "System", icon: "settings", blurb: "Updates, boot and login, housekeeping", pages: [
            { key: "updates", label: "Updates", icon: "system_update", subtitle: "packages and facet" },
            { key: "boot", label: "Boot and login", icon: "power_settings_new", subtitle: "the splash, the login screen" },
            { key: "housekeeping", label: "Housekeeping", icon: "cleaning_services", subtitle: "check, clean, the settings file" },
            { key: "about", label: "About", icon: "info", subtitle: "what runs" }
        ] }
    ]
    // Other names people (and the mockup) use for a place: a category, or "category/page"
    readonly property var aliases: ({
        notify: "notifications",
        rules: "notifications",
        popup: "popups",
        overlays: "popups",
        game: "games",
        audio: "sound",
        theme: "look/colors",
        themes: "look/colors",
        colors: "look/colors",
        style: "look/style",
        layout: "look/layout",
        lock: "shell",
        lockscreen: "shell",
        ambient: "shell/ambient",
        weather: "shell/weather",
        modules: "apps/modules",
        about: "system/about",
        updates: "system/updates",
        fps: "games/fps",
        voice: "popups/voice",
        spotify: "popups/spotify",
        output: "sound/output",
        input: "sound/input",
        channels: "sound/channels",
        claude: "launcher/claude",
        calendar: "calendars",
        icloud: "calendars/icloud",
        google: "calendars/google"
    })

    readonly property var current: categories.find(c => c.key === category) ?? categories[0]
    readonly property var currentPage: page === "" ? null : (current.pages.find(p => p.key === page) ?? null)

    readonly property string home: Quickshell.env("HOME")
    readonly property string facet: `${home}/.local/bin/facet`
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/facet`
    readonly property string modulesDir: `${Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"}/facet/modules`

    // [{ id, name, description, colors, tones }] from the facet command's themes
    property var themes: []
    property var installed: []
    property string about: ""
    property string status: ""

    // Each style keeps its own theme (facet: theme-<style>); bloom's default is nebula
    readonly property string currentTheme: themeState.text().trim() || "nebula"
    readonly property string currentLayout: layoutState.text().trim() === "canvas" ? "canvas" : "tiling"
    // This file only runs in bloom, so bloom until the state file says otherwise
    readonly property string currentStyle: styleState.text().trim() || "bloom"

    // ── Where you are ────────────────────────────────────────

    // A name from IPC to a place; unknown names keep what is open
    function goTo(name) {
        const n = String(name ?? "").trim().toLowerCase();
        const target = aliases[n] ?? n;
        const [c, p] = target.split("/");
        const cat = categories.find(x => x.key === c);
        if (!cat)
            return;
        direction = 1;
        category = cat.key;
        page = p && cat.pages.some(x => x.key === p) ? p : "";
    }

    function openPage(key) {
        const p = current.pages.find(x => x.key === key);
        if (!p)
            return;
        if (p.open === "wallpapers") {
            wallpapersRequested();
            return;
        }
        if (p.open === "keyboard") {
            keyboardRequested();
            return;
        }
        direction = 1;
        page = key;
    }

    function back() {
        if (page === "") {
            closeRequested();
            return;
        }
        direction = -1;
        page = "";
    }

    function pickCategory(key) {
        if (key === category && page === "")
            return;
        direction = page === "" ? 1 : -1;
        page = "";
        category = key;
    }

    // The pages of a category in groups: [{ title, pages }]; a page with `group` starts one
    function groupsOf(key) {
        const cat = categories.find(c => c.key === key);
        const groups = [];
        for (const p of cat?.pages ?? []) {
            if (p.group !== undefined || groups.length === 0)
                groups.push({ title: p.group ?? "", pages: [] });
            groups[groups.length - 1].pages.push(p);
        }
        return groups;
    }

    // What a page is set to, for the menu's right side (reads live values, so the row follows)
    function valueOf(cat, key) {
        const onOff = b => b ? "on" : "off";
        switch (`${cat}/${key}`) {
        case "look/style":
            return currentStyle;
        case "look/colors":
            return Config.colorMode === "dynamic" ? "from the wallpaper" : (themes.find(t => t.id === currentTheme)?.name ?? currentTheme);
        case "look/layout":
            return `${currentLayout} · ${Config.corners === "veryRound" ? "very round" : Config.corners}`;
        case "notifications/popups":
            return `${Config.notificationStyle} · ${Config.notificationPosition.replace("-", " ")}`;
        case "notifications/groups":
            return onOff(Config.notificationGroupByApp);
        case "popups/spotify":
            return `${Config.spotifyFormat} · ${Config.spotifyPosition.replace("-", " ")}`;
        case "popups/voice":
            return ({ always: "always", hidden: "Discord on no screen", game: "in game", never: "never" })[Config.voiceOverlayWhen] ?? "";
        case "games/mode":
            return Toggles.gameMode ? "on" : Config.gameModeAuto ? "by itself" : "off";
        case "games/fps":
            return onOff(Config.fpsOverlay);
        case "games/list":
            return Config.gameClasses.length > 0 ? `${Config.gameClasses.length} added` : "";
        case "sound/output":
            return Audio.masterOutput ? (Audio.masterOutput.description || Audio.masterOutput.nickname || Audio.masterOutput.name) : "";
        case "sound/channels":
            return Audio.channelSource === "goxlr" ? "GoXLR" : Audio.channelSource === "virtual" ? "virtual" : "none";
        case "launcher/web":
            return Config.searchEngines[Config.searchDefault]?.[0] ?? Config.searchDefault;
        case "launcher/claude":
            return Config.claudeEnabled ? (Config.claudeModel || "default model") : "off";
        case "shell/lock":
            return Config.idleLockMinutes > 0 ? `after ${Config.idleLockMinutes} min` : "never by itself";
        case "shell/ambient":
            return Config.lockAmbient ? `after ${Config.lockAmbientMinutes} min` : "off";
        case "shell/weather":
            return Config.weatherLocation || "from your connection";
        case "calendars/accounts":
            return Calendar.accountList.length > 0 ? `${Calendar.accountList.length} connected` : "none yet";
        case "apps/modules":
            return installed.length > 0 ? `${installed.length} installed` : "";
        case "system/updates":
            return Updates.total + Updates.frameCount > 0 ? `${Updates.total + Updates.frameCount} waiting` : Updates.checking ? "checking" : "up to date";
        default:
            return "";
        }
    }

    // ── Search ───────────────────────────────────────────────

    readonly property string query: search.text
    // Pages whose name, line or category matches, for the list under the search box
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const out = [];
        for (const c of categories)
            for (const p of c.pages) {
                const hay = `${p.label} ${p.subtitle ?? ""} ${c.label} ${p.group ?? ""}`.toLowerCase();
                if (hay.includes(q))
                    out.push({ category: c, page: p });
            }
        return out.slice(0, 10);
    }

    function openMatch(m) {
        search.text = "";
        forceActiveFocus();
        category = m.category.key;
        direction = 1;
        page = "";
        openPage(m.page.key);
    }

    // ── Keys ─────────────────────────────────────────────────

    function refresh() {
        themesProc.running = true;
        modulesProc.running = true;
        aboutProc.running = true;
        Calendar.checkAccounts(true);
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

    // Esc: a page goes back to its menu, the menu closes the window; Ctrl+F finds; Alt+Left
    // and Backspace go back; Ctrl+Tab and Ctrl+Shift+Tab (or Ctrl+PgDown/PgUp) walk the categories
    Keys.onEscapePressed: {
        if (query !== "") {
            search.text = "";
            return;
        }
        back();
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Backspace || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier))) {
            if (page !== "") {
                back();
                event.accepted = true;
            }
            return;
        }
        if (!(event.modifiers & Qt.ControlModifier))
            return;
        if (event.key === Qt.Key_F) {
            search.focusField();
            event.accepted = true;
            return;
        }
        const i = categories.findIndex(c => c.key === category);
        let d = 0;
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown)
            d = 1;
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp)
            d = -1;
        if (d === 0)
            return;
        pickCategory(categories[(i + d + categories.length) % categories.length].key);
        event.accepted = true;
    }

    onPageChanged: contentIn.restart()
    onCategoryChanged: contentIn.restart()

    // ── Files and commands ───────────────────────────────────

    Process {
        id: themesProc
        command: ["sh", "-c", 'd="${XDG_DATA_HOME:-$HOME/.local/share}/facet/cli/themes/bloom"; jq -c -n \'[inputs | { id: (input_filename | split("/") | last | rtrimstr(".json")), name, description, colors, tones }]\' "$d"/*.json']
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
        path: `${root.stateDir}/theme-bloom`
        printErrors: false
        // facet theme set writes it while the page is open: the pick follows at once
        watchChanges: true
        onFileChanged: reload()
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
        id: menuPage
        MenuPage {
            view: root
        }
    }
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
        id: calendarsPage
        CalendarsPage {
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
        calendars: calendarsPage,
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

        // ── Categories ──
        Rectangle {
            Layout.preferredWidth: 256
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

                SearchField {
                    id: search

                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.small
                    Layout.bottomMargin: Theme.spacing.medium
                    implicitHeight: Theme.control.button + 2
                    placeholder: "Search"
                    baseColor: Theme.high
                    onAccepted: {
                        if (root.matches.length > 0)
                            root.openMatch(root.matches[0]);
                    }
                    onEscaped: {
                        search.text = "";
                        root.forceActiveFocus();
                    }
                }

                // What the search found, instead of the pills
                Column {
                    Layout.fillWidth: true
                    visible: root.query !== ""
                    spacing: Theme.spacing.tiny

                    StyledText {
                        visible: root.matches.length === 0
                        x: Theme.padding.card
                        text: "nothing with that name"
                        dim: true
                        font.pixelSize: Theme.size.small
                    }

                    Repeater {
                        model: root.matches

                        delegate: Item {
                            id: hit

                            required property var modelData

                            width: parent.width
                            height: Theme.control.button + Theme.spacing.small

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: hitLayer.containsMouse ? Theme.high : "transparent"

                                Behavior on color {
                                    ColorAnim {}
                                }

                                StateLayer {
                                    id: hitLayer

                                    onClicked: root.openMatch(hit.modelData)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.padding.card
                                anchors.rightMargin: Theme.padding.card
                                spacing: Theme.spacing.medium

                                Icon {
                                    icon: hit.modelData.page.icon
                                    size: Theme.icon.normal - 1
                                    dim: true
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: hit.modelData.page.label
                                        font.pixelSize: Theme.size.small + 1
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: hit.modelData.category.label
                                        dim: true
                                        font.pixelSize: Theme.size.tiny
                                    }
                                }
                            }
                        }
                    }
                }

                // The pills, with one highlight that slides to the picked one
                Item {
                    Layout.fillWidth: true
                    visible: root.query === ""
                    implicitHeight: nav.implicitHeight

                    Rectangle {
                        readonly property Item target: navRepeater.count > 0 ? navRepeater.itemAt(Math.max(0, root.categories.findIndex(c => c.key === root.category))) : null

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

                            model: root.categories

                            delegate: Item {
                                id: navEntry

                                required property var modelData
                                readonly property bool picked: root.category === modelData.key

                                width: nav.width
                                height: Theme.control.button + Theme.spacing.small

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: "transparent"

                                    StateLayer {
                                        onClicked: root.pickCategory(navEntry.modelData.key)
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

        // ── The menu, or the open page ──
        Item {
            id: content

            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real gutter: Theme.padding.drawer + Theme.spacing.small

            // The menu or the page slides in from the side it comes from and fades
            ParallelAnimation {
                id: contentIn

                Anim {
                    target: contentBox
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.anim.medium
                }
                Anim {
                    target: contentSlide
                    property: "x"
                    from: 28 * root.direction
                    to: 0
                    duration: Theme.anim.medium
                }
            }

            ColumnLayout {
                id: contentBox

                anchors.fill: parent
                spacing: 0
                transform: Translate {
                    id: contentSlide
                }

                // Fixed at the top: back, where you are, what the page is about
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: content.gutter - (root.page !== "" ? Theme.spacing.small : 0)
                    Layout.rightMargin: content.gutter
                    Layout.topMargin: Theme.padding.drawer
                    Layout.bottomMargin: Theme.spacing.medium
                    spacing: Theme.spacing.small

                    IconButton {
                        visible: root.page !== ""
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        icon: "arrow_back"
                        onClicked: root.back()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            visible: root.page !== ""
                            text: root.current.label
                            color: Theme.primary
                            font.pixelSize: Theme.size.small
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.4
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentPage?.label ?? root.current.label
                            font.pixelSize: Theme.size.title
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentPage?.subtitle ?? root.current.blurb
                            dim: true
                            font.pixelSize: Theme.size.small
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: scroller

                        anchors.fill: parent
                        contentHeight: pageLoader.height + Theme.padding.drawer * 2
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Loader {
                            id: pageLoader

                            x: content.gutter
                            y: Theme.spacing.small
                            width: scroller.width - x * 2
                            sourceComponent: root.page === "" ? menuPage : (root.pages[root.category] ?? menuPage)

                            onLoaded: scroller.contentY = 0
                        }
                    }

                    // A thin thumb on the right while the page is longer than the window
                    Rectangle {
                        readonly property real track: parent.height - Theme.spacing.medium * 2

                        visible: scroller.visibleArea.heightRatio < 1
                        x: parent.width - width - Theme.spacing.small
                        y: Theme.spacing.medium + scroller.visibleArea.yPosition * track
                        width: Theme.spacing.small
                        height: scroller.visibleArea.heightRatio * track
                        radius: width / 2
                        color: Theme.outline
                        opacity: scroller.moving ? 1 : 0.5

                        Behavior on opacity {
                            Anim {
                                duration: Theme.anim.small
                            }
                        }
                    }
                }
            }
        }
    }
}
