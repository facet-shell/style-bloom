import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The dashboard: a drawer out of the top edge under the clock, opened by the logo and the
// clock in the bar. Tabs: Dashboard (weather with the next hours, media, GitHub in short,
// calendar, the next timer), Media (big cover and controls), GitHub (you or an
// organisation), Performance (gauges and the task manager). `qs ipc call controlcenter
// tasks` lands here on "performance" (shell.qml).
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null
    // home, media, github or performance
    property string tab: "home"
    // The GitHub tab's scope: "me" or an organisation's login
    property string ghScope: "me"

    readonly property var tabKeys: ["home", "media", "github", "performance"]
    // Settings' panel size; a game asks for a smaller panel when "compact in a game" is on
    readonly property real panelScale: Bloom.scale("panels") * (Bloom.compact("panels") ? 0.85 : 1)

    function show(screen, tab) {
        root.screen = screen ?? Bloom.focusedScreen;
        if (tab)
            root.tab = tab === "dashboard" ? "home" : tabKeys.includes(tab) ? tab : root.tab;
        open = true;
    }

    function hide() {
        open = false;
    }

    function toggle(screen) {
        if (open)
            hide();
        else
            show(screen, "");
    }

    function openGitHub(scope) {
        ghScope = scope;
        tab = "github";
    }

    // GitHub is asked when the dashboard opens (the short card is on the first tab too),
    // the organisation only while its scope is picked
    onOpenChanged: {
        if (open)
            askGitHub(false);
    }
    onTabChanged: askGitHub(false)
    onGhScopeChanged: askGitHub(false)

    function askGitHub(force) {
        if (!open)
            return;
        gh.refresh(force);
        if (tab === "github" && ghScope !== "me")
            gh.refreshOrg(ghScope, force);
    }

    GitHubData {
        id: gh

        // The login came in after the dashboard asked for the organisation
        onStatusChanged: {
            if (gh.status === "ok" && root.open && root.tab === "github" && root.ghScope !== "me")
                gh.refreshOrg(root.ghScope, false);
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.open
        onTriggered: root.askGitHub(true)
    }

    // The task list is only read while it is on screen
    Binding {
        target: Tasks
        property: "active"
        value: root.open && root.tab === "performance"
    }

    // ── Media: which player the cards show ───────────────────

    // Picked by hand with the chips on the media tab; otherwise the one that started
    // playing last, like the media keys (services/Core.qml)
    property MprisPlayer picked: null
    property MprisPlayer last: null
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        if (picked && list.includes(picked))
            return picked;
        if (last && list.includes(last))
            return last;
        const spotify = list.find(p => p.identity === "Spotify");
        return (spotify?.isPlaying ? spotify : null) ?? list.find(p => p.isPlaying) ?? spotify ?? list[0] ?? null;
    }

    Variants {
        model: Mpris.players.values

        Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying) {
                    root.last = modelData;
                    root.picked = null;
                }
            }
        }
    }

    // Positions are only sent on seeks; this keeps progress bars moving while visible
    Timer {
        interval: 1000
        repeat: true
        running: root.open && (root.player?.isPlaying ?? false) && (root.tab === "home" || root.tab === "media")
        onTriggered: root.player.positionChanged()
    }

    // ── The drawer ───────────────────────────────────────────

    Drawer {
        id: drawer

        screen: root.screen
        edge: "top"
        open: root.open
        padding: Theme.padding.drawer * root.panelScale
        namespace: "qs-dashboard"
        // Over a fullscreen game, when it is opened there
        windowLayer: Bloom.gaming ? WlrLayer.Overlay : WlrLayer.Top
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()

        // Scaled from its corner; the drawer takes the scaled size
        Item {
            implicitWidth: page.implicitWidth * root.panelScale
            implicitHeight: page.implicitHeight * root.panelScale

            ColumnLayout {
                id: page

                scale: root.panelScale
                transformOrigin: Item.TopLeft
                spacing: Theme.spacing.large - 2

                Tabs {
                    Layout.alignment: Qt.AlignHCenter
                    model: [
                        { key: "home", label: "Dashboard", icon: "dashboard" },
                        { key: "media", label: "Media", icon: "music_note" },
                        { key: "github", label: "GitHub", icon: "commit" },
                        { key: "performance", label: "Performance", icon: "monitoring" }
                    ]
                    current: root.tab
                    onSelected: key => root.tab = key
                }

                Loader {
                    id: pane

                    Layout.preferredWidth: 864
                    sourceComponent: root.tab === "media" ? mediaTab
                        : root.tab === "github" ? githubTab
                        : root.tab === "performance" ? performanceTab
                        : homeTab

                    // Each pane comes in from a little below
                    onLoaded: paneIn.restart()
                }
            }

            ParallelAnimation {
                id: paneIn

                Anim {
                    target: pane.item
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.anim.normal
                }
                Anim {
                    target: pane.item
                    property: "y"
                    from: 10
                    to: 0
                    duration: Theme.anim.normal
                }
            }
        }
    }

    Component {
        id: homeTab

        HomeTab {
            width: 864
            player: root.player
            github: gh
            onGithubRequested: root.openGitHub("me")
            onMediaRequested: root.tab = "media"
        }
    }

    Component {
        id: mediaTab

        MediaTab {
            width: 864
            player: root.player
            onPlayerPicked: player => root.picked = player
        }
    }

    Component {
        id: githubTab

        GitHubTab {
            width: 864
            github: gh
            scope: root.ghScope
            onScopePicked: scope => root.ghScope = scope
            onRefreshRequested: root.askGitHub(true)
        }
    }

    Component {
        id: performanceTab

        PerformanceTab {
            width: 864
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show(null, "");
        }

        function close(): void {
            root.hide();
        }

        // home, media, github or performance
        function tab(name: string): void {
            root.show(null, name);
        }
    }
}
