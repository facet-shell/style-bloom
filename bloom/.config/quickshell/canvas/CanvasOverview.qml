import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// Zoomed-out view of the infinite canvas (facet layout canvas) on the focused screen, in the
// hole: the surface at 70 % (blurred with a layer rule for qs-overview), every screen as a
// rounded outline, every window as a rounded card with its live picture, a minimap bottom
// right. Super+wheel down opens it: it starts 1:1 on the current view and zooms out until
// everything is in view. The screens stay where they are (layout coordinates): moving a view
// moves its windows across the map, so you always know which screen you are looking at.
// The wheel zooms around the cursor, dragging empty canvas moves the map, dragging a window
// moves it (onto another screen's canvas too), dragging its bottom right corner resizes it,
// a click on a window focuses it and brings it to the middle of its screen, a click on empty
// canvas looks there, a click or drag on the minimap moves the map. Zooming in past 1:1 picks
// what is under the cursor. Keys work on the window under the cursor (or the focused one):
// F fullscreen, Enter go there, Q close it. Esc or right click goes back.
//
// `qs ipc call overview toggle|open|close|zoomIn|zoomOut`; the Super+wheel binds are in
// hypr/facet/canvas.lua, everything else the overlay handles itself.
Scope {
    id: root

    property bool hidden: false
    property bool open: false

    property real shown: open && !hidden ? 1 : 0
    Behavior on shown {
        Anim {
            duration: Theme.anim.medium
        }
    }

    // Canvas point in the middle of the screen and the scale canvas → screen
    property real cx: 0
    property real cy: 0
    property real zoom: 1
    // jump() sets these without a glide; while the map is dragged they follow the mouse
    property bool instant: false
    readonly property bool panning: area.dragging || minimap.dragging
    Behavior on cx {
        enabled: !root.panning && !root.instant
        Anim {
            duration: Theme.anim.drawerIn
        }
    }
    Behavior on cy {
        enabled: !root.panning && !root.instant
        Anim {
            duration: Theme.anim.drawerIn
        }
    }
    Behavior on zoom {
        enabled: !root.instant
        Anim {
            duration: Theme.anim.drawerIn
        }
    }

    readonly property real margin: 90
    readonly property real step: 1.25

    // The screen the overview is on; the map is in layout coordinates, so its middle is fixed
    property string screenName: ""
    readonly property var screenMon: CanvasLayout.monitor(screenName)
    readonly property real camCx: screenMon ? screenMon.x + screenMon.w / 2 : 0
    readonly property real camCy: screenMon ? screenMon.y + screenMon.h / 2 : 0

    // A window's place in layout coordinates: its canvas place minus its screen's camera
    function layoutX(w) {
        return w.x - (CanvasLayout.monitor(w.monitor)?.camera.x ?? 0);
    }
    function layoutY(w) {
        return w.y - (CanvasLayout.monitor(w.monitor)?.camera.y ?? 0);
    }

    // Every screen and every window, in layout coordinates
    function bounds() {
        let x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
        for (const m of CanvasLayout.monitors) {
            x1 = Math.min(x1, m.x);
            y1 = Math.min(y1, m.y);
            x2 = Math.max(x2, m.x + m.w);
            y2 = Math.max(y2, m.y + m.h);
        }
        for (const w of CanvasLayout.windows) {
            const lx = layoutX(w), ly = layoutY(w);
            x1 = Math.min(x1, lx);
            y1 = Math.min(y1, ly);
            x2 = Math.max(x2, lx + w.w);
            y2 = Math.max(y2, ly + w.h);
        }
        if (x1 === Infinity)
            return { x: 0, y: 0, w: window.width, h: window.height };
        return { x: x1, y: y1, w: x2 - x1, h: y2 - y1 };
    }

    // Everything in view of the hole, never larger than 0.6 so it always reads as zoomed out
    function fitZoom() {
        const b = bounds();
        return Math.min(0.6, (window.holeW - 2 * margin) / Math.max(1, b.w), (window.holeH - 2 * margin) / Math.max(1, b.h));
    }

    // The map is centred on the screen (not the hole), so 1:1 lines up with the real desktop
    function toCanvasX(sx) { return (sx - window.width / 2) / zoom + cx; }
    function toCanvasY(sy) { return (sy - window.height / 2) / zoom + cy; }

    // A window being dragged: its address and where its top left corner is on the canvas.
    // The card follows the mouse at once; Hyprland gets the position a few times a second
    // and once more on release, and the override stays until that move shows up
    property var drag: null

    // A window being resized from its corner: address and new size, same idea as drag
    property var resize: null

    function sizeW(w) { return resize && resize.address === w.address ? resize.w : w.w; }
    function sizeH(w) { return resize && resize.address === w.address ? resize.h : w.h; }

    function windowAt(x, y) {
        const list = CanvasLayout.windows;
        for (let i = list.length - 1; i >= 0; i--) {
            const w = list[i];
            const wx = drag && drag.address === w.address ? drag.x : layoutX(w);
            const wy = drag && drag.address === w.address ? drag.y : layoutY(w);
            if (x >= wx && x < wx + sizeW(w) && y >= wy && y < wy + sizeH(w))
                return w;
        }
        return null;
    }

    // The grab zone in the bottom right corner of a window, in screen pixels
    function grip(w) {
        return Math.max(16, Math.min(30, Math.min(sizeW(w), sizeH(w)) * zoom * 0.25));
    }

    // The window whose corner grip is under screen point sx, sy
    function cornerAt(sx, sy) {
        const w = windowAt(toCanvasX(sx), toCanvasY(sy));
        if (!w)
            return null;
        const right = window.width / 2 + (layoutX(w) + sizeW(w) - cx) * zoom;
        const bottom = window.height / 2 + (layoutY(w) + sizeH(w) - cy) * zoom;
        const g = grip(w);
        return right - sx <= g && bottom - sy <= g ? w : null;
    }

    // The window a key acts on: under the cursor, otherwise the focused one
    function keyTarget() {
        return area.hoverWindow ?? CanvasLayout.windows.find(w => w.active) ?? null;
    }

    // F: fullscreen on the screen the window sits on, and the overview goes away
    function fullscreenTarget() {
        const w = keyTarget();
        if (!w)
            return;
        CanvasLayout.fullscreen(w.address);
        close(layoutX(w) + sizeW(w) / 2, layoutY(w) + sizeH(w) / 2);
    }

    // Q: the window is asked to close; the overview stays open
    function closeTarget() {
        const w = keyTarget();
        if (w)
            CanvasLayout.closeWindow(w.address);
    }

    // Enter: like a click on the window
    function pickTarget() {
        const w = keyTarget();
        if (w) {
            CanvasLayout.select(w.address);
            close(layoutX(w) + sizeW(w) / 2, layoutY(w) + sizeH(w) / 2);
        }
    }

    // Starts at 1:1 on the current view, then zooms out until everything fits
    function show() {
        if (hidden || open || !CanvasLayout.enabled)
            return;
        area.pressSeen = false;
        const screen = Bloom.focusedScreen;
        window.screen = screen;
        screenName = screen?.name ?? "";
        window.visible = true;
        jump(camCx, camCy, 1);
        open = true;
        const b = bounds();
        cx = b.x + b.w / 2;
        cy = b.y + b.h / 2;
        zoom = fitZoom();
    }

    // Without the glide
    function jump(x, y, z) {
        instant = true;
        cx = x;
        cy = y;
        zoom = z;
        instant = false;
    }

    // Zooms back to 1:1 on (x, y) while fading out; the desktop below is moved there meanwhile
    function close(x, y) {
        if (!open)
            return;
        dragEnd();
        cx = x ?? camCx;
        cy = y ?? camCy;
        zoom = 1;
        open = false;
    }

    // Window under the cursor: focus and center it; empty canvas: look there
    function pick(sx, sy) {
        const x = toCanvasX(sx), y = toCanvasY(sy);
        const w = windowAt(x, y);
        if (w) {
            CanvasLayout.select(w.address);
            close(layoutX(w) + w.w / 2, layoutY(w) + w.h / 2);
        } else {
            // Hyprland thinks in canvas coordinates
            const c = CanvasLayout.toCanvas(x, y);
            CanvasLayout.lookAt(c.x, c.y, c.monitor);
            close(x, y);
        }
    }

    function zoomAround(sx, sy, factor) {
        const x = toCanvasX(sx), y = toCanvasY(sy);
        const z = Math.max(fitZoom() * 0.4, Math.min(1, zoom * factor));
        cx = x - (sx - window.width / 2) / z;
        cy = y - (sy - window.height / 2) / z;
        zoom = z;
    }

    function zoomIn(sx, sy) {
        if (!open)
            return;
        if (zoom * step >= 0.95)
            pick(sx, sy);
        else
            zoomAround(sx, sy, step);
    }

    function zoomOut(sx, sy) {
        if (!open)
            show();
        else
            zoomAround(sx, sy, 1 / step);
    }

    function dragTo(x, y) {
        if (!drag)
            return;
        drag = { address: drag.address, x: x, y: y };
        if (!dragSend.running)
            dragSend.start();
    }

    // The window's top left corner on the map → canvas coordinates of the screen it is over.
    // Only the drop (final) may move it to another monitor (canvas.lua move_to)
    function sendDrag(final) {
        const c = CanvasLayout.toCanvas(drag.x + 1, drag.y + 1);
        CanvasLayout.moveTo(drag.address, c.x, c.y, c.monitor, final);
    }

    function dragEnd() {
        if (!drag)
            return;
        dragSend.stop();
        sendDrag(true);
        dragSettle.restart();
    }

    Timer {
        id: dragSend
        interval: 120
        onTriggered: if (root.drag) root.sendDrag()
    }
    // Not while the next drag already started within that time
    Timer {
        id: dragSettle
        interval: 700
        onTriggered: if (!area.movingWindow) root.drag = null
    }

    function resizeTo(w, h) {
        if (!resize)
            return;
        resize = { address: resize.address, w: Math.max(100, w), h: Math.max(80, h) };
        if (!resizeSend.running)
            resizeSend.start();
    }

    function sendResize() {
        CanvasLayout.resizeTo(resize.address, resize.w, resize.h);
    }

    function resizeEnd() {
        if (!resize)
            return;
        resizeSend.stop();
        sendResize();
        resizeSettle.restart();
    }

    Timer {
        id: resizeSend
        interval: 120
        onTriggered: if (root.resize) root.sendResize()
    }
    Timer {
        id: resizeSettle
        interval: 700
        onTriggered: if (!area.resizingWindow) root.resize = null
    }

    onHiddenChanged: if (hidden) open = false
    // Super + mouse would still drag the windows behind the overlay
    onOpenChanged: CanvasLayout.overview(open)

    // A drawer coming out on this screen (the bar's buttons still work through the frame)
    // would open under the overview: make way for it
    readonly property bool drawerOut: screenName !== "" && Bloom.anyOpen(screenName)
    onDrawerOutChanged: if (drawerOut && open) close()

    // A key and what it does, for the help line
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

    PanelWindow {
        id: window

        // The hole of the facet: the overview lives in it; in a game the frame is away and
        // the whole screen is the hole
        readonly property bool away: Bloom.frameAway
        readonly property real holeX: away ? 0 : Theme.frame.border
        readonly property real holeY: away ? 0 : Theme.frame.bar
        // From the screen, not the window: show() fits the zoom right after visible = true,
        // before the compositor sized the surface (it reads a 500x500 placeholder then, which
        // gave a negative zoom: a mirrored map with every window off screen)
        readonly property real fullW: screen?.width ?? width
        readonly property real fullH: screen?.height ?? height
        readonly property real holeW: fullW - 2 * holeX
        readonly property real holeH: fullH - holeY - (away ? 0 : Theme.frame.border)
        readonly property real holeR: away ? 0 : Math.min(Theme.rounding.hole, holeW / 2, holeH / 2)

        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-overview"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // The frame and the bar stay usable: only the hole takes the mouse
        mask: Region {
            item: hole
        }

        // Gone once the fade finished
        Timer {
            running: !root.open && window.visible && root.shown < 0.01
            interval: 50
            onTriggered: window.visible = false
        }

        Item {
            id: hole

            x: window.holeX
            y: window.holeY
            width: window.holeW
            height: window.holeH
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Theme.surface
                opacity: 0.7 * root.shown
            }

            // Everything below is in screen coordinates
            Item {
                id: plane

                x: -hole.x
                y: -hole.y
                width: window.width
                height: window.height

                // Dots in canvas coordinates, so the map is seen to move
                Canvas {
                    id: grid

                    readonly property real spacing: 200

                    anchors.fill: parent
                    opacity: 0.6 * root.shown

                    Connections {
                        target: root
                        function onCxChanged() { grid.requestPaint(); }
                        function onCyChanged() { grid.requestPaint(); }
                        function onZoomChanged() { grid.requestPaint(); }
                    }
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const s = spacing * root.zoom;
                        if (s < 24)
                            return;
                        ctx.fillStyle = Theme.outline;
                        const ox = ((width / 2 - root.cx * root.zoom) % s + s) % s;
                        const oy = ((height / 2 - root.cy * root.zoom) % s + s) % s;
                        for (let x = ox; x < width; x += s) {
                            for (let y = oy; y < height; y += s)
                                ctx.fillRect(Math.round(x) - 1, Math.round(y) - 1, 2, 2);
                        }
                    }
                }

                Item {
                    id: map

                    anchors.fill: parent
                    opacity: root.shown

                    // Every screen as it is now, a rounded outline like the hole
                    Repeater {
                        model: ScriptModel {
                            values: CanvasLayout.monitors
                            objectProp: "name"
                        }

                        Item {
                            id: mon

                            required property var modelData
                            readonly property bool here: modelData.name === root.screenName

                            x: window.width / 2 + (modelData.x - root.cx) * root.zoom
                            y: window.height / 2 + (modelData.y - root.cy) * root.zoom
                            width: modelData.w * root.zoom
                            height: modelData.h * root.zoom

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.min(Theme.rounding.drawer, Theme.rounding.hole * root.zoom * 2)
                                color: Theme.alpha(Theme.container, mon.here ? 0.6 : 0.35)
                                border.width: mon.here ? 2 : 1
                                border.color: mon.here ? Theme.primary : Theme.outline
                            }

                            Rectangle {
                                anchors { left: parent.left; top: parent.top; margins: 10 }
                                implicitWidth: monRow.implicitWidth + 18
                                implicitHeight: 24
                                radius: height / 2
                                color: mon.here ? Theme.primaryContainer : Theme.high

                                RowLayout {
                                    id: monRow

                                    anchors.centerIn: parent
                                    spacing: 5

                                    Icon {
                                        icon: "desktop_windows"
                                        size: 14
                                        color: mon.here ? Theme.textOnPrimaryContainer : Theme.dim
                                    }
                                    StyledText {
                                        text: mon.modelData.name
                                        font.pixelSize: Theme.size.tiny
                                        color: mon.here ? Theme.textOnPrimaryContainer : Theme.dim
                                    }
                                }
                            }
                        }
                    }

                    // Each delegate sticks to its window (address): without that a changed
                    // order in the list handed delegates another window, and the capture kept
                    // showing the old one's picture when the new one gave no frame
                    Repeater {
                        model: ScriptModel {
                            values: CanvasLayout.windows
                            objectProp: "address"
                        }

                        Item {
                            id: win

                            required property var modelData
                            readonly property bool hovered: area.hoverWindow !== null && area.hoverWindow.address === modelData.address
                            readonly property bool dragged: root.drag !== null && root.drag.address === modelData.address
                            readonly property bool resized: root.resize !== null && root.resize.address === modelData.address
                            readonly property bool lifted: hovered || dragged || resized
                            readonly property real canvasX: dragged ? root.drag.x : root.layoutX(modelData)
                            readonly property real canvasY: dragged ? root.drag.y : root.layoutY(modelData)
                            readonly property real radius: Math.max(4, Math.min(Theme.rounding.medium, width / 6, height / 6))
                            readonly property var toplevel: {
                                const wanted = String(modelData.address ?? "").replace(/^0x/, "").toLowerCase();
                                const t = Hyprland.toplevels.values.find(t => String(t.address ?? "").replace(/^0x/, "").toLowerCase() === wanted);
                                return t?.wayland ?? null;
                            }

                            x: window.width / 2 + (canvasX - root.cx) * root.zoom
                            y: window.height / 2 + (canvasY - root.cy) * root.zoom
                            width: Math.max(2, root.sizeW(modelData) * root.zoom)
                            height: Math.max(2, root.sizeH(modelData) * root.zoom)
                            z: dragged || resized ? 2 : hovered ? 1 : 0
                            // Lifts a little under the cursor; not while it is moved, the card
                            // has to stay under the mouse
                            scale: hovered && !dragged && !resized ? 1.03 : 1

                            Behavior on scale {
                                SpringAnim {}
                            }

                            // The ring: primary under the cursor, a softer one on the focused window
                            Rectangle {
                                readonly property real ring: win.lifted ? 3 : win.modelData.active ? 2 : 0

                                anchors.fill: parent
                                anchors.margins: -ring
                                radius: win.radius + ring
                                color: "transparent"
                                border.width: ring
                                border.color: win.lifted ? Theme.primary : Theme.primaryContainer
                                visible: ring > 0
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: win.radius
                                color: Theme.container

                                ScreencopyView {
                                    id: preview

                                    anchors.fill: parent
                                    captureSource: win.toplevel
                                    live: true
                                    paintCursor: false
                                }

                                // Hyprland gives no picture of a window that lies fully off every
                                // screen: the last one taken while it was on one (CanvasThumbs.qml)
                                Image {
                                    id: cached

                                    anchors.fill: parent
                                    visible: !preview.hasContent && source != ""
                                    source: Thumbnails.url(win.modelData.address)
                                    asynchronous: true
                                    cache: false
                                    fillMode: Image.Stretch
                                }

                                // No picture yet (or the window has none): its icon, class and title
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: !preview.hasContent && !cached.visible
                                    width: parent.width - 24
                                    spacing: 6

                                    AppIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        visible: win.height > 90
                                        name: String(win.modelData.class ?? "").toLowerCase()
                                        size: Math.max(24, Math.min(48, win.height * 0.25))
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: win.modelData.class
                                        font.pixelSize: Math.max(10, Math.min(Theme.size.large, Theme.size.medium * root.zoom / 0.6))
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: win.height > 60
                                        text: win.modelData.title
                                        dim: true
                                        font.pixelSize: Math.max(9, Math.min(Theme.size.normal, Theme.size.small * root.zoom / 0.6))
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                // Dim everything the cursor is not on
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.page
                                    opacity: win.lifted || win.modelData.active ? 0 : 0.35

                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.anim.small
                                        }
                                    }
                                }
                            }

                            // Resize grip in the bottom right corner while hovered
                            Rectangle {
                                readonly property real g: root.grip(win.modelData)

                                anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
                                width: g
                                height: g
                                radius: g / 2
                                color: win.resized ? Theme.primary : Theme.surface
                                visible: win.hovered || win.resized

                                Icon {
                                    anchors.centerIn: parent
                                    icon: "open_in_full"
                                    size: parent.g * 0.55
                                    color: win.resized ? Theme.textOnPrimary : Theme.text
                                }
                            }

                            // The size while resizing
                            Rectangle {
                                anchors.centerIn: parent
                                visible: win.resized
                                implicitWidth: sizeLabel.implicitWidth + 24
                                implicitHeight: 32
                                radius: height / 2
                                color: Theme.surface

                                StyledText {
                                    id: sizeLabel

                                    anchors.centerIn: parent
                                    text: `${Math.round(root.sizeW(win.modelData))} × ${Math.round(root.sizeH(win.modelData))}`
                                    tabular: true
                                    font.weight: Font.Medium
                                }
                            }

                            // Its name above it while hovered or moved
                            Rectangle {
                                anchors { left: parent.left; bottom: parent.top; bottomMargin: 8 }
                                width: Math.min(Math.max(win.width, 160), titleRow.implicitWidth + 20)
                                height: 30
                                radius: height / 2
                                color: Theme.surface
                                visible: win.lifted

                                RowLayout {
                                    id: titleRow

                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    AppIcon {
                                        name: String(win.modelData.class ?? "").toLowerCase()
                                        size: 20
                                        round: true
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: win.modelData.title !== "" ? `${win.modelData.class} · ${win.modelData.title}` : win.modelData.class
                                        font.pixelSize: Theme.size.small
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // The hole's round corners over the map (the frame's own surface is under them)
        Shape {
            anchors.fill: parent
            visible: window.holeR > 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.surface
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: {
                        const r = window.holeR;
                        const x0 = window.holeX, y0 = window.holeY;
                        const x1 = x0 + window.holeW, y1 = y0 + window.holeH;
                        if (r <= 0)
                            return "";
                        return `M ${x0} ${y0} L ${x0 + r} ${y0} A ${r} ${r} 0 0 0 ${x0} ${y0 + r} Z `
                            + `M ${x1} ${y0} L ${x1} ${y0 + r} A ${r} ${r} 0 0 0 ${x1 - r} ${y0} Z `
                            + `M ${x1} ${y1} L ${x1 - r} ${y1} A ${r} ${r} 0 0 0 ${x1} ${y1 - r} Z `
                            + `M ${x0} ${y1} L ${x0} ${y1 - r} A ${r} ${r} 0 0 0 ${x0 + r} ${y1} Z`;
                    }
                }
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: resizingWindow || hoverCorner ? Qt.SizeFDiagCursor : dragging || movingWindow ? Qt.ClosedHandCursor : hoverWindow ? Qt.PointingHandCursor : Qt.ArrowCursor

            property real hoverX: width / 2
            property real hoverY: height / 2
            readonly property var hoverWindow: root.open && !dragging && !movingWindow && !resizingWindow && !minimap.hovered ? root.windowAt(root.toCanvasX(hoverX), root.toCanvasY(hoverY)) : null
            readonly property bool hoverCorner: hoverWindow !== null && root.cornerAt(hoverX, hoverY) !== null

            // dragging: the map moves; movingWindow: the pressed window moves; resizingWindow: its corner
            property bool dragging: false
            property bool movingWindow: false
            property bool resizingWindow: false
            property var pressedWindow: null
            // Opened while a Hyprland window drag was going on (Super+drag, then the wheel):
            // the button's release reaches the overlay without a press and must not count
            property bool pressSeen: false
            property real pressX: 0
            property real pressY: 0
            property real startCx: 0
            property real startCy: 0
            // Where inside the window it was grabbed, in canvas pixels
            property real grabX: 0
            property real grabY: 0

            onPressed: mouse => {
                pressSeen = true;
                pressX = mouse.x;
                pressY = mouse.y;
                startCx = root.cx;
                startCy = root.cy;
                dragging = false;
                movingWindow = false;
                resizingWindow = false;
                pressedWindow = mouse.button === Qt.LeftButton ? root.windowAt(root.toCanvasX(mouse.x), root.toCanvasY(mouse.y)) : null;
                if (pressedWindow && root.cornerAt(mouse.x, mouse.y)) {
                    resizingWindow = true;
                    resizeSettle.stop();
                    root.resize = { address: pressedWindow.address, w: root.sizeW(pressedWindow), h: root.sizeH(pressedWindow) };
                    return;
                }
                if (pressedWindow) {
                    grabX = root.toCanvasX(mouse.x) - root.layoutX(pressedWindow);
                    grabY = root.toCanvasY(mouse.y) - root.layoutY(pressedWindow);
                }
            }
            onPositionChanged: mouse => {
                hoverX = mouse.x;
                hoverY = mouse.y;
                if (!pressed || !(mouse.buttons & (Qt.LeftButton | Qt.MiddleButton)))
                    return;
                const moved = Math.hypot(mouse.x - pressX, mouse.y - pressY) > 6;
                if (resizingWindow && pressedWindow) {
                    root.resizeTo(root.toCanvasX(mouse.x) - root.layoutX(pressedWindow), root.toCanvasY(mouse.y) - root.layoutY(pressedWindow));
                    return;
                }
                if (pressedWindow && (mouse.buttons & Qt.LeftButton)) {
                    if (!movingWindow && moved) {
                        movingWindow = true;
                        dragSettle.stop();
                        root.drag = { address: pressedWindow.address, x: root.layoutX(pressedWindow), y: root.layoutY(pressedWindow) };
                    }
                    if (movingWindow)
                        root.dragTo(root.toCanvasX(mouse.x) - grabX, root.toCanvasY(mouse.y) - grabY);
                    return;
                }
                if (!dragging && moved)
                    dragging = true;
                if (dragging) {
                    root.cx = startCx - (mouse.x - pressX) / root.zoom;
                    root.cy = startCy - (mouse.y - pressY) / root.zoom;
                }
            }
            onReleased: mouse => {
                if (!pressSeen)
                    return;
                pressSeen = false;
                if (resizingWindow) {
                    resizingWindow = false;
                    pressedWindow = null;
                    root.resizeEnd();
                    return;
                }
                if (movingWindow) {
                    movingWindow = false;
                    pressedWindow = null;
                    root.dragEnd();
                    return;
                }
                pressedWindow = null;
                if (dragging) {
                    dragging = false;
                    return;
                }
                if (mouse.button === Qt.RightButton)
                    root.close();
                else if (mouse.button === Qt.LeftButton)
                    root.pick(mouse.x, mouse.y);
            }
            onWheel: wheel => {
                hoverX = wheel.x;
                hoverY = wheel.y;
                if (wheel.angleDelta.y > 0)
                    root.zoomIn(wheel.x, wheel.y);
                else if (wheel.angleDelta.y < 0)
                    root.zoomOut(wheel.x, wheel.y);
            }
        }

        // ── On top of the map: where you are, the keys, the minimap ──

        Pill {
            x: hole.x + 20
            y: hole.y + 20
            opacity: root.shown
            padding: 14
            spacing: 8

            Icon {
                icon: "grid_view"
                size: Theme.icon.small
                color: Theme.primary
            }
            StyledText {
                text: "infinite canvas"
                font.pixelSize: Theme.size.small + 1
                font.weight: Font.Medium
            }
            StyledText {
                text: `${Math.round(root.zoom * 100)} % · ${CanvasLayout.windows.length} ${CanvasLayout.windows.length === 1 ? "window" : "windows"} · ${CanvasLayout.short(root.toCanvasX(area.hoverX))}, ${CanvasLayout.short(root.toCanvasY(area.hoverY))}`
                dim: true
                tabular: true
                font.pixelSize: Theme.size.small
            }
        }

        Pill {
            anchors.horizontalCenter: hole.horizontalCenter
            y: hole.y + hole.height - height - 20
            opacity: root.shown
            visible: hole.width > 1100
            padding: 8
            spacing: 14

            KeyHint { key: "wheel"; label: "zoom" }
            KeyHint { key: "drag"; label: "move" }
            KeyHint { key: "corner"; label: "resize" }
            KeyHint { key: "click"; label: "go there" }
            KeyHint { key: "F"; label: "fullscreen" }
            KeyHint { key: "Q"; label: "close" }
            KeyHint { key: "esc"; label: "back" }
        }

        // The whole canvas small, with the part in view framed; click or drag moves the map
        Rectangle {
            id: minimap

            readonly property real pad: 10
            readonly property var b: root.bounds()
            readonly property real k: Math.min((width - 2 * pad) / Math.max(1, b.w), (height - 2 * pad) / Math.max(1, b.h))
            // Offsets that center the canvas in the minimap
            readonly property real ox: pad + (width - 2 * pad - b.w * k) / 2
            readonly property real oy: pad + (height - 2 * pad - b.h * k) / 2
            readonly property bool hovered: miniArea.containsMouse
            property bool dragging: false

            function mapX(x) { return ox + (x - b.x) * k; }
            function mapY(y) { return oy + (y - b.y) * k; }

            x: hole.x + hole.width - width - 20
            y: hole.y + hole.height - height - 20
            width: 220
            height: 130
            radius: Theme.rounding.large
            color: Theme.container
            opacity: root.shown
            clip: true

            Repeater {
                model: CanvasLayout.monitors

                Rectangle {
                    required property var modelData

                    x: minimap.mapX(modelData.x)
                    y: minimap.mapY(modelData.y)
                    width: modelData.w * minimap.k
                    height: modelData.h * minimap.k
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.outline
                }
            }

            Repeater {
                model: CanvasLayout.windows

                Rectangle {
                    required property var modelData
                    readonly property bool dragged: root.drag !== null && root.drag.address === modelData.address

                    x: minimap.mapX(dragged ? root.drag.x : root.layoutX(modelData))
                    y: minimap.mapY(dragged ? root.drag.y : root.layoutY(modelData))
                    width: Math.max(2, root.sizeW(modelData) * minimap.k)
                    height: Math.max(2, root.sizeH(modelData) * minimap.k)
                    radius: Math.min(4, width / 3, height / 3)
                    color: modelData.active ? Theme.secondary : Theme.high
                }
            }

            // What the hole shows right now
            Rectangle {
                x: minimap.mapX(root.toCanvasX(hole.x))
                y: minimap.mapY(root.toCanvasY(hole.y))
                width: hole.width / root.zoom * minimap.k
                height: hole.height / root.zoom * minimap.k
                radius: 6
                color: Theme.alpha(Theme.primary, 0.08)
                border.width: 2
                border.color: Theme.primary
            }

            MouseArea {
                id: miniArea

                property real pressX: 0
                property real pressY: 0

                function lookAt(mx, my) {
                    root.cx = minimap.b.x + (mx - minimap.ox) / minimap.k;
                    root.cy = minimap.b.y + (my - minimap.oy) / minimap.k;
                }

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: mouse => {
                    pressX = mouse.x;
                    pressY = mouse.y;
                    minimap.dragging = false;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    if (!minimap.dragging && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 3)
                        minimap.dragging = true;
                    if (minimap.dragging)
                        lookAt(mouse.x, mouse.y);
                }
                // A click glides there, a drag follows the mouse
                onReleased: mouse => {
                    if (!minimap.dragging)
                        lookAt(mouse.x, mouse.y);
                    minimap.dragging = false;
                }
                onCanceled: minimap.dragging = false
                onWheel: wheel => wheel.accepted = true
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_F:
                    root.fullscreenTarget();
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.pickTarget();
                    break;
                case Qt.Key_Q:
                case Qt.Key_Delete:
                    root.closeTarget();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }
    }

    // The other screens while the overview is open: a click on one of them closes it (the
    // click goes no further; the next one lands where it was aimed)
    Variants {
        model: root.open ? Quickshell.screens.filter(s => s.name !== root.screenName) : []

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.open
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-overview-other"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.close()
            }
        }
    }

    IpcHandler {
        target: "overview"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            if (root.open)
                root.close();
            else
                root.show();
        }

        // Super+wheel from Hyprland: around wherever the cursor is
        function zoomIn(): void {
            root.zoomIn(area.hoverX, area.hoverY);
        }

        function zoomOut(): void {
            root.zoomOut(area.hoverX, area.hoverY);
        }
    }
}
