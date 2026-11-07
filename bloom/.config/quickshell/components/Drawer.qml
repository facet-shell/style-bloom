import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config

// A panel that slides out of an edge of the frame and joins it with concave curves: the
// dashboard (top), the launcher and the GoXLR line (bottom), the control center (right),
// the tray and power menus (top, under their button). One Drawer is one layer window.
//
//   Drawer {
//       screen: Bloom.focusedScreen      // set it when opening; it does not follow focus
//       edge: "top"
//       open: root.open
//       namespace: "qs-dashboard"
//       onDismissed: root.open = false
//       ColumnLayout { anchors.fill: parent; … }   // the content, inside the padding
//   }
//
// Where
//   edge        "top", "bottom", "left" or "right": the frame edge it comes out of
//   align       "center" (middle of that edge), "start" (left / top) or "end" (right / bottom)
//   offset      distance from the hole's start or end for align start/end, in px. Keep it at
//               least Theme.rounding.hole, or the joint runs into the hole's corner.
// What
//   open        out or in; the slide is emphasized-decelerate (Theme.anim.drawerIn/Out)
//   bodyWidth / bodyHeight   the panel's size; by default the content's implicit size plus
//               the padding. Changing it while open glides (the launcher growing).
//   padding     around the content (Theme.padding.drawer)
//   bodyColor   Theme.surface, the frame's color, so drawer and frame are one piece
//   radius      its free corners (Theme.rounding.drawer); fillet the joints
//               (Theme.rounding.fillet); fillets: false for none
// The window
//   namespace   the layer's name (Hyprland rules, hl.get_layers): keep the tui names where
//               they exist ("qs-launcher" is checked by hypr/facet/shell.lua)
//   windowLayer WlrLayer.Top (under fullscreen windows) or WlrLayer.Overlay (over them)
//   keyboard    WlrKeyboardFocus.None (default), OnDemand (menus, Esc) or Exclusive (typing)
//   closeOnOutside  a click outside it (and outside the bar) emits dismissed() (on by default)
//   grabWith    more windows that count as inside for that (e.g. a second drawer beside it)
//   panelId     its name in Bloom.drawers (namespace by default), for Bloom.inset()
// Read
//   progress    0..1 while sliding; extent: how far it is out now, in px
//   contentShown  0..1, the content's fade (follows progress, a little later)
//   signal dismissed()  Esc, or a click outside with closeOnOutside; set open = false there
//
// The window never covers the frame: it is placed inside the hole (it respects the frame's
// exclusive zones), its content slides in from that edge clipped by the window, so it looks
// as if it came from under the frame on any layer.
PanelWindow {
    id: root

    property string edge: "top"
    property string align: "center"
    property real offset: 0
    property bool open: false
    property real padding: Theme.padding.drawer
    property real bodyWidth: (contentChild?.implicitWidth ?? 0) + padding * 2
    property real bodyHeight: (contentChild?.implicitHeight ?? 0) + padding * 2
    property color bodyColor: Theme.surface
    property real radius: Theme.rounding.drawer
    property real fillet: Theme.rounding.fillet
    property bool fillets: true
    property string namespace: "qs-bloom-drawer"
    property int windowLayer: WlrLayer.Top
    property int keyboard: WlrKeyboardFocus.None
    property bool closeOnOutside: true
    property var grabWith: []
    property string panelId: namespace
    default property alias content: inner.data

    readonly property Item contentChild: inner.children.length > 0 ? inner.children[0] : null
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real joint: fillets ? fillet : 0
    // Animated sizes, so a panel that grows while open glides instead of jumping
    property real shownWidth: bodyWidth
    property real shownHeight: bodyHeight
    readonly property real along: horizontal ? shownWidth : shownHeight
    readonly property real across: horizontal ? shownHeight : shownWidth

    // The surface's size: it grows to a larger body at once and shrinks only once the drawer
    // is closed; the body glides inside it (the mask keeps clicks on the rest going through).
    // Every new size of a layer surface stalls a frame until Hyprland configures it (the
    // swap waited 100 ms each), and the glide used to resize it on every frame (~10 fps).
    property real windowWidth: bodyWidth
    property real windowHeight: bodyHeight
    onBodyWidthChanged: windowWidth = visible ? Math.max(windowWidth, bodyWidth) : bodyWidth
    onBodyHeightChanged: windowHeight = visible ? Math.max(windowHeight, bodyHeight) : bodyHeight
    onVisibleChanged: {
        if (!visible) {
            windowWidth = bodyWidth;
            windowHeight = bodyHeight;
        }
    }
    // Where the body sits along the edge inside a surface that is longer than it for now
    readonly property real slack: Math.max(0, (horizontal ? windowWidth : windowHeight) - along)
    readonly property real alongOffset: align === "end" ? slack : align === "start" ? 0 : slack / 2

    property real progress: open ? 1 : 0
    readonly property real extent: progress * across
    readonly property real contentShown: open ? Math.max(0, (progress - 0.35) / 0.65) : Math.max(0, progress * 1.5 - 0.5)

    signal dismissed()

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? Theme.anim.drawerIn : Theme.anim.drawerOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.emphasizedDecel
        }
    }
    Behavior on shownWidth {
        enabled: root.visible
        Anim {
            duration: Theme.anim.drawerOut
        }
    }
    Behavior on shownHeight {
        enabled: root.visible
        Anim {
            duration: Theme.anim.drawerOut
        }
    }

    visible: open || progress > 0.001
    color: "transparent"
    implicitWidth: horizontal ? windowWidth + joint * 2 : Math.max(windowWidth, shownWidth)
    implicitHeight: horizontal ? Math.max(windowHeight, shownHeight) : windowHeight + joint * 2

    // Inside the hole: other layers' exclusive zones (the frame's) are respected, none is set
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: root.windowLayer
    WlrLayershell.namespace: root.namespace
    WlrLayershell.keyboardFocus: open ? root.keyboard : WlrKeyboardFocus.None

    anchors {
        top: root.edge === "top" || (!root.horizontal && root.align === "start")
        bottom: root.edge === "bottom" || (!root.horizontal && root.align === "end")
        left: root.edge === "left" || (root.horizontal && root.align === "start")
        right: root.edge === "right" || (root.horizontal && root.align === "end")
    }
    margins {
        left: root.horizontal && root.align === "start" ? root.offset : 0
        right: root.horizontal && root.align === "end" ? root.offset : 0
        top: !root.horizontal && root.align === "start" ? root.offset : 0
        bottom: !root.horizontal && root.align === "end" ? root.offset : 0
    }

    // Clicks only land on the part that is out
    mask: Region {
        item: clipper
    }

    // ── Shape: body and joints as one path ───────────────────

    // In "top" terms: u runs along the edge, v away from it; every edge maps (u, v) onto the
    // window. The mirrored ones (bottom, left) flip the arcs' sweep.
    function silhouette() {
        const L = along, E = extent, F = joint;
        if (E < 0.5 || L <= 0)
            return "";
        const f = fillets ? Math.min(F, E) : 0;
        const r = Math.max(0, Math.min(radius, E - f, L / 2));
        const W = width, H = height;
        const flip = edge === "bottom" || edge === "left";
        const o = alongOffset;
        const concave = flip ? 1 : 0, convex = flip ? 0 : 1;
        const p = (u, v) => {
            switch (edge) {
            case "bottom":
                return `${u + o} ${H - v}`;
            case "left":
                return `${v} ${u + o}`;
            case "right":
                return `${W - v} ${u + o}`;
            default:
                return `${u + o} ${v}`;
            }
        };
        const arc = (rad, sweep, u, v) => rad > 0 ? `A ${rad} ${rad} 0 0 ${sweep} ${p(u, v)} ` : `L ${p(u, v)} `;
        let d = `M ${p(F - f, 0)} L ${p(F + L + f, 0)} `;
        d += arc(f, concave, F + L, f);
        d += `L ${p(F + L, E - r)} `;
        d += arc(r, convex, F + L - r, E);
        d += `L ${p(F + r, E)} `;
        d += arc(r, convex, F, E - r);
        d += `L ${p(F, f)} `;
        d += arc(f, concave, F - f, 0);
        return d + "Z";
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.bodyColor
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: root.silhouette()
            }
        }
    }

    // ── Content: slides with the body, clipped at the frame's edge ──

    Item {
        id: clipper

        x: root.edge === "right" ? root.width - root.extent : root.horizontal ? root.joint + root.alongOffset : 0
        y: root.edge === "bottom" ? root.height - root.extent : root.horizontal ? 0 : root.joint + root.alongOffset
        width: root.horizontal ? root.along : root.extent
        height: root.horizontal ? root.extent : root.along
        clip: true

        FocusScope {
            id: inner

            // The body's far side follows the edge; content sits inside the padding
            x: (root.edge === "left" ? root.extent - root.shownWidth : 0) + root.padding
            y: (root.edge === "top" ? root.extent - root.shownHeight : 0) + root.padding
            width: root.shownWidth - root.padding * 2
            height: root.shownHeight - root.padding * 2
            focus: root.open
            opacity: root.contentShown
            // A short way in from the edge while it fades in
            transform: Translate {
                x: root.horizontal ? 0 : (root.edge === "left" ? -8 : 8) * (1 - root.contentShown)
                y: root.horizontal ? (root.edge === "top" ? -8 : 8) * (1 - root.contentShown) : 0
            }

            Keys.onEscapePressed: root.dismissed()
        }
    }

    // ── Closing from outside, and telling the others ─────────

    HyprlandFocusGrab {
        active: root.open && root.closeOnOutside
        windows: {
            const frame = Bloom.frameWindow(root.screen?.name ?? "");
            return [root].concat(root.grabWith).concat(frame ? [frame] : []);
        }
        onCleared: root.dismissed()
    }

    readonly property real reported: open ? across : 0
    onReportedChanged: Bloom.report(panelId, screen?.name ?? "", edge, reported)
    onScreenChanged: Bloom.report(panelId, screen?.name ?? "", edge, reported)
    Component.onDestruction: Bloom.report(panelId, "", edge, 0)
}
