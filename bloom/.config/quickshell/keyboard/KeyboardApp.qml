import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The keyboard app (Super+K): lighting, Fn keys and per-key colors (KeyboardView), a rounded
// window in the middle of the hole over the dimmed desktop. The Keyboard service and
// facet-keyboard (keyboard package) do the work.
// `qs ipc call keyboard toggle`, also open and close; `mods` comes from Hyprland while
// modifier keys are held (hypr/facet/hotkeys.lua).
Scope {
    id: root

    property bool open: false
    property real shown: open ? 1 : 0

    Behavior on shown {
        Anim {
            duration: root.open ? Theme.anim.drawerIn : Theme.anim.drawerOut
        }
    }

    function show() {
        if (open)
            return;
        window.screen = Bloom.focusedScreen;
        open = true;
        view.reset();
        Keyboard.refresh();
    }

    function hide() {
        open = false;
    }

    PanelWindow {
        id: window

        visible: root.open || root.shown > 0.01
        color: "transparent"
        // Inside the hole: the frame's exclusive zones are respected, none is set
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-keyboard"
        // The hex and action fields take typing
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Dims the hole a little; a click outside closes
        Rectangle {
            anchors.fill: parent
            radius: Bloom.frameAway ? 0 : Theme.rounding.hole
            color: Theme.page
            opacity: 0.5 * root.shown

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        KeyboardView {
            id: view

            width: Math.min(1180, parent.width - Theme.spacing.huge * 2)
            height: Math.min(900, parent.height - Theme.spacing.huge * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - height) / 2 + 16 * (1 - root.shown)
            opacity: root.shown
            scale: 0.97 + 0.03 * root.shown
            focus: root.open
            onCloseRequested: root.hide()
        }
    }

    IpcHandler {
        target: "keyboard"

        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        // From Hyprland while modifier keys are held (hypr/facet/hotkeys.lua): "super+shift", "" on release
        function mods(text: string): void {
            Keyboard.setHeldMods(text);
        }
    }
}
