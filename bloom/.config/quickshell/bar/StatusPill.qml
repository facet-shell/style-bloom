import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.components
import qs.config
import qs.services

// The status pill: network by connection type (cable, Wi-Fi by signal, none), volume, mic,
// and a battery only where UPower reports one. Click: the control center; the wheel steps the
// volume (the GoXLR System channel when there is one, else the default output).
Pill {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false

    readonly property string networkIcon: !Network.online ? "signal_disconnected"
        : Network.type === "ethernet" ? "lan"
        : Network.strength >= 67 ? "wifi"
        : Network.strength >= 34 ? "wifi_2_bar"
        : "wifi_1_bar"
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property real sinkVolume: sink?.audio?.volume ?? 0
    readonly property string volumeIcon: sinkMuted ? "volume_off" : sinkVolume < 0.01 ? "volume_mute" : sinkVolume < 0.5 ? "volume_down" : "volume_up"
    readonly property bool micMuted: (source?.audio?.muted ?? false) || (GoXLR.available && GoXLR.micButtonMuted)
    readonly property string batteryIcon: {
        if (!hasBattery)
            return "";
        if (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)
            return "battery_charging_full";
        const level = battery.percentage;
        if (level >= 0.95)
            return "battery_full";
        return `battery_${Math.max(0, Math.min(6, Math.floor(level * 7)))}_bar`;
    }

    interactive: true
    spacing: 10
    onScrolled: wheel => stepVolume(wheel.angleDelta.y > 0)

    function stepVolume(up) {
        if (GoXLR.available && GoXLR.volumes.system !== undefined) {
            GoXLR.stepSystem(up ? 5 : -5);
            return;
        }
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (up ? 0.05 : -0.05)));
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null)
    }

    Icon {
        visible: Network.available
        icon: root.networkIcon
        size: 19
        dim: true
    }
    Icon {
        icon: root.volumeIcon
        size: 19
        color: root.sinkMuted ? Theme.error : Theme.dim
    }
    Icon {
        visible: root.source !== null
        icon: root.micMuted ? "mic_off" : "mic"
        size: 19
        color: root.micMuted ? Theme.error : Theme.dim
    }
    Icon {
        visible: root.hasBattery
        icon: root.batteryIcon
        size: 19
        color: root.hasBattery && root.battery.percentage < 0.15 && root.batteryIcon !== "battery_charging_full" ? Theme.error : Theme.dim
    }
}
