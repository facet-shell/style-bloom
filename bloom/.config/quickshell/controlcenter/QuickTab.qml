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
// and the way to the other apps. Some tiles have a page behind them (Android's quick
// settings): the arrow at a tile's end, or a right click, slides it in over the tiles:
// Wi-Fi networks, Bluetooth devices, microphones; the volume slider's arrow the outputs.
Item {
    id: root

    signal lockRequested()
    signal wallpapersRequested()
    signal keyboardRequested()
    signal settingsRequested()
    signal tasksRequested()

    // The page over the tiles: "", "wifi", "bluetooth", "input" or "output"
    property string page: ""
    // What the loader holds; stays while a closed page slides out
    property string shownPage: ""

    implicitWidth: tiles.implicitWidth
    // Keep both views covered until the outgoing page has finished sliding away.
    implicitHeight: (slideIn.running || slideOut.running) && pages.item
        ? Math.max(pages.item.implicitHeight, tiles.implicitHeight)
        : shownPage !== "" && pages.item ? pages.item.implicitHeight : tiles.implicitHeight
    clip: true
    // Keys come here first (the pane in ControlCenter passes focus on)
    focus: true

    function openPage(name) {
        page = name;
    }

    function closePage() {
        page = "";
    }

    // A page comes in from the right as the tiles leave to the left; back the other way
    onPageChanged: {
        if (page === "") {
            slideOut.restart();
            return;
        }
        slideOut.stop();
        shownPage = page;
        slideIn.restart();
    }

    // The page took the keys while a field in it had them; without a page they are ours
    onShownPageChanged: {
        if (shownPage === "")
            root.forceActiveFocus();
    }

    // Esc leaves a page first; without one it goes on to the drawer, which closes
    Keys.onEscapePressed: event => {
        if (page !== "")
            closePage();
        else
            event.accepted = false;
    }

    // ── A tile ───────────────────────────────────────────────

    component Tile: Rectangle {
        id: tile

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        property bool available: true
        // A page behind it: a line and an arrow at the end open it, so does a right click
        property bool more: false
        readonly property color foreground: checked ? Theme.textOnPrimary : Theme.text

        signal clicked()
        signal opened()

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
            anchors.rightMargin: tile.more ? arrow.width + 4 : 10
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
                    color: tile.checked ? Theme.alpha(tile.foreground, 0.75) : Theme.dim
                    font.pixelSize: Theme.size.tiny
                }
            }
        }

        StateLayer {
            id: layer

            color: tile.foreground
            disabled: !tile.available
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton && tile.more)
                    tile.opened();
                else if (mouse.button === Qt.LeftButton)
                    tile.clicked();
            }
        }

        // The trailing arrow: a thin line, then the chevron with its own round wash. Above
        // the tile's layer, so its clicks do not toggle.
        Item {
            id: arrow

            visible: tile.more && tile.available
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 38

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: parent.height - 24
                color: Theme.alpha(tile.foreground, 0.25)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: height / 2
                color: tile.foreground
                opacity: arrowArea.pressed ? 0.12 : arrowArea.containsMouse ? 0.08 : 0

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.small
                    }
                }
            }
            Icon {
                anchors.centerIn: parent
                icon: "chevron_right"
                size: 20
                color: tile.foreground
            }
            MouseArea {
                id: arrowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.opened()
            }
        }
    }

    // ── The tiles, sliders and the way to the apps ───────────

    ColumnLayout {
        id: tiles

        width: root.width
        x: root.page === "" ? 0 : -root.width
        opacity: root.page === "" ? 1 : 0
        enabled: root.page === "" && !slideOut.running
        spacing: Theme.spacing.medium

        Behavior on x {
            Anim {}
        }
        Behavior on opacity {
            Anim {}
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing.normal
            rowSpacing: Theme.spacing.normal

            // By connection type; a click switches the Wi-Fi radio (a cable stays a cable),
            // the arrow lists the networks (not on a machine without Wi-Fi)
            Tile {
                icon: !Network.online ? (Toggles.wifi ? "signal_wifi_bad" : "wifi_off")
                    : Network.type === "ethernet" ? "lan"
                    : Network.strength >= 67 ? "wifi"
                    : Network.strength >= 34 ? "wifi_2_bar"
                    : "wifi_1_bar"
                title: "Network"
                checked: Network.online
                available: Network.available
                more: Network.wifiAvailable
                subtitle: Network.type === "ethernet" ? `cable · ${Network.name}`
                    : Network.type === "wifi" ? Network.name + (Network.strength >= 0 ? ` · ${Network.strength}%` : "")
                    : Toggles.wifi ? "not connected" : "Wi-Fi off"
                onClicked: Toggles.setWifi(!Toggles.wifi)
                onOpened: root.openPage("wifi")
            }

            Tile {
                readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

                icon: !Toggles.bluetooth ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"
                title: "Bluetooth"
                checked: Toggles.bluetooth
                available: Toggles.bluetoothAvailable
                more: true
                subtitle: !Toggles.bluetooth ? "off"
                    : connected.length === 1 ? connected[0].name
                    : connected.length > 1 ? `${connected.length} devices`
                    : "on"
                onClicked: Toggles.setBluetooth(!Toggles.bluetooth)
                onOpened: root.openPage("bluetooth")
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

            // The mic fader's mute on a GoXLR, else the default microphone's (like tui);
            // the arrow picks the microphone
            Tile {
                readonly property bool micOnFader: GoXLR.fader("mic") !== null

                icon: checked ? "mic_off" : "mic"
                title: "Mic mute"
                checked: micOnFader ? GoXLR.fader("mic").muted : Audio.defaultSource?.audio?.muted ?? false
                available: micOnFader || Audio.defaultSource !== null
                more: Audio.inputs.length > 0
                subtitle: checked ? "muted" : "off"
                onClicked: {
                    if (micOnFader)
                        GoXLR.setMuted("mic", !checked);
                    else
                        Audio.toggleMute(Audio.defaultSource);
                }
                onOpened: root.openPage("input")
            }
        }

        // ── Sliders ──────────────────────────────────────────

        // The GoXLR's System channel when there is one (as the bar's wheel), else the default
        // output; the arrow at the end picks the output device
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

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

            IconButton {
                visible: Audio.masterOutputs.length > 0
                icon: "chevron_right"
                restColor: Theme.high
                onClicked: root.openPage("output")
            }
        }

        // ── Channels ─────────────────────────────────────────

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

        // ── The other apps ───────────────────────────────────

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

    // ── The pages ────────────────────────────────────────────

    Loader {
        id: pages

        width: root.width
        active: root.shownPage !== ""
        sourceComponent: root.shownPage === "wifi" ? wifiPage
            : root.shownPage === "bluetooth" ? bluetoothPage
            : root.shownPage !== "" ? audioPage
            : null

        // The device pages have transparent gaps. Move an opaque surface with
        // them so the returning Quick tiles cannot show through those gaps.
        Rectangle {
            z: -1
            width: pages.width
            height: Math.max(root.height, pages.height)
            visible: pages.active
            color: Theme.surface
        }
    }

    Anim {
        id: slideIn
        target: pages
        property: "x"
        from: root.width
        to: 0
    }

    SequentialAnimation {
        id: slideOut

        Anim {
            target: pages
            property: "x"
            to: root.width
            easing.bezierCurve: Theme.curve.emphasizedAccel
        }
        ScriptAction {
            script: root.shownPage = ""
        }
    }

    Component {
        id: wifiPage

        WifiPage {
            onBack: root.closePage()
        }
    }

    Component {
        id: bluetoothPage

        BluetoothPage {
            onBack: root.closePage()
        }
    }

    Component {
        id: audioPage

        AudioDevicePage {
            input: root.shownPage === "input"
            onBack: root.closePage()
        }
    }
}
