import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

// The control center's App mixer, tui's mixer in the bloom look: every app with its own
// volume and mute. With a GoXLR each app shows its channel as a chip, a click moves it to
// the next channel. Without one apps move between the machine's own outputs and inputs
// (the chip opens the device list) and the default devices sit on top as master rows.
// Apps that play right now come first, idle ones are dimmed below; the list scrolls.
ColumnLayout {
    id: root

    readonly property bool goxlr: Audio.goxlr
    // Moving a stream (or a short pause) drops its link for a moment, so the order only
    // follows idle changes after they held a while; new and gone apps show up at once
    readonly property var rawPlayback: sortActive(Audio.playback)
    readonly property var rawRecording: sortActive(Audio.recording)
    property var playback: []
    property var recording: []
    readonly property int activeCount: playback.filter(n => !Audio.isIdle(n)).length
    readonly property int idleCount: playback.length - activeCount
    readonly property bool empty: playback.length === 0 && recording.length === 0
    // The row whose device list is open (a stream, or "output" / "input"); one at a time
    property var picking: null

    spacing: Theme.spacing.normal

    function sortActive(list) {
        return list.slice().sort((a, b) => (Audio.isIdle(a) ? 1 : 0) - (Audio.isIdle(b) ? 1 : 0));
    }

    function sameSet(a, b) {
        return a.length === b.length && a.every(n => b.includes(n));
    }

    function sameOrder(a, b) {
        return sameSet(a, b) && a.every((n, i) => n === b[i]);
    }

    // "music" → "Music", "chat mic" → "Chat mic"
    function routeLabel(route) {
        return route === "" ? "not routed" : route.charAt(0).toUpperCase() + route.slice(1);
    }

    onRawPlaybackChanged: sameSet(rawPlayback, playback) ? settle.restart() : playback = rawPlayback
    onRawRecordingChanged: sameSet(rawRecording, recording) ? settle.restart() : recording = rawRecording
    Component.onCompleted: {
        playback = rawPlayback;
        recording = rawRecording;
    }

    Timer {
        id: settle
        interval: 800
        onTriggered: {
            if (!root.sameOrder(root.rawPlayback, root.playback))
                root.playback = root.rawPlayback;
            if (!root.sameOrder(root.rawRecording, root.recording))
                root.recording = root.rawRecording;
        }
    }

    // ── Building blocks ──────────────────────────────────────

    // A chip with a long device name cut short, and an arrow while its list can open
    component DeviceChip: Rectangle {
        id: chip

        property string text: ""
        property bool open: false
        property real maxWidth: 150

        signal clicked()

        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 24
        radius: height / 2
        color: open ? Theme.secondaryContainer : chipLayer.containsMouse ? Theme.highest : Theme.high
        scale: chipLayer.pressed ? 0.92 : 1

        Behavior on color {
            ColorAnim {}
        }
        Behavior on scale {
            SpringAnim {}
        }

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: 2

            StyledText {
                Layout.maximumWidth: chip.maxWidth
                text: chip.text
                color: chip.open ? Theme.text : Theme.dim
                font.pixelSize: Theme.size.tiny
            }
            Icon {
                icon: chip.open ? "expand_less" : "expand_more"
                size: 16
                color: chip.open ? Theme.text : Theme.dim
            }
        }

        StateLayer {
            id: chipLayer
            onClicked: chip.clicked()
        }
    }

    // Every device to pick from as chips that wrap; the one in use is picked
    component DevicePicker: Flow {
        id: picker

        property var devices: []
        property string current: ""

        signal picked(var device)

        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: picker.devices

            Chip {
                required property var modelData

                compact: true
                text: Audio.deviceLabel(modelData)
                selected: modelData.name === picker.current
                onClicked: picker.picked(modelData)
            }
        }
    }

    // A mute button that turns red
    component MuteButton: IconButton {
        property bool muted: false
        property bool mic: false

        size: 28
        iconSize: 16
        icon: mic ? (muted ? "mic_off" : "mic") : (muted ? "volume_off" : "volume_up")
        iconColor: muted ? Theme.error : hovered ? Theme.text : Theme.dim
    }

    // The default output or microphone (only without a GoXLR)
    component MasterRow: Rectangle {
        id: master

        property var device: null
        property var devices: []
        property string key: ""
        property string title: ""
        property bool mic: false
        readonly property bool picking: root.picking === key
        readonly property real volume: device?.audio?.volume ?? 0
        readonly property bool muted: device?.audio?.muted ?? false

        Layout.fillWidth: true
        implicitHeight: masterBody.implicitHeight + 20
        radius: Theme.rounding.large
        color: Theme.container

        ColumnLayout {
            id: masterBody

            anchors.fill: parent
            anchors.margins: 10
            anchors.leftMargin: 14
            spacing: Theme.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.normal

                Icon {
                    icon: master.mic ? "mic" : "speaker"
                    size: Theme.icon.small
                    dim: true
                }
                StyledText {
                    text: master.title
                    font.pixelSize: Theme.size.small + 1
                    font.weight: Font.Medium
                }
                Item {
                    Layout.fillWidth: true
                }
                DeviceChip {
                    text: master.device ? Audio.deviceLabel(master.device) : "none"
                    maxWidth: 190
                    open: master.picking
                    onClicked: root.picking = master.picking ? null : master.key
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.normal

                Slider {
                    Layout.fillWidth: true
                    thin: true
                    disabled: master.device === null
                    value: master.volume
                    opacity: disabled ? 0.38 : master.muted ? 0.5 : 1
                    onMoved: v => Audio.setVolume(master.device, v)
                }
                StyledText {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: `${Math.round(master.volume * 100)}%`
                    tabular: true
                    dim: true
                    font.pixelSize: Theme.size.tiny
                }
                MuteButton {
                    muted: master.muted
                    mic: master.mic
                    disabled: master.device === null
                    onClicked: Audio.toggleMute(master.device)
                }
            }
            DevicePicker {
                visible: master.picking
                devices: master.devices
                current: master.device?.name ?? ""
                onPicked: device => {
                    Audio.setDefault(device);
                    root.picking = null;
                }
            }
        }
    }

    component StreamRow: Rectangle {
        id: row

        required property var node
        property var routes: []
        // idle and route follow with a delay too: while PipeWire relinks the stream the
        // row would dim and lose its chip for a moment. No bindings on them: they start from
        // the live values and then only the timer sets them
        readonly property bool idleNow: Audio.isIdle(node)
        property bool idle: false
        // With a GoXLR the channel key ("music"), without one the device's node name
        readonly property string routeNow: root.goxlr ? Audio.routeOf(node) : Audio.deviceOf(node)?.name ?? ""
        property string route: ""
        readonly property real volume: node.audio?.volume ?? 0
        readonly property bool muted: node.audio?.muted ?? false
        readonly property bool recordingApp: Audio.isRecording(node)
        readonly property bool picking: root.picking === node

        Component.onCompleted: {
            idle = idleNow;
            route = routeNow;
        }
        onIdleNowChanged: idleSettle.restart()
        onRouteNowChanged: {
            if (routeNow !== "")
                route = routeNow;
            else
                idleSettle.restart();
        }

        // The next channel in the list; shown at once, PipeWire confirms a moment later
        function nextRoute() {
            if (routes.length === 0)
                return;
            const next = routes[(routes.indexOf(route) + 1) % routes.length];
            route = next;
            Audio.move(node, next);
        }

        Timer {
            id: idleSettle
            interval: 800
            onTriggered: {
                row.idle = row.idleNow;
                row.route = row.routeNow;
            }
        }

        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 20
        radius: Theme.rounding.large
        color: Theme.container
        opacity: idle ? 0.5 : 1

        Behavior on opacity {
            Anim {
                duration: Theme.anim.small
            }
        }

        RowLayout {
            id: body

            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            AppIcon {
                Layout.alignment: Qt.AlignTop
                name: Audio.iconName(row.node)
                letter: Audio.appName(row.node).charAt(0).toUpperCase()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Audio.appName(row.node)
                            font.pixelSize: Theme.size.small + 1
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: Audio.mediaName(row.node) + (row.idle ? (Audio.mediaName(row.node) !== "" ? " · idle" : "idle") : "")
                            dim: true
                            font.pixelSize: Theme.size.tiny
                        }
                    }

                    // The GoXLR channel: a click moves the app on to the next one
                    Chip {
                        visible: root.goxlr
                        compact: true
                        selected: row.route !== ""
                        icon: row.recordingApp ? "mic" : ""
                        text: root.routeLabel(row.route)
                        onClicked: row.nextRoute()
                    }
                    // A paused app has no link and so no device: it plays on the default
                    // one (or the one WirePlumber remembered) once it starts
                    DeviceChip {
                        visible: !root.goxlr
                        text: row.route === "" ? "default" : Audio.deviceLabel(Audio.deviceByName(row.route))
                        maxWidth: 120
                        open: row.picking
                        onClicked: root.picking = row.picking ? null : row.node
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    Slider {
                        Layout.fillWidth: true
                        thin: true
                        value: row.volume
                        opacity: row.muted ? 0.5 : 1
                        onMoved: v => Audio.setVolume(row.node, v)
                    }
                    StyledText {
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(row.volume * 100)}%`
                        tabular: true
                        dim: true
                        font.pixelSize: Theme.size.tiny
                    }
                    MuteButton {
                        muted: row.muted
                        mic: !root.goxlr && row.recordingApp
                        onClicked: Audio.toggleMute(row.node)
                    }
                }

                DevicePicker {
                    visible: row.picking
                    devices: row.recordingApp ? Audio.inputs : Audio.sinks
                    current: row.route
                    // Picked at once like the GoXLR chips; PipeWire confirms a moment later
                    onPicked: device => {
                        row.route = device.name;
                        Audio.moveTo(row.node, device);
                        root.picking = null;
                    }
                }
            }
        }
    }

    // A list of StreamRows that scrolls past its height, with a thin scroll line
    component StreamList: Item {
        id: list

        property var nodes: []
        property var routes: []
        property real maxHeight: 380

        Layout.fillWidth: true
        implicitHeight: Math.min(listColumn.implicitHeight, maxHeight)

        Flickable {
            id: flick

            anchors.fill: parent
            contentHeight: listColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: listColumn

                width: flick.width - (flick.contentHeight > flick.height ? 10 : 0)
                spacing: Theme.spacing.normal

                // ScriptModel keeps rows (and a slider being dragged) when PipeWire updates
                Repeater {
                    model: ScriptModel {
                        values: list.nodes
                    }

                    StreamRow {
                        required property var modelData

                        node: modelData
                        routes: list.routes
                    }
                }
            }
        }

        Rectangle {
            visible: flick.contentHeight > flick.height
            anchors.right: parent.right
            width: 4
            radius: width / 2
            y: flick.visibleArea.yPosition * flick.height
            height: flick.visibleArea.heightRatio * flick.height
            color: Theme.outline
        }
    }

    // ── Layout ───────────────────────────────────────────────

    StyledText {
        Layout.fillWidth: true
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        text: !root.goxlr ? "Every app on its output; click the device to move it"
            : Audio.outputRoutes.length === 0 ? "No GoXLR outputs found · check goxlrOutputs in the settings"
            : "Every app on its GoXLR channel; click the channel to move it"
    }

    // Without a GoXLR nothing else sets the overall level
    MasterRow {
        visible: !root.goxlr
        key: "output"
        title: "Output"
        device: Audio.defaultSink
        devices: Audio.sinks
    }
    MasterRow {
        visible: !root.goxlr
        key: "input"
        title: "Microphone"
        mic: true
        device: Audio.defaultSource
        devices: Audio.inputs
    }

    // Nothing plays or records
    Card {
        Layout.fillWidth: true
        visible: root.empty

        RowLayout {
            anchors.fill: parent
            spacing: Theme.spacing.medium

            Icon {
                icon: "graphic_eq"
                size: Theme.icon.large
                dim: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Nothing plays sound right now"
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Apps show up here the moment they play or record"
                    dim: true
                    font.pixelSize: Theme.size.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    StyledText {
        visible: root.playback.length > 0
        Layout.topMargin: Theme.spacing.small
        text: `Playback · ${root.activeCount} active${root.idleCount > 0 ? ", " + root.idleCount + " idle" : ""}`
        dim: true
        font.pixelSize: Theme.size.tiny
    }
    StreamList {
        visible: root.playback.length > 0
        nodes: root.playback
        routes: Audio.outputRoutes
        maxHeight: root.recording.length > 0 ? 300 : 400
    }

    StyledText {
        visible: root.recording.length > 0
        Layout.topMargin: Theme.spacing.small
        text: "Recording"
        dim: true
        font.pixelSize: Theme.size.tiny
    }
    StreamList {
        visible: root.recording.length > 0
        nodes: root.recording
        routes: Audio.inputRoutes
        maxHeight: 170
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        visible: !root.empty
        text: root.goxlr ? "Routing is remembered per app, so Spotify stays on Music after a restart"
            : "The device picked per app is remembered, so it stays there after a restart"
        dim: true
        opacity: 0.7
        font.pixelSize: Theme.size.tiny
        wrapMode: Text.WordWrap
    }
}
