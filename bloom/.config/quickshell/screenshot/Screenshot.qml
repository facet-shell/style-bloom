import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// Screenshots and the recording picker. Print freezes every screen (the shot is cut out of
// that frozen picture, so it shows the moment the key was pressed); on the focused screen a
// drawer comes out of the bottom edge with what to take (region, window, screen) and how
// (picture or recording). Region: drag a region or click a window (it lights up under the
// cursor). Window: a click takes the window under the cursor. Screen: a click takes that
// screen. Enter takes the whole screen in every mode, Esc or a right click cancels.
// Shift+Print takes the focused screen right away. The picture goes to ~/Pictures/screenshots
// (your XDG pictures folder), lands in the clipboard, and a notification shows it with
// "open", "edit", "folder" and "delete". grim does the capture, wl-copy the clipboard.
//
// Recording (Super+Shift+R, services/Recorder.qml): the same picker on the live screen, the
// drawer grows the audio panel (which channels go in, at what level; the choice is kept).
// While it runs a small pill in the hole shows the time; a click on it, or the same key
// again, stops it.
//
// `qs ipc call screenshot region|screen|record|toggle|close`
Scope {
    id: root

    property bool hidden: false
    property bool open: false

    property real shown: open && !hidden ? 1 : 0
    // Short: a live capture starts 220 ms after the picker leaves (captureDelay)
    Behavior on shown {
        Anim {
            duration: Theme.anim.fast
        }
    }

    // What a click takes: "region" (drag a region, or click a window), "window" or "screen"
    property string pick: "region"
    // The screen with the toolbar (focused when the picker opened)
    property string barScreen: ""

    // Pictures folder from XDG (xdg-user-dir), ~/Pictures until that answered
    property string picturesDir: `${Quickshell.env("HOME")}/Pictures`
    readonly property string folder: `${picturesDir}/screenshots`

    // Monitors and the windows on their visible workspaces, from hyprctl, taken when the
    // tool opens: [{ name, x, y, w, h, scale }], [{ address, class, title, x, y, w, h, monitor }]
    // in layout coordinates, windows most recently focused first
    property var monitors: []
    property var windows: []

    property string pendingFile: ""
    property var pendingArgs: []
    // The same picker for a screen recording (services/Recorder.qml) instead of a picture
    property bool recordMode: false

    // Freeze first: Print grabs every screen right away (grim -o, one PNG each), the picker
    // shows exactly those pictures and the shot is cut out of them (ffmpeg crop). Menus,
    // tooltips and video frames are taken as they were when the key was pressed. Without
    // ffmpeg, or for a recording, the picker works on the live screen.
    readonly property string frozenDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/frame-shot`
    property bool frozen: false
    property bool hasFfmpeg: false

    function frozenFile(name) {
        return `${frozenDir}/${name}.png`;
    }

    function show() {
        if (hidden || open || freezeProc.running || grimProc.running)
            return;
        barScreen = Bloom.focusedScreen?.name ?? Quickshell.screens[0]?.name ?? "";
        monitorsProc.running = true;
        frozen = false;
        if (recordMode || !hasFfmpeg) {
            open = true;
            return;
        }
        // The picker opens once the screens are taken, so it is not in them
        freezeProc.command = ["bash", "-c", 'd=$1; shift; mkdir -p "$d" && rm -f "$d"/*.png; for n in "$@"; do grim -o "$n" "$d/$n.png" & done; wait; for n in "$@"; do [ -s "$d/$n.png" ] || exit 1; done', "frame-freeze", frozenDir]
            .concat(Quickshell.screens.map(s => s.name));
        freezeProc.running = true;
    }

    function close() {
        open = false;
        recordMode = false;
        dropFrozen();
    }

    // The frozen screens sit in RAM (XDG_RUNTIME_DIR); gone once the shot is taken or cancelled
    function dropFrozen() {
        Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.png', "frame-freeze", frozenDir]);
    }

    Process {
        id: freezeProc
        onExited: code => {
            root.frozen = code === 0;
            if (!root.hidden)
                root.open = true;
        }
    }

    Process {
        command: ["sh", "-c", "command -v ffmpeg"]
        running: true
        onExited: code => root.hasFfmpeg = code === 0
    }

    function monitorNamed(name) {
        return monitors.find(m => m.name === name) ?? null;
    }

    // Windows on that monitor, topmost first
    function windowsOn(name) {
        return windows.filter(w => w.monitor === name);
    }

    function windowAt(name, x, y) {
        return windowsOn(name).find(w => x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h) ?? null;
    }

    function stamp() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        // Milliseconds too: two shots in the same second must not share a file
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}-${String(d.getMilliseconds()).padStart(3, "0")}`;
    }

    // A rectangle in layout coordinates on monitor `name`: cut out of the frozen screen, or
    // taken live once the overlays have left (they must not be in the picture)
    function captureRect(x, y, w, h, name) {
        if (w < 2 || h < 2)
            return;
        const mon = monitorNamed(name);
        if (open && frozen && !recordMode && mon) {
            cropFrozen(mon, x, y, w, h);
            return;
        }
        start(["-g", `${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}`]);
    }

    function captureOutput(name) {
        // Only the open picker uses the frozen screens; Shift+Print takes the live one
        if (open && frozen && !recordMode) {
            takeFrozen(name, ["cp", "--", frozenFile(name)]);
            return;
        }
        start(["-o", name]);
    }

    // Layout coordinates → the frozen PNG's pixels (it has the monitor's real resolution),
    // clipped to the monitor: a window can reach past its edge
    function cropFrozen(mon, x, y, w, h) {
        const sx = mon.pw / mon.w, sy = mon.ph / mon.h;
        const x0 = Math.max(0, Math.round((x - mon.x) * sx)), y0 = Math.max(0, Math.round((y - mon.y) * sy));
        const x1 = Math.min(mon.pw, Math.round((x - mon.x + w) * sx)), y1 = Math.min(mon.ph, Math.round((y - mon.y + h) * sy));
        if (x1 - x0 < 2 || y1 - y0 < 2)
            return;
        takeFrozen(mon.name, ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", frozenFile(mon.name),
            "-vf", `crop=${x1 - x0}:${y1 - y0}:${x0}:${y0}`, "-frames:v", "1", "-update", "1"]);
    }

    // cmd gets the new file's path as its last argument; no delay, the overlays are not in it
    function takeFrozen(name, cmd) {
        if (grimProc.running)
            return;
        pendingFile = `${folder}/screenshot-${stamp()}.png`;
        open = false;
        grimProc.command = ["sh", "-c", 'f=$1; shift; mkdir -p "$(dirname "$f")" && "$@" "$f" && wl-copy --type image/png < "$f"', "frame-shot", pendingFile].concat(cmd);
        grimProc.running = true;
    }

    function start(args) {
        // One shot at a time: a second one would change the file name under the first
        if (captureDelay.running || grimProc.running || (recordMode && Recorder.recording))
            return;
        pendingFile = recordMode ? "" : `${folder}/screenshot-${stamp()}.png`;
        pendingArgs = args;
        open = false;
        captureDelay.restart();
    }

    // The picker's fade has to be gone from the screen before grim or wf-recorder looks
    Timer {
        id: captureDelay
        interval: 220
        onTriggered: {
            if (root.recordMode) {
                root.recordMode = false;
                Recorder.start(root.pendingArgs);
                return;
            }
            grimProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && grim "$2" "$3" "$1" && wl-copy --type image/png < "$1"', "frame-shot", root.pendingFile].concat(root.pendingArgs);
            grimProc.running = true;
        }
    }

    Process {
        id: grimProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") console.warn(`screenshot: ${this.text.trim()}`)
        }
        onExited: code => {
            root.dropFrozen();
            const file = root.pendingFile;
            const name = file.slice(file.lastIndexOf("/") + 1);
            if (code !== 0) {
                Notifications.push({ app: "screenshot", title: "screenshot failed", body: "grim could not capture (is it installed?)", glyph: "✗", icon: "error" });
                return;
            }
            Notifications.push({
                app: "screenshot",
                title: "screenshot saved",
                body: `${name} · in the clipboard`,
                image: file,
                icon: "screenshot_region",
                actions: [
                    { id: "open", label: "open", style: "ok" },
                    { id: "edit", label: "edit", style: "" },
                    { id: "folder", label: "folder", style: "" },
                    { id: "delete", label: "delete", style: "" }
                ],
                onAction: id => {
                    if (id === "open")
                        Quickshell.execDetached(["xdg-open", file]);
                    else if (id === "edit")
                        // Blur a name, put a picture on it, crop (the editor part)
                        Editor.open(file);
                    else if (id === "folder")
                        Quickshell.execDetached(["xdg-open", root.folder]);
                    else if (id === "delete")
                        // With the edit the picture editor kept for it
                        Quickshell.execDetached(["rm", "-f", "--", file, file.replace(/\.[^./]+$/, "") + ".edit.json"]);
                }
            });
        }
    }

    Process {
        id: picturesProc
        command: ["xdg-user-dir", "PICTURES"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = this.text.trim();
                if (dir !== "")
                    root.picturesDir = dir;
            }
        }
    }

    Process {
        id: monitorsProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(this.text).map(m => ({
                        name: m.name, x: m.x, y: m.y, w: m.width / (m.scale || 1), h: m.height / (m.scale || 1),
                        // Real pixels, for cutting the frozen picture
                        pw: m.width, ph: m.height,
                        workspaces: [m.activeWorkspace?.id, m.specialWorkspace?.id].filter(id => id !== undefined && id !== 0)
                    }));
                } catch (e) {
                    console.warn(`screenshot: monitors: ${e}`);
                }
            }
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(this.text)
                        .filter(c => c.mapped && !c.hidden)
                        .sort((a, b) => (a.focusHistoryID ?? 999) - (b.focusHistoryID ?? 999));
                    root.windows = list.map(c => {
                        const mon = root.monitors.find(m => m.workspaces.includes(c.workspace?.id)) ?? null;
                        return { address: c.address, class: c.class, title: c.title, x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1], monitor: mon?.name ?? "" };
                    }).filter(w => w.monitor !== "");
                } catch (e) {
                    console.warn(`screenshot: clients: ${e}`);
                }
            }
        }
    }

    // Windows are matched to monitors through the monitors list, so read them after it
    Connections {
        target: monitorsProc
        function onExited() {
            clientsProc.running = true;
        }
    }

    onHiddenChanged: if (hidden) close()

    // A key and what it does, for the hint line
    component KeyHint: RowLayout {
        id: hint

        property string key: ""
        property string label: ""

        spacing: 6

        Rectangle {
            implicitWidth: Math.max(22, keyText.implicitWidth + 12)
            implicitHeight: 22
            radius: Theme.rounding.small * 0.7
            color: Theme.high

            StyledText {
                id: keyText

                anchors.centerIn: parent
                text: hint.key
                font.pixelSize: Theme.size.tiny
                font.weight: Font.Medium
            }
        }
        StyledText {
            text: hint.label
            dim: true
            font.pixelSize: Theme.size.small
        }
    }

    Variants {
        model: root.open || root.shown > 0.01 ? Quickshell.screens : []

        PanelWindow {
            id: overlay

            required property ShellScreen modelData
            readonly property var mon: root.monitorNamed(modelData.name)
            readonly property real offX: mon?.x ?? 0
            readonly property real offY: mon?.y ?? 0
            readonly property bool hasBar: modelData.name === root.barScreen
            readonly property color accent: root.recordMode ? Theme.error : Theme.primary

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-screenshot"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // The screen as it was when Print was pressed: the frozen picture the shot is cut
            // from, or (recording, no ffmpeg) a still of the screen
            Image {
                anchors.fill: parent
                visible: root.frozen
                source: root.frozen ? "file://" + root.frozenFile(overlay.modelData.name) : ""
                cache: false
                smooth: true
                fillMode: Image.Stretch
            }

            ScreencopyView {
                anchors.fill: parent
                visible: !root.frozen
                captureSource: root.frozen ? null : overlay.modelData
                live: false
                paintCursor: false
            }

            // Selection in this screen's coordinates
            property bool dragging: false
            property real selX: 0
            property real selY: 0
            property real selW: 0
            property real selH: 0
            readonly property bool overToolbar: toolbar.hovered
            readonly property var hoverWindow: root.open && !dragging && !overToolbar && root.pick !== "screen"
                ? root.windowAt(modelData.name, area.mouseX + offX, area.mouseY + offY) : null
            // What a click or Enter would take: the dragged region, else the window under the
            // cursor; in screen mode the whole screen
            readonly property rect target: root.pick === "screen" && root.open && area.containsMouse ? Qt.rect(0, 0, width, height)
                : dragging && selW > 2 && selH > 2 ? Qt.rect(selX, selY, selW, selH)
                : hoverWindow ? Qt.rect(hoverWindow.x - offX, hoverWindow.y - offY, hoverWindow.w, hoverWindow.h)
                : Qt.rect(0, 0, 0, 0)
            readonly property bool hasTarget: target.width > 0

            // Darken everything but the target (four rectangles around it)
            Repeater {
                model: 4

                Rectangle {
                    required property int index

                    color: Theme.page
                    opacity: 0.5 * root.shown
                    // 0 top (full width), 1 right, 2 bottom (full width), 3 left
                    x: index === 1 ? overlay.target.x + overlay.target.width : 0
                    y: index === 0 ? 0 : index === 2 ? overlay.target.y + overlay.target.height : overlay.target.y
                    width: index === 0 || index === 2 ? overlay.width : index === 1 ? overlay.width - (overlay.target.x + overlay.target.width) : overlay.target.x
                    height: index === 0 ? (overlay.hasTarget ? overlay.target.y : overlay.height) : index === 2 ? overlay.height - (overlay.target.y + overlay.target.height) : overlay.target.height
                    visible: overlay.hasTarget || index === 0
                }
            }

            // The target's outline (square: it is exactly what is taken) and its size
            Rectangle {
                visible: overlay.hasTarget
                x: overlay.target.x
                y: overlay.target.y
                width: overlay.target.width
                height: overlay.target.height
                color: "transparent"
                border.width: 2
                border.color: overlay.accent
                opacity: root.shown

                Rectangle {
                    // Above the target, or inside it when it touches the top
                    readonly property bool inside: overlay.target.y < height + 12

                    y: inside ? 10 : -height - 8
                    anchors.left: parent.left
                    anchors.leftMargin: inside ? 10 : 0
                    implicitWidth: labelRow.implicitWidth + 22
                    implicitHeight: 30
                    radius: height / 2
                    color: Theme.surface

                    RowLayout {
                        id: labelRow

                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            icon: root.recordMode ? "videocam" : overlay.dragging ? "crop_free" : root.pick === "screen" ? "desktop_windows" : "web_asset"
                            size: Theme.icon.small
                            color: overlay.accent
                        }
                        StyledText {
                            text: overlay.dragging || root.pick === "screen"
                                ? `${Math.round(overlay.target.width)} × ${Math.round(overlay.target.height)}`
                                : `${overlay.hoverWindow?.class ?? ""} · ${Math.round(overlay.target.width)} × ${Math.round(overlay.target.height)}`
                            tabular: true
                            font.pixelSize: Theme.size.small
                        }
                    }
                }
            }

            // Crosshair lines through the cursor while nothing is selected
            Rectangle {
                visible: root.open && !overlay.dragging && !overlay.overToolbar && root.pick === "region" && area.containsMouse
                x: area.mouseX
                y: 0
                width: 1
                height: parent.height
                color: Theme.outline
                opacity: 0.7 * root.shown
            }
            Rectangle {
                visible: root.open && !overlay.dragging && !overlay.overToolbar && root.pick === "region" && area.containsMouse
                x: 0
                y: area.mouseY
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.7 * root.shown
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.pick === "region" ? Qt.CrossCursor : Qt.PointingHandCursor

                property real pressX: 0
                property real pressY: 0

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.close();
                        return;
                    }
                    pressX = mouse.x;
                    pressY = mouse.y;
                    overlay.dragging = false;
                }
                onPositionChanged: mouse => {
                    if (!pressed || !(mouse.buttons & Qt.LeftButton) || root.pick !== "region")
                        return;
                    if (!overlay.dragging && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 4)
                        overlay.dragging = true;
                    if (overlay.dragging) {
                        overlay.selX = Math.min(pressX, mouse.x);
                        overlay.selY = Math.min(pressY, mouse.y);
                        overlay.selW = Math.abs(mouse.x - pressX);
                        overlay.selH = Math.abs(mouse.y - pressY);
                    }
                }
                onReleased: mouse => {
                    if (mouse.button !== Qt.LeftButton)
                        return;
                    if (overlay.dragging) {
                        overlay.dragging = false;
                        root.captureRect(overlay.selX + overlay.offX, overlay.selY + overlay.offY, overlay.selW, overlay.selH, overlay.modelData.name);
                    } else if (overlay.hoverWindow) {
                        const w = overlay.hoverWindow;
                        root.captureRect(w.x, w.y, w.w, w.h, w.monitor);
                    } else if (root.pick !== "window") {
                        // Window mode: a click on no window takes nothing
                        root.captureOutput(overlay.modelData.name);
                    }
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: root.open
                Keys.onEscapePressed: root.close()
                Keys.onReturnPressed: root.captureOutput(overlay.modelData.name)
                Keys.onEnterPressed: root.captureOutput(overlay.modelData.name)
                Keys.onSpacePressed: {
                    if (overlay.hoverWindow)
                        root.captureRect(overlay.hoverWindow.x, overlay.hoverWindow.y, overlay.hoverWindow.w, overlay.hoverWindow.h, overlay.hoverWindow.monitor);
                    else
                        root.captureOutput(overlay.modelData.name);
                }
            }

            // ── The toolbar: a drawer out of the bottom edge of the focused screen ──
            // Drawn in this window (a Drawer is its own layer and could end up under it)
            Item {
                id: toolbar

                // The frame's bottom edge; the screen's edge while the frame is away
                readonly property real base: overlay.height - (Bloom.frameAway ? 0 : Theme.frame.border)
                readonly property real pad: Theme.padding.drawer
                readonly property real fillet: Theme.rounding.fillet
                readonly property real bodyW: Math.max(body.implicitWidth, 200) + pad * 2
                readonly property real bodyH: body.implicitHeight + pad * 2
                property real shownW: bodyW
                property real shownH: bodyH
                // Slides out once the window is there; on the way out it fades with the
                // picker instead, so it is gone before a live capture looks
                property real progress: 0
                readonly property real extent: progress * shownH
                readonly property real contentShown: root.open ? Math.max(0, (progress - 0.35) / 0.65) : Math.max(0, progress * 1.5 - 0.5)
                readonly property bool hovered: toolbarMouse.containsMouse

                anchors.fill: parent
                visible: overlay.hasBar && progress > 0.001
                opacity: root.shown

                Behavior on progress {
                    Anim {
                        duration: Theme.anim.drawerIn
                    }
                }
                // The audio panel coming in grows the drawer instead of jumping (not while it
                // slides out: the first layout would wobble)
                Behavior on shownW {
                    enabled: toolbar.progress > 0.99
                    Anim {
                        duration: Theme.anim.drawerOut
                    }
                }
                Behavior on shownH {
                    enabled: toolbar.progress > 0.99
                    Anim {
                        duration: Theme.anim.drawerOut
                    }
                }

                // Body and joints as one path, like components/Drawer.qml for the bottom edge
                function silhouette() {
                    const L = shownW, E = extent, F = fillet;
                    if (E < 0.5 || L <= 0)
                        return "";
                    const f = Math.min(F, E);
                    const r = Math.max(0, Math.min(Theme.rounding.drawer, E - f, L / 2));
                    const u0 = (width - L) / 2 - F;
                    const p = (u, v) => `${u0 + u} ${base - v}`;
                    const arc = (rad, sweep, u, v) => rad > 0 ? `A ${rad} ${rad} 0 0 ${sweep} ${p(u, v)} ` : `L ${p(u, v)} `;
                    let d = `M ${p(F - f, 0)} L ${p(F + L + f, 0)} `;
                    d += arc(f, 1, F + L, f);
                    d += `L ${p(F + L, E - r)} `;
                    d += arc(r, 0, F + L - r, E);
                    d += `L ${p(F + r, E)} `;
                    d += arc(r, 0, F, E - r);
                    d += `L ${p(F, f)} `;
                    d += arc(f, 1, F - f, 0);
                    return d + "Z";
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.surface
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: toolbar.silhouette()
                        }
                    }
                }

                // The part that is out; the content slides with the body's top
                Item {
                    id: clipper

                    x: (toolbar.width - toolbar.shownW) / 2
                    y: toolbar.base - toolbar.extent
                    width: toolbar.shownW
                    height: toolbar.extent
                    clip: true

                    // Clicks on the toolbar never reach the picker below
                    MouseArea {
                        id: toolbarMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => wheel.accepted = true
                    }

                    ColumnLayout {
                        id: body

                        x: toolbar.pad
                        y: toolbar.pad + 8 * (1 - toolbar.contentShown)
                        width: toolbar.shownW - toolbar.pad * 2
                        spacing: Theme.spacing.medium
                        opacity: toolbar.contentShown

                        // ── Recording: which sound goes in, at what level ──
                        Card {
                            Layout.fillWidth: true
                            visible: root.recordMode
                            padding: Theme.padding.normal

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacing.normal

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacing.normal

                                    Icon {
                                        icon: "graphic_eq"
                                        size: Theme.icon.small
                                        color: Theme.error
                                    }
                                    StyledText {
                                        text: "sound"
                                        font.pixelSize: Theme.size.small + 1
                                        font.weight: Font.Medium
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Recorder.chosen.length > 0 ? Recorder.chosen.map(c => c.label).join(", ") : "none, picture only"
                                        dim: true
                                        font.pixelSize: Theme.size.small
                                    }
                                }

                                Repeater {
                                    model: Recorder.channels

                                    delegate: RowLayout {
                                        id: channelRow

                                        required property var modelData
                                        readonly property var state: Recorder.channelState(modelData.key)

                                        Layout.fillWidth: true
                                        spacing: Theme.spacing.medium

                                        Chip {
                                            Layout.preferredWidth: 130
                                            text: channelRow.modelData.label
                                            icon: channelRow.state.on ? "check" : /mic|chat|stream/i.test(channelRow.modelData.key) ? "mic" : "volume_up"
                                            selected: channelRow.state.on
                                            onClicked: Recorder.setChannel(channelRow.modelData.key, !channelRow.state.on, channelRow.state.level)
                                        }
                                        Slider {
                                            Layout.fillWidth: true
                                            thin: true
                                            value: channelRow.state.level
                                            opacity: channelRow.state.on ? 1 : 0.45
                                            onMoved: v => Recorder.setChannel(channelRow.modelData.key, channelRow.state.on || v > 0, v)
                                        }
                                        StyledText {
                                            Layout.preferredWidth: 44
                                            horizontalAlignment: Text.AlignRight
                                            text: `${Math.round(channelRow.state.level * 100)} %`
                                            dim: !channelRow.state.on
                                            tabular: true
                                            font.pixelSize: Theme.size.small
                                        }
                                    }
                                }

                                StyledText {
                                    visible: Recorder.channels.length === 0
                                    text: "no sound devices found"
                                    dim: true
                                    font.pixelSize: Theme.size.small
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacing.medium

                            Tabs {
                                model: [
                                    { key: "region", label: "region", icon: "crop_free" },
                                    { key: "window", label: "window", icon: "web_asset" },
                                    { key: "screen", label: "screen", icon: "desktop_windows" }
                                ]
                                current: root.pick
                                onSelected: key => {
                                    overlay.dragging = false;
                                    root.pick = key;
                                }
                            }

                            SegmentedButtons {
                                model: [
                                    { key: "picture", label: "picture", icon: "photo_camera" },
                                    { key: "record", label: "record", icon: "videocam" }
                                ]
                                current: root.recordMode ? "record" : "picture"
                                // A recording is of the live screen; the frozen picture stays as
                                // the backdrop until the picker goes
                                onSelected: key => root.recordMode = key === "record"
                            }

                            IconButton {
                                icon: "close"
                                onClicked: root.close()
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacing.large

                            KeyHint {
                                visible: root.pick === "region"
                                key: "drag"
                                label: "region"
                            }
                            KeyHint {
                                visible: root.pick !== "screen"
                                key: "click"
                                label: "window"
                            }
                            KeyHint {
                                visible: root.pick === "screen"
                                key: "click"
                                label: "this screen"
                            }
                            KeyHint {
                                key: "enter"
                                label: "whole screen"
                            }
                            KeyHint {
                                key: "esc"
                                label: "cancel"
                            }
                        }
                    }
                }

                Component.onCompleted: progress = 1
            }
        }
    }

    // ── While recording: the time in the hole, a click stops it ──
    HolePopup {
        id: indicator

        readonly property bool compact: Bloom.gaming
        readonly property string screenName: screen?.name ?? ""

        screen: Bloom.focusedScreen
        position: Config.user.recordIndicatorPosition ?? "top-left"
        insetTop: atTop ? Bloom.inset(screenName, "top") : 0
        insetBottom: atBottom ? Bloom.inset(screenName, "bottom") : 0
        insetLeft: atLeft ? Bloom.inset(screenName, "left") : 0
        insetRight: atRight ? Bloom.inset(screenName, "right") : 0
        shown: Recorder.recording && !root.hidden && !root.open && (Config.user.recordIndicator ?? true)
        namespace: "qs-recording"

        Behavior on insetTop {
            Anim {}
        }
        Behavior on insetBottom {
            Anim {}
        }
        Behavior on insetLeft {
            Anim {}
        }
        Behavior on insetRight {
            Anim {}
        }

        Pill {
            interactive: true
            baseColor: indicator.compact ? Theme.scrim : Theme.container
            activeColor: indicator.compact ? Theme.scrim : Theme.high
            padding: 12
            spacing: 8
            onClicked: Recorder.stop()

            // A slow pulse while it runs; steady while saving
            Rectangle {
                implicitWidth: 10
                implicitHeight: 10
                radius: 5
                color: Theme.error

                SequentialAnimation on opacity {
                    running: Recorder.recording && !Recorder.stopping && Theme.animated
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    Anim {
                        to: 0.3
                        duration: Theme.anim.slow
                    }
                    Anim {
                        to: 1
                        duration: Theme.anim.slow
                    }
                }
            }
            StyledText {
                text: Recorder.stopping ? "saving …" : `rec ${Recorder.elapsed}`
                color: indicator.compact ? Theme.textOnScrim : Theme.text
                tabular: true
                font.pixelSize: Theme.size.small + 1
                font.weight: Font.Medium
            }
            Icon {
                visible: !Recorder.stopping
                icon: "stop_circle"
                size: Theme.icon.small
                color: indicator.compact ? Theme.textOnScrim : Theme.error
            }
        }
    }

    IpcHandler {
        target: "screenshot"

        function region(): void {
            root.recordMode = false;
            root.pick = "region";
            root.show();
        }

        // Pick what to record; while a recording runs, the same call stops it
        function record(): void {
            if (Recorder.recording) {
                Recorder.stop();
                return;
            }
            root.recordMode = true;
            root.show();
        }

        function toggle(): void {
            if (root.open)
                root.close();
            else
                root.show();
        }

        // The focused screen, no questions asked
        function screen(): void {
            const name = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
            if (name !== "")
                root.captureOutput(name);
        }

        function close(): void {
            root.close();
        }
    }
}
