import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.config

// The frame around every screen: the bar as its top edge (Theme.frame.bar, 52 px), a thin
// border on the other three (Theme.frame.border, 10 px), and the desktop as a hole with round
// corners (Theme.rounding.hole). Windows stay inside the hole (exclusive zones); drawers
// come out of its edges.
//
//   ScreenFrame {
//       hidden: lock.active
//       bar: Component { BarContent {} }   // one per screen, see below
//   }
//
//   bar      what sits in the top edge, made once per screen. It gets `screen` (ShellScreen)
//            and `frameWindow` (this screen's frame window) set after it is made, so declare
//            `property ShellScreen screen` and `property var frameWindow` in it; it is
//            Theme.frame.bar high and as wide as the screen.
//   hidden   gone completely (the lockscreen takes over): the bar flies up, the frame fades
//   away     read: hidden, or game mode with Config.frameHidesInGame (Bloom.frameAway).
//            While away the exclusive zones go too and windows get the whole screen.
//   color    Theme.surface
//
// Per screen it makes four empty windows that only reserve the space (top: bar, sides and
// bottom: border), and one see-through window over the whole screen that draws the frame
// and holds the bar. Its input region is the bar alone, so the hole takes no clicks.
Scope {
    id: root

    property Component bar
    property bool hidden: false
    property color color: Theme.surface
    readonly property bool away: hidden || Bloom.frameAway

    // An empty layer that only reserves space along one edge
    component Zone: PanelWindow {
        id: zone

        required property string edge
        property real size: 0
        // Inline components cannot see the ids around them, so this is passed in
        property bool away: false

        visible: !away && size > 0
        color: "transparent"
        exclusiveZone: size
        implicitWidth: edge === "left" || edge === "right" ? size : 0
        implicitHeight: edge === "top" || edge === "bottom" ? size : 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-frame-zone"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: zone.edge !== "bottom"
            bottom: zone.edge !== "top"
            left: zone.edge !== "right"
            right: zone.edge !== "left"
        }
        mask: Region {}
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            Zone {
                screen: perScreen.modelData
                away: root.away
                edge: "top"
                size: Theme.frame.bar
            }
            Zone {
                screen: perScreen.modelData
                away: root.away
                edge: "bottom"
                size: Theme.frame.border
            }
            Zone {
                screen: perScreen.modelData
                away: root.away
                edge: "left"
                size: Theme.frame.border
            }
            Zone {
                screen: perScreen.modelData
                away: root.away
                edge: "right"
                size: Theme.frame.border
            }

            PanelWindow {
                id: window

                // 1 while the frame is there, 0 while it is away; the bar rides on it
                property real presence: root.away ? 0 : 1

                screen: perScreen.modelData
                visible: presence > 0.001
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "qs-frame"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                // Only the bar takes input; the frame and the hole let everything through
                mask: Region {
                    item: barSlot
                }

                Behavior on presence {
                    NumberAnimation {
                        duration: Theme.anim.drawerIn
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }

                Component.onCompleted: Bloom.registerFrame(perScreen.modelData.name, window)
                Component.onDestruction: Bloom.registerFrame(perScreen.modelData.name, null)

                // The surface everywhere but the hole (even-odd: the hole cuts out)
                Shape {
                    anchors.fill: parent
                    opacity: window.presence
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.color
                        fillRule: ShapePath.OddEvenFill
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: {
                                const W = window.width, H = window.height;
                                const t = Theme.frame.border, b = Theme.frame.bar;
                                if (W <= 2 * t || H <= b + t)
                                    return "";
                                const r = Math.min(Theme.rounding.hole, (W - 2 * t) / 2, (H - b - t) / 2);
                                const x0 = t, y0 = b, x1 = W - t, y1 = H - t;
                                return `M 0 0 L ${W} 0 L ${W} ${H} L 0 ${H} Z `
                                    + `M ${x0} ${y0 + r} A ${r} ${r} 0 0 1 ${x0 + r} ${y0} L ${x1 - r} ${y0} `
                                    + `A ${r} ${r} 0 0 1 ${x1} ${y0 + r} L ${x1} ${y1 - r} `
                                    + `A ${r} ${r} 0 0 1 ${x1 - r} ${y1} L ${x0 + r} ${y1} `
                                    + `A ${r} ${r} 0 0 1 ${x0} ${y1 - r} Z`;
                            }
                        }
                    }
                }

                // The bar: the frame's top edge; flies up while the frame steps away
                Item {
                    id: barSlot

                    width: window.width
                    height: Theme.frame.bar
                    y: -height * (1 - window.presence)
                    opacity: window.presence

                    Loader {
                        anchors.fill: parent
                        sourceComponent: root.bar
                        onLoaded: {
                            item.screen = perScreen.modelData;
                            item.frameWindow = window;
                        }
                    }
                }
            }
        }
    }
}
