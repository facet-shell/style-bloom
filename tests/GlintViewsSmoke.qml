import QtQuick
import QtQuick.Window
import Quickshell
import qs.launcher
import qs.wallpapers
import qs.services

ShellRoot {
    id: test
    property int phase: 0
    Component.onCompleted: Wallpapers.refresh()
    Item {
        id: fakeModes
        function wallFilter(items, tab, word) { return items; }
        function wallPicture(item) { return ""; }
    }
    Window {
        visible: true
        width: 1180
        height: 960
        WallMenu { id: menu; modes: fakeModes; width: 1144; screenName: "DP-2" }
    }
    Window {
        visible: true
        width: 1180
        height: 960
        WallpaperView { id: drawer; width: 1144 }
    }
    QtObject {
        id: sharedLauncher
        property bool open: false
        property bool wallBig: false
        property string preset: ""
        function show(text) { preset = text; wallBig = text === "wall"; open = true; }
        function hide() { open = false; }
    }
    WallpaperApp { id: wallpaperShortcut; controller: sharedLauncher }
    GlintSettings { id: controls; width: 1100; output: "*"; projectPath: "/test/42" }
    Timer {
        running: true
        repeat: true
        interval: 500
        onTriggered: {
            if (test.phase === 0) {
                if (!Wallpapers.glintActive || controls.properties.length !== 5 || !controls.common.mixed.fps) {
                    console.error("Native settings missing", Wallpapers.glintActive, controls.properties.length);
                    Qt.exit(1);
                    return;
                }
                if (menu.width !== 1144 || menu.implicitHeight > 500) { console.error("Wallpaper menu dimensions changed", menu.width, menu.implicitHeight); Qt.exit(1); return; }
                menu.nextTab(1);
                if (menu.page !== "general") { console.error("General settings tab missing"); Qt.exit(1); return; }
                menu.nextTab(1);
                if (menu.page !== "wallpaper") { console.error("Project settings tab missing"); Qt.exit(1); return; }
                wallpaperShortcut.show();
                if (!wallpaperShortcut.open || sharedLauncher.preset !== "wall") { console.error("Super+W did not open the shared launcher"); Qt.exit(1); return; }
                wallpaperShortcut.toggle();
                if (sharedLauncher.open) { console.error("Shared menu toggle failed"); Qt.exit(1); return; }
                Wallpapers.setDisplaySetting("*", "fps", 120);
            } else if (test.phase === 1) {
                if (controls.common.fps !== 120 || controls.common.mixed.fps) { console.error("Native FPS binding did not update"); Qt.exit(1); return; }
                menu.page = "library";
                menu.current = menu.list.findIndex(w => w.id === "42");
                menu.apply(false);
            } else if (test.phase === 2) {
                if (Wallpapers.current("*") !== "/test/42") { console.error("Launcher did not apply the wallpaper"); Qt.exit(1); return; }
                drawer.current = drawer.shown.findIndex(w => w.id === "42");
                drawer.target = "HDMI-A-1";
                drawer.applyCurrent();
            } else {
                if (Wallpapers.current("HDMI-A-1") !== "/test/42") { Qt.exit(1); return; }
                console.log("Glint views smoke passed");
                Qt.quit();
            }
            test.phase++;
        }
    }
}
