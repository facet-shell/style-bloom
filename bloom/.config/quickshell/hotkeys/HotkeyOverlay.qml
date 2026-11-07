import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// Hold Super for 1.5 seconds (hypr/facet/hotkeys.lua opens it, the release closes it) and
// every Super key shows: a rounded card in the middle of the focused screen with the
// keyboard (keys that do something lit) and all binds grouped (Binds). Also
// `qs ipc call hotkeys toggle`; opened that way a click outside the card closes it. It takes
// no keyboard focus, so Super stays with Hyprland.
Scope {
    id: root

    property bool hidden: false
    property bool open: false

    property real shown: open && !hidden ? 1 : 0
    Behavior on shown {
        Anim {
            duration: root.open ? Theme.anim.medium : Theme.anim.small
            easing.bezierCurve: root.open ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
        }
    }

    function show() {
        if (hidden || open)
            return;
        window.screen = Bloom.focusedScreen;
        // Read the binds every time: the config may have changed since the last look
        Binds.refresh();
        open = true;
    }

    function hide() {
        open = false;
    }

    onHiddenChanged: if (hidden) open = false

    // The same keys light up on an AULA F75 (services/Keyboard.qml): while the overlay is
    // open without Super held, Super counts as held
    Binding {
        target: Keyboard
        property: "overlayOpen"
        value: root.open && !root.hidden
    }

    PanelWindow {
        id: window

        visible: root.shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-hotkeys"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: root.shown

            // Opened with toggle (no Super held): a click closes it
            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        HotkeyView {
            id: view

            // Never larger than the screen: a small one gets the whole card, smaller
            readonly property real fit: Math.min(1, (window.width - 64) / Math.max(1, implicitWidth), (window.height - 64) / Math.max(1, implicitHeight))

            anchors.centerIn: parent
            anchors.verticalCenterOffset: 24 * (1 - root.shown)
            opacity: root.shown
            scale: fit * (0.96 + 0.04 * root.shown)
        }
    }

    IpcHandler {
        target: "hotkeys"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show();
        }
    }
}
