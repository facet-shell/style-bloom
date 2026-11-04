import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// A window for things that float inside the hole without joining the frame: notification
// popups, the Spotify bloom, the voice overlay, the in-game OSD pill. It is placed in the
// hole (it respects the frame's exclusive zones), so with the frame away in a game it moves
// to the screen's edge by itself.
//
//   HolePopup {
//       screen: Bloom.focusedScreen
//       position: Config.notificationPosition
//       shown: list.count > 0
//       namespace: "qs-notifications"
//       contentScale: Bloom.scale("notification")
//       Column { … }                 // its one child: the window takes its implicit size
//   }
//
//   position     top-left, top, top-right, left, center, right, bottom-left, bottom,
//                bottom-right (the Config.*Position values)
//   margin       from the hole's edges (14)
//   insetTop / insetBottom / insetLeft / insetRight
//                more room on that side, e.g. Bloom.inset(screen.name, "right") so the
//                popups step aside while the control center is out (animate it yourself)
//   contentScale the size factor (Bloom.scale(key)); the child is scaled from its corner
//   shown        the window is there (fade and slide the child yourself; keep shown true
//                until that has finished)
//   clickThrough every click goes through (the voice overlay)
//   windowLayer  WlrLayer.Overlay (over fullscreen windows, so a game still gets them)
//   namespace    the layer's name
PanelWindow {
    id: root

    property string position: "top-right"
    property real margin: 14
    property real insetTop: 0
    property real insetBottom: 0
    property real insetLeft: 0
    property real insetRight: 0
    property real contentScale: 1
    property bool shown: true
    property bool clickThrough: false
    property int windowLayer: WlrLayer.Overlay
    property string namespace: "qs-bloom-popup"
    default property alias content: holder.data

    readonly property Item contentChild: holder.children.length > 0 ? holder.children[0] : null
    readonly property bool atTop: position.startsWith("top")
    readonly property bool atBottom: position.startsWith("bottom")
    readonly property bool atLeft: position.endsWith("left")
    readonly property bool atRight: position.endsWith("right")

    visible: shown && contentChild !== null
    color: "transparent"
    implicitWidth: Math.max(1, (contentChild?.implicitWidth ?? 0) * contentScale)
    implicitHeight: Math.max(1, (contentChild?.implicitHeight ?? 0) * contentScale)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: root.windowLayer
    WlrLayershell.namespace: root.namespace
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: root.atTop
        bottom: root.atBottom
        left: root.atLeft
        right: root.atRight
    }
    margins {
        top: root.atTop ? root.margin + root.insetTop : 0
        bottom: root.atBottom ? root.margin + root.insetBottom : 0
        left: root.atLeft ? root.margin + root.insetLeft : 0
        right: root.atRight ? root.margin + root.insetRight : 0
    }

    mask: root.clickThrough ? passThrough : null
    Region {
        id: passThrough
    }

    Item {
        id: holder

        width: root.contentChild?.implicitWidth ?? 0
        height: root.contentChild?.implicitHeight ?? 0
        scale: root.contentScale
        transformOrigin: Item.TopLeft
    }
}
