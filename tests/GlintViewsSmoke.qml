import QtQuick
import QtQuick.Window
import Quickshell
import qs.launcher
import qs.wallpapers
import qs.services
import qs.config
import "services/Fixture.js" as Fixture

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
    Window {
        visible: true
        width: 440
        height: 400
        GlintSettings { id: narrowControls; width: parent.width; section: "general"; output: "*"; projectPath: "/test/42" }
    }
    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = findItem(child, name);
            if (found) return found;
        }
        return null;
    }
    function checkSettingsLayout() {
        const grid = findItem(narrowControls, "glintGeneralSettings");
        if (!grid || grid.children.length !== 10 || grid.width > narrowControls.width + 1) {
            console.error("Settings do not fit their column"); Qt.exit(1); return;
        }
        for (let i = 0; i < 10; i += 2) {
            const label = grid.children[i], editor = grid.children[i + 1];
            if (label.x + label.width > editor.x || editor.x + editor.width > grid.width + 1 || editor.height <= 0 || (i > 0 && editor.y < grid.children[i - 1].y + grid.children[i - 1].height)) {
                console.error("Settings rows overlap", i, narrowControls.width); Qt.exit(1); return;
            }
            const fields = editor.children.filter(child => child.visible && child.width > 0 && child.height > 0);
            for (let j = 0; j < fields.length; j++) {
                if (fields[j].x < 0 || fields[j].x + fields[j].width > editor.width + 1 || (j > 0 && fields[j - 1].x + fields[j - 1].width > fields[j].x + 1)) {
                    console.error("Settings controls overlap", i, narrowControls.width); Qt.exit(1); return;
                }
            }
        }
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
            test.checkSettingsLayout();
            if (test.phase === 0) {
                if (Theme.frame === undefined) { console.error("Structural theme frame token missing"); Qt.exit(1); return; }
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
                narrowControls.width = 360;
                Wallpapers.setDisplaySetting("*", "fps", 120);
            } else if (test.phase === 1) {
                if (controls.common.fps !== 120 || controls.common.mixed.fps) { console.error("Native FPS binding did not update"); Qt.exit(1); return; }
                narrowControls.width = 620;
                menu.page = "library";
                menu.current = menu.list.findIndex(w => w.id === "42");
                menu.apply(false);
            } else if (test.phase === 2) {
                if (Wallpapers.current("*") !== "/test/42") { console.error("Launcher did not apply the wallpaper"); Qt.exit(1); return; }
                menu.touched = true;
                Fixture.externalSet("/other/video/movie.mp4");
            } else if (test.phase === 3) {
                if (menu.selected?.path !== "/other/video" || !menu.selectedInUse) { console.error("External wallpaper change did not select its tile"); Qt.exit(1); return; }
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
