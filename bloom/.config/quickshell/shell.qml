import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.canvas
import qs.components
import qs.controlcenter
import qs.dashboard
import qs.draw
import qs.editor
import qs.gallery
import qs.hotkeys
import qs.keyboard
import qs.launcher
import qs.lockscreen
import qs.media
import qs.notifications
import qs.osd
import qs.screenshot
import qs.services
import qs.settings
import qs.voice
import qs.wallpapers

// The bloom style's entry point. Core {} starts what every style shares (services/Core.qml in
// core); the rest is this style: the frame with the bar on every screen, the drawers that
// slide out of it, the popups in the hole, the apps. CONTRACT.md says who owns what.
ShellRoot {
    Core {}

    Lock {
        id: lock

        // Panels leave the screen before the lockscreen takes its snapshot
        onAboutToLock: {
            dashboard.hide();
            controlCenter.hide();
            launcher.hide();
            history.hide();
            wallpapers.hide();
            keyboard.hide();
            hotkeys.hide();
            settings.hide();
            overview.close();
        }
    }

    // The frame around every screen, its top edge the bar
    Bar {
        hidden: lock.active
        dashboardOpen: dashboard.open
        controlCenterOpen: controlCenter.open
        launcherOpen: launcher.open
        historyOpen: history.open
        overviewOpen: overview.open

        onDashboardRequested: screen => dashboard.toggle(screen)
        onControlCenterRequested: screen => {
            history.hide();
            controlCenter.toggle(screen);
        }
        onLauncherRequested: screen => launcher.toggle(screen)
        onHistoryRequested: screen => {
            controlCenter.hide();
            history.toggle(screen);
        }
        onOverviewRequested: screen => overview.open ? overview.close() : overview.show()
        onLockRequested: lock.lock()
    }

    // Still wallpapers and the plain background (the moving ones come from frame-wallpaper)
    Backdrop {}

    // ── Drawers: out of the frame's edges ────────────────────

    // Top, under the clock: weather, media, GitHub, calendar, performance and tasks
    Dashboard {
        id: dashboard
    }

    // Right, under the status pill: quick tiles, sliders, the app mixer
    ControlCenter {
        id: controlCenter
        onLockRequested: lock.lock()
        onWallpapersRequested: wallpapers.show()
        onKeyboardRequested: keyboard.show()
        onSettingsRequested: settings.show("")
        onTasksRequested: dashboard.show(null, "performance")
    }

    // Bottom: apps, commands, files, Claude, wallpapers (Super+Space)
    Launcher {
        id: launcher
    }

    // The bell's history
    History {
        id: history
    }

    // ── Popups in the hole ───────────────────────────────────

    Popups {
        hidden: lock.active
    }

    // Shows fader, mute, volume and layout changes; never on the lockscreen
    Osd {
        hidden: lock.active
    }

    // The Spotify bloom: a disc out of the top border when the song changes
    SpotifyPopup {
        hidden: lock.active
    }

    // Discord voice: who is in your channel and who talks (Super+Shift+V moves it)
    VoiceOverlay {
        hidden: lock.active
    }

    // Hold Super for 1.5 seconds (hypr/frame/hotkeys.lua); closed while locked or while Super
    // is busy with the canvas overview
    HotkeyOverlay {
        id: hotkeys
        hidden: lock.active || overview.open
    }

    // ── The infinite canvas ──────────────────────────────────

    // Super+wheel zooms out to every window (facet layout canvas)
    CanvasOverview {
        id: overview
        hidden: lock.active
    }

    // Dragging empty canvas moves the view
    CanvasDesk {}

    // Pictures of the windows on screen, for the overview's off-screen ones
    CanvasThumbs {}

    // ── Tools and apps ───────────────────────────────────────

    // Print: region or window, Shift+Print: the screen (hypr/frame/shell.lua)
    Screenshot {
        hidden: lock.active
    }

    // Super+P: draw on the screen, again hides it; gone while locked
    DrawOverlay {
        hidden: lock.active
    }

    // Editors for recordings and pictures: "edit" on a notification or in the media app
    EditorWindow {}

    // Screenshots and recordings (Super+G)
    MediaApp {
        id: media
    }

    // Super+W
    WallpaperApp {
        id: wallpapers
    }

    // AULA F75 lighting, Fn keys and per-key colors (Super+K, keyboard package)
    KeyboardApp {
        id: keyboard
    }

    // qs ipc call preview popup notification|call|spotify (the settings' "Try it" buttons)
    IpcHandler {
        target: "preview"

        function popup(what: string): void {
            Bloom.preview(what);
        }
    }

    // Super+, or "settings" in the control center
    SettingsApp {
        id: settings
        onWallpapersRequested: wallpapers.show()
        onKeyboardRequested: keyboard.show()
    }
}
