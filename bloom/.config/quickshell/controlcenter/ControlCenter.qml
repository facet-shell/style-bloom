import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The control center: a drawer out of the right edge, under the status pill. Tabs: Quick
// (tiles, volume and brightness, the way to lock, wallpapers, keyboard, tasks and settings)
// and App mixer (every app with its own volume, on its GoXLR or virtual channel or its
// device). The task manager lives in the dashboard's Performance tab in bloom: tasks()
// asks for it with tasksRequested().
Scope {
    id: root

    signal lockRequested()
    signal wallpapersRequested()
    signal keyboardRequested()
    signal settingsRequested()
    signal tasksRequested()

    property bool open: false
    property ShellScreen screen: null
    // quick or mixer
    property string tab: "quick"

    // Settings' panel size; a game asks for a smaller panel when "compact in a game" is on
    readonly property real panelScale: Bloom.scale("panels") * (Bloom.compact("panels") ? 0.85 : 1)

    function show(screen) {
        root.screen = screen ?? Bloom.focusedScreen;
        open = true;
        // The faders are read more often while the mixer could be on screen
        GoXLR.fast = true;
    }

    function hide() {
        open = false;
        GoXLR.fast = false;
    }

    function toggle(screen) {
        if (open)
            hide();
        else
            show(screen);
    }

    // The other apps open once the drawer is on its way in
    function leaveFor(signalName) {
        hide();
        root[signalName]();
    }

    // Lock once the drawer is in, so the lockscreen's snapshot does not show it
    Timer {
        id: lockLater
        interval: Theme.anim.drawerOut + 80
        onTriggered: root.lockRequested()
    }

    Drawer {
        screen: root.screen
        edge: "right"
        align: "start"
        offset: 70
        open: root.open
        padding: Theme.padding.drawer * root.panelScale
        namespace: "qs-controlcenter"
        // Over a fullscreen game, when it is opened there
        windowLayer: Bloom.gaming ? WlrLayer.Overlay : WlrLayer.Top
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()

        // Scaled from its corner; the drawer takes the scaled size
        Item {
            implicitWidth: page.width * root.panelScale
            implicitHeight: page.implicitHeight * root.panelScale

            ColumnLayout {
                id: page

                width: 394
                scale: root.panelScale
                transformOrigin: Item.TopLeft
                spacing: Theme.spacing.large - 2

                Tabs {
                    model: [
                        { key: "quick", label: "Quick", icon: "tune" },
                        { key: "mixer", label: "App mixer", icon: "equalizer" }
                    ]
                    current: root.tab
                    onSelected: key => root.tab = key
                }

                Loader {
                    id: pane

                    Layout.fillWidth: true
                    sourceComponent: root.tab === "mixer" ? mixerTab : quickTab
                    onLoaded: paneIn.restart()
                }
            }

            // Each pane comes in from a little below
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
        id: quickTab

        QuickTab {
            onLockRequested: {
                root.hide();
                lockLater.restart();
            }
            onWallpapersRequested: root.leaveFor("wallpapersRequested")
            onKeyboardRequested: root.leaveFor("keyboardRequested")
            onSettingsRequested: root.leaveFor("settingsRequested")
            onTasksRequested: root.leaveFor("tasksRequested")
        }
    }

    Component {
        id: mixerTab

        Mixer {}
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show(null);
        }

        function close(): void {
            root.hide();
        }

        // The task manager: the dashboard's Performance tab in bloom
        function tasks(): void {
            root.hide();
            root.tasksRequested();
        }
    }
}
