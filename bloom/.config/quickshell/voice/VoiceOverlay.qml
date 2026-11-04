import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// STUB (notifications part: voice): the Discord voice overlay. Round faces with a green
// ring while talking, names with a soft shadow, red mute icons, no frame or background, every
// click goes through (HolePopup { clickThrough: true }) except while moving
// (Super+Shift+V). In a game with Bloom.compact("voice"): smaller faces. Config.voiceOverlay*
// as in tui's voice/VoiceOverlay.qml, which has the data side (DiscordBridge) to port.
// mute, deafen and leave already work here; move needs the overlay.
Scope {
    id: root

    property bool hidden: false
    property bool moving: false

    IpcHandler {
        target: "voice"

        // Super+Shift+V
        function move(): void {
            root.moving = !root.moving;
            console.warn("bloom: the voice overlay is not built yet (voice/VoiceOverlay.qml)");
        }

        // Super+Shift+M and Super+Shift+D, from inside a game too
        function mute(): void {
            DiscordBridge.send({ cmd: "toggle_mute" });
        }

        function deafen(): void {
            DiscordBridge.send({ cmd: "toggle_deafen" });
        }

        function leave(): void {
            DiscordBridge.send({ cmd: "leave_voice" });
        }
    }
}
