import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
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

    // Fullscreen (or only maximized, which leaves the bar in sight) is only in hyprctl clients
    // (lastIpcObject); read it again when it can change, for the bar over fullscreen windows
    Connections {
        target: Hyprland
        enabled: Config.barOverFullscreen
        function onRawEvent(event) {
            if (["fullscreen", "workspacev2", "focusedmonv2", "openwindow", "closewindow", "movewindowv2", "activespecialv2"].includes(event.name))
                fullscreenRead.restart();
        }
    }

    Timer {
        id: fullscreenRead
        interval: 50
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

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
        WlrLayershell.namespace: "qs-facet-zone"
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

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

            // A window covers this screen fullscreen (a maximized one leaves the bar in sight);
            // the frame sits on the Top layer, under it. Same reading as tui's bar. The special
            // workspace shown on top counts too (HyprlandMonitor has no property for it, only
            // hyprctl monitors: lastIpcObject)
            readonly property bool fullscreen: {
                const special = monitor?.lastIpcObject?.specialWorkspace?.name ?? "";
                const shown = [monitor?.activeWorkspace];
                if (special !== "")
                    shown.push(Hyprland.workspaces.values.find(w => w.name === special));
                return shown.some(ws => {
                    if (!ws?.hasFullscreen)
                        return false;
                    const modes = ws.toplevels.values.map(t => t.lastIpcObject?.fullscreen).filter(f => f !== undefined);
                    // Not read from hyprctl yet: the workspace's word is enough
                    return modes.length === 0 || modes.some(f => f === true || (Number(f) & 2) !== 0);
                });
            }

            // Over a fullscreen window, or with the frame away in game mode, resting the mouse on
            // the top edge brings the bar down on the Overlay layer (Config.barOverFullscreen, as
            // tui's bar does); the frame stays out of it and the window keeps the screen
            readonly property bool canPeek: Config.barOverFullscreen && !root.hidden && (fullscreen || Bloom.frameAway)
            property bool peek: false
            onCanPeekChanged: if (!canPeek) {
                peek = false;
                peekOpen.stop();
                peekClose.stop();
            }
            // The bar is held while the mouse is on it or a drawer of it is out
            readonly property bool held: barHover.hovered || Bloom.inset(modelData.name, "top") > 0
            onHeldChanged: {
                if (held) {
                    peekClose.stop();
                } else if (peek) {
                    peekClose.interval = 400;
                    peekClose.restart();
                }
            }

            // Passing by does not count, the mouse has to rest on the edge
            Timer {
                id: peekOpen
                interval: 280
                onTriggered: {
                    if (!perScreen.canPeek)
                        return;
                    perScreen.peek = true;
                    // Goes up again if the mouse never reaches the bar
                    if (!perScreen.held) {
                        peekClose.interval = 1200;
                        peekClose.restart();
                    }
                }
            }
            Timer {
                id: peekClose
                interval: 400
                onTriggered: perScreen.peek = false
            }

            // Hot edge: 1 px along the top, above the fullscreen window or game, only while the
            // bar is out of sight; no keyboard focus, too thin to be in the way
            PanelWindow {
                screen: perScreen.modelData
                visible: perScreen.canPeek && !perScreen.peek
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                implicitHeight: 1
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "qs-facet-peek"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors {
                    top: true
                    left: true
                    right: true
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            peekOpen.restart();
                        else
                            peekOpen.stop();
                    }
                }
            }

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
                // The bar alone: there with the frame, up out of sight over a fullscreen window
                // (it is under it anyway), so a peek slides it down instead of popping it up
                readonly property bool barShown: (!root.away && !perScreen.fullscreen) || perScreen.peek
                property real barPresence: barShown ? 1 : 0
                // On the Overlay layer while the bar peeks and until it has slid up again; the
                // frame around the hole is not drawn there
                readonly property bool overFullscreen: perScreen.peek || (perScreen.canPeek && barPresence > 0.001)

                screen: perScreen.modelData
                // Unmapped while it sits under a fullscreen window: moved up to the Overlay layer
                // it would first show its last buffer there (the whole frame) for a moment
                // before the slide; mapped fresh, the first frame is already the peeking bar
                visible: overFullscreen || (!perScreen.canPeek && (presence > 0.001 || barPresence > 0.001))
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                // Over a fullscreen game while the bar peeks
                WlrLayershell.layer: overFullscreen ? WlrLayer.Overlay : WlrLayer.Top
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
                // Down fast with a soft landing; up again with a gentle start and end, the
                // decel curve snapped it nearly out of sight at once and then crawled
                Behavior on barPresence {
                    NumberAnimation {
                        duration: window.barShown ? Theme.anim.drawerIn : Theme.anim.drawerOut
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: window.barShown ? Theme.curve.emphasizedDecel : Theme.curve.standard
                    }
                }

                Component.onCompleted: Bloom.registerFrame(perScreen.modelData.name, window)
                Component.onDestruction: Bloom.registerFrame(perScreen.modelData.name, null)

                // The surface everywhere but the hole (even-odd: the hole cuts out)
                Shape {
                    anchors.fill: parent
                    // Not while the bar peeks: over a fullscreen window only the bar comes
                    opacity: window.overFullscreen ? 0 : window.presence
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
                    y: -height * (1 - window.barPresence)
                    // Stays solid for most of the slide, fades only the last bit
                    opacity: Math.min(1, window.barPresence * 2.5)

                    HoverHandler {
                        id: barHover
                    }

                    // Its own background while it peeks: the frame, whose top edge is the bar's
                    // background otherwise, is not drawn over a fullscreen window
                    Rectangle {
                        anchors.fill: parent
                        visible: window.overFullscreen
                        color: root.color
                    }

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
