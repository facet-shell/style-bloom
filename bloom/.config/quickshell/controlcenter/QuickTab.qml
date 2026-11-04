import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// The control center's Quick tab: tiles that spring between round (off) and squarer (on),
// the volume and brightness sliders, the channels (GoXLR or virtual) when there are some,
// and the way to the other apps.
ColumnLayout {
    id: root

    signal lockRequested()
    signal wallpapersRequested()
    signal keyboardRequested()
    signal settingsRequested()
    signal tasksRequested()

    spacing: Theme.spacing.medium

    // ── A tile ───────────────────────────────────────────────

    component Tile: Rectangle {
        id: tile

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        property bool available: true
        readonly property color foreground: checked ? Theme.onPrimary : Theme.text

        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: line.implicitHeight + 24
        radius: checked ? Theme.rounding.normal : Theme.rounding.large
        color: checked ? Theme.primary : Theme.high
        scale: layer.pressed ? 0.96 : 1
        opacity: available ? 1 : 0.38

        Behavior on radius {
            SpringAnim {}
        }
        Behavior on scale {
            SpringAnim {}
        }
        Behavior on color {
            ColorAnim {}
        }

        RowLayout {
            id: line

            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 10

            Icon {
                icon: tile.icon
                size: 22
                fill: tile.checked ? 1 : 0
                color: tile.foreground
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: tile.title
                    color: tile.foreground
                    font.pixelSize: Theme.size.small + 1
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: !tile.available ? "not here" : tile.subtitle
                    color: tile.checked ? Theme.alpha(Theme.onPrimary, 0.75) : Theme.dim
                    font.pixelSize: Theme.size.tiny
                }
            }
        }

        StateLayer {
            id: layer

            color: tile.foreground
            disabled: !tile.available
            onClicked: tile.clicked()
        }
    }

    // ── Tiles ────────────────────────────────────────────────

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.spacing.normal
        rowSpacing: Theme.spacing.normal

        // By connection type; a click switches the Wi-Fi radio (a cable stays a cable)
        Tile {
            icon: !Network.online ? (Toggles.wifi ? "signal_wifi_bad" : "wifi_off")
                : Network.type === "ethernet" ? "lan"
                : Network.strength >= 67 ? "wifi"
                : Network.strength >= 34 ? "wifi_2_bar"
                : "wifi_1_bar"
            title: "Network"
            checked: Network.online
            available: Network.available
            subtitle: Network.type === "ethernet" ? `cable · ${Network.name}`
                : Network.type === "wifi" ? Network.name + (Network.strength >= 0 ? ` · ${Network.strength}%` : "")
                : Toggles.wifi ? "not connected" : "Wi-Fi off"
            onClicked: Toggles.setWifi(!Toggles.wifi)
        }

        Tile {
            readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

            icon: !Toggles.bluetooth ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"
            title: "Bluetooth"
            checked: Toggles.bluetooth
            available: Toggles.bluetoothAvailable
            subtitle: !Toggles.bluetooth ? "off"
                : connected.length === 1 ? connected[0].name
                : connected.length > 1 ? `${connected.length} devices`
                : "on"
            onClicked: Toggles.setBluetooth(!Toggles.bluetooth)
        }

        Tile {
            icon: "do_not_disturb_on"
            title: "Silent"
            checked: Toggles.silent
            subtitle: checked ? "only calls and alarms" : "off"
            onClicked: Toggles.silent = !Toggles.silent
        }

        Tile {
            icon: "sports_esports"
            title: "Game mode"
            checked: Toggles.gameMode
            subtitle: !checked ? (Config.gameModeAuto ? "starts with a game" : "off")
                : Toggles.autoGame ? (Toggles.gameTitle || "by itself") : "on"
            onClicked: Toggles.setGameMode(!Toggles.gameMode)
        }

        Tile {
            icon: "coffee"
            title: "Stay awake"
            checked: Toggles.stayAwake
            subtitle: checked ? "no lock, screen stays on" : "off"
            onClicked: Toggles.stayAwake = !Toggles.stayAwake
        }

        // The mic fader's mute on a GoXLR, else the default microphone's (like tui)
        Tile {
            readonly property bool onFader: GoXLR.fader("mic") !== null

            icon: checked ? "mic_off" : "mic"
            title: "Mic mute"
            checked: onFader ? GoXLR.fader("mic").muted : Audio.defaultSource?.audio?.muted ?? false
            available: onFader || Audio.defaultSource !== null
            subtitle: checked ? "muted" : "off"
            onClicked: {
                if (onFader)
                    GoXLR.setMuted("mic", !checked);
                else
                    Audio.toggleMute(Audio.defaultSource);
            }
        }
    }

    // ── Sliders ──────────────────────────────────────────────

    // The GoXLR's System channel when there is one (as the bar's wheel), else the default output
    Slider {
        id: volume

        readonly property bool goxlrSystem: GoXLR.available && GoXLR.volumes.system !== undefined
        readonly property bool muted: !goxlrSystem && (Audio.defaultSink?.audio?.muted ?? false)

        Layout.fillWidth: true
        value: goxlrSystem ? (GoXLR.volumes.system ?? 0) / 100 : Audio.defaultSink?.audio?.volume ?? 0
        icon: muted ? "volume_off" : value < 0.01 ? "volume_mute" : value < 0.5 ? "volume_down" : "volume_up"
        disabled: !goxlrSystem && Audio.defaultSink === null
        onMoved: v => {
            if (goxlrSystem)
                GoXLR.setChannelVolume("System", v * 100);
            else
                Audio.setVolume(Audio.defaultSink, v);
        }
    }

    // ── Channels ─────────────────────────────────────────────

    // One line per channel, like tui's faders: the GoXLR's faders (levels follow the
    // hardware, the mute works from here), or the virtual channels from `facet audio channels
    // on` (a slider and a mute each, then the real output they play into). Not there
    // without either.
    Card {
        id: channels

        readonly property bool goxlrFaders: GoXLR.available && GoXLR.faders.length > 0
        readonly property var rows: goxlrFaders
            ? GoXLR.faders.map(f => ({ key: f.key, label: f.label, node: null }))
            : Audio.virtualActive
            ? Audio.virtualChannels.map(c => ({ key: c.key, label: c.label, node: c.node }))
                .concat(Audio.masterOutput ? [{ key: "output", label: "Output", node: Audio.masterOutput }] : [])
            : []
        readonly property var icons: ({ system: "desktop_windows", game: "sports_esports", chat: "forum", music: "music_note", mic: "mic", sample: "graphic_eq", output: "speaker" })

        Layout.fillWidth: true
        visible: rows.length > 0
        padding: Theme.padding.normal

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.small

            StyledText {
                text: channels.goxlrFaders ? "GoXLR faders" : "Channels"
                dim: true
                font.pixelSize: Theme.size.tiny
            }

            Repeater {
                model: channels.rows

                delegate: RowLayout {
                    id: channelRow

                    required property var modelData
                    readonly property var fader: channels.goxlrFaders ? GoXLR.state(modelData.key) : null
                    readonly property real level: fader ? fader.level / 100 : (modelData.node?.audio?.volume ?? 0)
                    readonly property bool muted: fader ? fader.muted : (modelData.node?.audio?.muted ?? false)

                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    Icon {
                        icon: channels.icons[channelRow.modelData.key] ?? "volume_up"
                        size: Theme.icon.small
                        dim: true
                    }
                    StyledText {
                        Layout.preferredWidth: 64
                        text: channelRow.modelData.label.charAt(0).toUpperCase() + channelRow.modelData.label.slice(1)
                        font.pixelSize: Theme.size.small
                    }
                    // The GoXLR's faders are physical: a meter, not a slider
                    ProgressBar {
                        visible: channelRow.fader !== null
                        Layout.fillWidth: true
                        value: channelRow.level
                        color: channelRow.muted ? Theme.outline : Theme.primary
                    }
                    Slider {
                        visible: channelRow.fader === null
                        Layout.fillWidth: true
                        thin: true
                        value: channelRow.level
                        opacity: channelRow.muted ? 0.5 : 1
                        onMoved: v => Audio.setVolume(channelRow.modelData.node, v)
                    }
                    StyledText {
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                        text: channelRow.muted ? "muted" : `${Math.round(channelRow.level * 100)}%`
                        color: channelRow.muted ? Theme.error : Theme.dim
                        tabular: true
                        font.pixelSize: Theme.size.tiny
                    }
                    IconButton {
                        size: 28
                        iconSize: 16
                        icon: channelRow.muted ? "volume_off" : "volume_up"
                        iconColor: channelRow.muted ? Theme.error : hovered ? Theme.text : Theme.dim
                        onClicked: {
                            if (channelRow.fader !== null)
                                GoXLR.setMuted(channelRow.modelData.key, !channelRow.muted);
                            else
                                Audio.toggleMute(channelRow.modelData.node);
                        }
                    }
                }
            }
        }
    }

    // Laptop backlights through brightnessctl; gone where there is none (a desktop)
    Slider {
        id: brightness

        property bool available: false
        property real level: 0
        // Only the newest value goes out, every 60 ms while dragging
        property real pending: -1

        Layout.fillWidth: true
        visible: available
        value: level
        icon: level < 0.35 ? "brightness_low" : level < 0.7 ? "brightness_medium" : "light_mode"
        onMoved: v => {
            level = Math.max(0.01, v);
            pending = level;
            if (!sendBrightness.running)
                sendBrightness.start();
        }

        Timer {
            id: sendBrightness
            interval: 60
            onTriggered: {
                if (brightness.pending < 0)
                    return;
                Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", `${Math.round(brightness.pending * 100)}%`]);
                brightness.pending = -1;
            }
        }

        // "intel_backlight,backlight,120,47%,255"
        Process {
            running: true
            command: ["brightnessctl", "-m", "-c", "backlight", "info"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = this.text.trim().split("\n")[0].split(",");
                    const current = Number(parts[2]), max = Number(parts[4]);
                    if (parts.length >= 5 && max > 0) {
                        brightness.level = current / max;
                        brightness.available = true;
                    }
                }
            }
        }
    }

    // ── The other apps ───────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        spacing: Theme.spacing.normal

        Repeater {
            model: [
                { key: "lock", icon: "lock" },
                { key: "wallpapers", icon: "wallpaper" },
                { key: "keyboard", icon: "keyboard" },
                { key: "tasks", icon: "monitoring" },
                { key: "settings", icon: "settings" }
            ]

            Button {
                required property var modelData

                Layout.fillWidth: true
                icon: modelData.icon
                variant: modelData.key === "settings" ? "tonal" : "plain"
                onClicked: {
                    switch (modelData.key) {
                    case "lock":
                        root.lockRequested();
                        break;
                    case "wallpapers":
                        root.wallpapersRequested();
                        break;
                    case "keyboard":
                        root.keyboardRequested();
                        break;
                    case "tasks":
                        root.tasksRequested();
                        break;
                    default:
                        root.settingsRequested();
                    }
                }
            }
        }
    }
}
