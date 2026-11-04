import QtQuick
import qs.components
import qs.config

// The recording editor's timeline on Theme.container: a ruler with the cut marks, the pieces
// of the video as rounded blocks, a row of pills for blur boxes and one for pictures, then one
// row per channel with its waveform. Names on the left, the lanes scroll; wheel scrolls
// through time, Ctrl+wheel zooms, Shift+wheel scrolls the rows.
//
// The rows are built from counts (segments.length, overlays.length …), so dragging a bar,
// which replaces the arrays, keeps the item under the mouse.
Rectangle {
    id: root

    required property var editor
    readonly property var project: editor.project
    readonly property real pps: editor.pps

    readonly property int labelW: 200
    readonly property int rulerH: 28
    readonly property int rowH: 42
    readonly property int audioH: 54
    readonly property real laneW: Math.max(flick.width, project.outLen * pps + 80)
    readonly property real contentH: rulerH + rowH * 3 + audioH * project.tracks.length

    radius: Theme.rounding.medium
    color: Theme.container
    clip: true

    function rowY(row) {
        // 0 video, 1 blur, 2 pictures, 3… tracks
        return row < 3 ? rulerH + row * rowH : rulerH + rowH * 3 + (row - 3) * audioH;
    }

    function timeAt(x) {
        return Math.max(0, Math.min(project.outLen, x / pps));
    }

    // Keeps the playhead in view while it plays
    Connections {
        target: root.editor

        function onPlayheadChanged() {
            if (!root.editor.playing)
                return;
            const x = root.editor.playhead * root.pps;
            if (x > flick.contentX + flick.width - 40 || x < flick.contentX)
                flick.contentX = Math.max(0, Math.min(root.laneW - flick.width, x - 40));
        }
    }

    component Label: StyledText {
        dim: true
        font.pixelSize: Theme.size.tiny
    }

    // ── Names on the left ────────────────────────────────────

    Item {
        id: names

        width: root.labelW
        height: parent.height
        clip: true
        z: 2

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.spacing.normal
            anchors.bottomMargin: Theme.spacing.normal
            width: 1
            color: Theme.outline
            opacity: 0.6
        }

        Item {
            y: -flick.contentY
            width: parent.width
            height: root.contentH

            Label {
                x: Theme.padding.normal
                y: (root.rulerH - height) / 2
                text: `output ${root.editor.fmt(root.project.outLen)}`
                tabular: true
            }

            Repeater {
                model: [{ icon: "movie", text: "video" }, { icon: "blur_on", text: "blur" }, { icon: "image", text: "pictures" }]

                Row {
                    required property var modelData
                    required property int index

                    x: Theme.padding.normal
                    y: root.rowY(index) + (root.rowH - height) / 2
                    spacing: Theme.spacing.normal

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: parent.modelData.icon
                        size: Theme.icon.small
                        dim: true
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.text
                        dim: true
                        font.pixelSize: Theme.size.small
                    }
                }
            }

            Repeater {
                model: root.project.tracks.length

                delegate: Item {
                    id: trackName

                    required property int index
                    readonly property var track: root.project.tracks[index] ?? null
                    readonly property bool isSelected: root.editor.selected?.kind === "track" && root.editor.selected.i === index

                    y: root.rowY(3 + index)
                    width: root.labelW - 1
                    height: root.audioH

                    // The picked channel's row
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.small
                        anchors.rightMargin: Theme.spacing.small
                        anchors.topMargin: 3
                        anchors.bottomMargin: 3
                        radius: Theme.rounding.normal
                        color: trackName.isSelected ? Theme.secondaryContainer : "transparent"

                        Behavior on color {
                            ColorAnim {}
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.editor.select({ kind: "track", i: trackName.index })
                    }

                    IconButton {
                        x: Theme.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        size: 30
                        iconSize: Theme.icon.small
                        icon: trackName.track?.muted ? "volume_off" : "volume_up"
                        iconColor: trackName.track?.muted ? Theme.error : hovered ? Theme.text : Theme.dim
                        onClicked: root.project.updateTrack(trackName.index, { muted: !trackName.track.muted })
                    }

                    StyledText {
                        x: 44
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44 - 74
                        text: trackName.track?.key ?? ""
                        color: trackName.track?.muted ? Theme.outline : Theme.text
                        font.pixelSize: Theme.size.small
                    }

                    Slider {
                        x: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        width: 60
                        thin: true
                        value: trackName.track?.level ?? 1
                        opacity: trackName.track?.muted ? 0.38 : 1
                        onMoved: v => root.project.updateTrack(trackName.index, { level: v }, false)
                    }
                }
            }
        }
    }

    // ── Lanes ────────────────────────────────────────────────

    Flickable {
        id: flick

        x: root.labelW
        width: parent.width - root.labelW
        height: parent.height
        contentWidth: root.laneW
        contentHeight: root.contentH
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: false

        // Empty lanes: click or drag to move the playhead; wheel through time, Ctrl+wheel zoom
        MouseArea {
            width: root.laneW
            height: Math.max(root.contentH, flick.height)
            onPressed: mouse => {
                root.editor.forceActiveFocus();
                root.editor.seek(root.timeAt(mouse.x));
            }
            onPositionChanged: mouse => {
                if (pressed)
                    root.editor.seek(root.timeAt(mouse.x));
            }
            onWheel: wheel => {
                if (wheel.modifiers & Qt.ControlModifier) {
                    const t = root.timeAt(wheel.x);
                    const next = Math.max(4, Math.min(60, root.editor.pps * (wheel.angleDelta.y > 0 ? 1.2 : 1 / 1.2)));
                    root.editor.pps = next;
                    flick.contentX = Math.max(0, t * next - (wheel.x - flick.contentX));
                } else if (wheel.modifiers & Qt.ShiftModifier) {
                    flick.contentY = Math.max(0, Math.min(root.contentH - flick.height, flick.contentY - wheel.angleDelta.y / 2));
                } else {
                    const d = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
                    flick.contentX = Math.max(0, Math.min(root.laneW - flick.width, flick.contentX - d));
                }
            }
        }

        // Ruler and cut marks, drawn for the visible part only
        Canvas {
            id: ruler

            property real from: flick.contentX
            property real zoom: root.pps
            property var segs: root.project.segments
            property color tick: Theme.outline
            property color label: Theme.dim
            property color mark: Theme.tertiary

            x: flick.contentX
            width: flick.width
            height: root.rulerH
            onFromChanged: requestPaint()
            onZoomChanged: requestPaint()
            onSegsChanged: requestPaint()
            onWidthChanged: requestPaint()
            onTickChanged: requestPaint()

            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.font = `${Theme.size.tiny - 1}px "${Theme.font}"`;
                const step = zoom >= 30 ? 1 : zoom >= 12 ? 2 : zoom >= 6 ? 5 : 10;
                const first = Math.floor(from / zoom / step) * step;
                const last = (from + width) / zoom;
                for (let s = first; s <= last && s <= root.project.outLen; s += step) {
                    const x = Math.round(s * zoom - from) + 0.5;
                    const major = Math.round(s / step) % 5 === 0;
                    g.fillStyle = tick;
                    g.fillRect(x, major ? 16 : 21, 1, height);
                    if (major) {
                        g.fillStyle = label;
                        g.fillText(root.editor.fmt(s).replace(/\.0$/, ""), x + 4, 13);
                    }
                }
                // Cuts: a round dot on a short line
                let acc = 0;
                g.fillStyle = mark;
                for (let i = 0; i < segs.length - 1; i++) {
                    acc += segs[i].b - segs[i].a;
                    const x = Math.round(acc * zoom - from);
                    g.fillRect(x - 1, 8, 2, height - 8);
                    g.beginPath();
                    g.arc(x, 6, 4, 0, Math.PI * 2);
                    g.fill();
                }
            }
        }

        // The pieces of the video
        Repeater {
            model: root.project.segments.length

            delegate: Rectangle {
                id: piece

                required property int index
                readonly property var g: root.project.segments[index] ?? null
                readonly property bool isSelected: root.editor.selected?.kind === "seg" && root.editor.selected.i === index

                x: root.project.segStart(index) * root.pps + 1
                y: root.rowY(0) + 5
                width: Math.max(4, (g ? g.b - g.a : 0) * root.pps - 3)
                height: root.rowH - 10
                radius: Theme.rounding.small
                color: isSelected ? Theme.primary : Theme.primaryContainer

                Behavior on color {
                    ColorAnim {}
                }

                StyledText {
                    x: Theme.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.spacing.normal * 2
                    text: piece.g ? `${root.editor.fmt(piece.g.a)}–${root.editor.fmt(piece.g.b)}` : ""
                    color: piece.isSelected ? Theme.textOnPrimary : Theme.textOnPrimaryContainer
                    tabular: true
                    font.pixelSize: Theme.size.tiny - 1
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => {
                        root.editor.forceActiveFocus();
                        root.editor.select({ kind: "seg", i: piece.index });
                        root.editor.seek(root.timeAt(piece.x + mouse.x));
                    }
                }
            }
        }

        // Blur boxes and pictures: drag to move, drag an end to change from or to
        Repeater {
            model: root.project.overlays.length

            delegate: Rectangle {
                id: bar

                required property int index
                readonly property var o: root.project.overlays[index] ?? null
                readonly property bool isBlur: o?.type === "blur"
                readonly property bool isSelected: o !== null && root.editor.selOverlay !== null && root.editor.selOverlay.id === o.id
                readonly property color tint: isBlur ? Theme.tertiary : Theme.secondary

                visible: o !== null
                x: (o?.start ?? 0) * root.pps
                y: root.rowY(isBlur ? 1 : 2) + 7
                width: Math.max(14, ((o?.end ?? 0) - (o?.start ?? 0)) * root.pps)
                height: root.rowH - 14
                radius: height / 2
                color: isSelected ? tint : Theme.alpha(tint, barArea.containsMouse ? 0.32 : 0.22)

                Behavior on color {
                    ColorAnim {}
                }

                StyledText {
                    x: Theme.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.spacing.medium * 2
                    text: bar.o?.name ?? ""
                    color: bar.isSelected ? Theme.page : Theme.text
                    font.pixelSize: Theme.size.tiny - 1
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: barArea

                    property string mode: "move"
                    property real x0: 0
                    property real s0: 0
                    property real e0: 0

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: mouseX < 8 || mouseX > width - 8 ? Qt.SizeHorCursor : Qt.OpenHandCursor
                    onPressed: mouse => {
                        root.editor.forceActiveFocus();
                        root.editor.select({ kind: "overlay", id: bar.o.id });
                        root.project.snapshot();
                        mode = mouse.x < 8 ? "start" : mouse.x > width - 8 ? "end" : "move";
                        x0 = mapToItem(flick.contentItem, mouse.x, 0).x;
                        s0 = bar.o.start;
                        e0 = bar.o.end;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        const d = (mapToItem(flick.contentItem, mouse.x, 0).x - x0) / root.pps;
                        const L = root.project.outLen;
                        let start = s0, end = e0;
                        if (mode === "move") {
                            start = Math.max(0, Math.min(L - (e0 - s0), s0 + d));
                            end = start + (e0 - s0);
                        } else if (mode === "start") {
                            start = Math.max(0, Math.min(e0 - 0.3, s0 + d));
                        } else {
                            end = Math.max(s0 + 0.3, Math.min(L, e0 + d));
                        }
                        root.project.updateOverlay(bar.o.id, { start, end }, false);
                    }
                }
            }
        }

        // One waveform per channel, drawn for the visible part only
        Repeater {
            model: root.project.tracks.length

            delegate: Item {
                id: lane

                required property int index
                readonly property var track: root.project.tracks[index] ?? null

                y: root.rowY(3 + index)
                width: root.laneW
                height: root.audioH

                Canvas {
                    id: wave

                    property real from: flick.contentX
                    property real zoom: root.pps
                    property var values: root.project.peaks[lane.track?.key ?? ""] ?? []
                    property var segs: root.project.segments
                    property real level: lane.track?.level ?? 1
                    property bool muted: lane.track?.muted ?? false
                    property real offset: lane.track && lane.track.file !== "" ? lane.track.offset : 0
                    property color fill: muted ? Theme.outline : Theme.primary

                    x: flick.contentX
                    width: flick.width
                    height: parent.height
                    onFromChanged: requestPaint()
                    onZoomChanged: requestPaint()
                    onValuesChanged: requestPaint()
                    onSegsChanged: requestPaint()
                    onLevelChanged: requestPaint()
                    onMutedChanged: requestPaint()
                    onOffsetChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onFillChanged: requestPaint()

                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const mid = height / 2;
                        g.fillStyle = fill;
                        if (values.length === 0) {
                            g.fillRect(0, mid - 1, Math.min(width, root.project.outLen * zoom - from), 2);
                            return;
                        }
                        const gain = muted ? 0.4 : Math.max(0.05, level);
                        const rate = root.project.peakRate;
                        // Bars of 2 px with a gap, rounded at both ends
                        for (let x = 0; x < width; x += 3) {
                            const t = (from + x) / zoom;
                            if (t > root.project.outLen)
                                break;
                            const v = values[Math.floor((root.project.toSrc(t) + offset) * rate)] ?? 0;
                            const a = Math.max(1, v * gain * (mid - 6));
                            g.beginPath();
                            g.moveTo(x + 1, mid - a);
                            g.lineTo(x + 1, mid + a);
                            g.lineWidth = 2;
                            g.lineCap = "round";
                            g.strokeStyle = fill;
                            g.stroke();
                        }
                    }
                }
            }
        }

        // Playhead: a line with a round knob on the ruler
        Item {
            x: root.editor.playhead * root.pps
            width: 1
            height: Math.max(root.contentH, flick.height)
            z: 5

            Rectangle {
                x: -1
                width: 2
                height: parent.height
                color: Theme.primary
            }

            Rectangle {
                x: -6
                y: 4
                width: 12
                height: 12
                radius: width / 2
                color: Theme.primary
                border.width: 2
                border.color: Theme.container
            }
        }
    }
}
