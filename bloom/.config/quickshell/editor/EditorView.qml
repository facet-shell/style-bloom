import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import qs.components
import qs.config

// The recording editor's window content: the preview with the pictures and blur boxes on
// top, the inspector for what is picked, the transport and the timeline (EditorTimeline.qml),
// each a rounded panel on the window's dark page. Loaded only when a video opens
// (EditorWindow.qml), so a missing Qt Multimedia (qt6-multimedia-ffmpeg) costs the editor,
// never the shell.
//
// Playback: the video plays in its own player and every separate track in one of its own,
// kept in step with the video; at the end of a piece the players jump to the next one.
FocusScope {
    id: root

    signal closeRequested()

    readonly property alias project: project
    // Output seconds
    property real playhead: 0
    property bool playing: false
    property int curSeg: 0
    // { kind: "overlay", id } | { kind: "seg", i } | { kind: "track", i } | null
    property var selected: null
    // Timeline pixels per second
    property real pps: 12
    // "export & delete raw" waits for a yes
    property bool confirmRaw: false

    readonly property var selOverlay: selected?.kind === "overlay" ? project.overlay(selected.id) : null

    EditorProject {
        id: project

        // The recording is gone after "export & delete raw"; nothing is written back for it
        onOriginalDeleted: {
            root.pause();
            dirty = false;
            root.closeRequested();
        }
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function fmt(s) {
        s = Math.max(0, s);
        const m = Math.floor(s / 60);
        const r = s - m * 60;
        return `${m}:${r.toFixed(1).padStart(4, "0")}`;
    }

    function openFile(path) {
        pause();
        selected = null;
        confirmRaw = false;
        playhead = 0;
        curSeg = 0;
        project.load(path);
        player.source = fileUrl(path);
        forceActiveFocus();
    }

    // ── Playback ─────────────────────────────────────────────

    function trackPlayer(i) {
        return trackPlayers.objectAt(i);
    }

    function syncTracks(src, force) {
        for (let i = 0; i < project.tracks.length; i++) {
            const t = project.tracks[i];
            const p = trackPlayer(i);
            if (!p || t.file === "")
                continue;
            const want = Math.max(0, (src + t.offset) * 1000);
            if (force || Math.abs(p.position - want) > 120)
                p.setPosition(want);
        }
    }

    function seek(t) {
        playhead = Math.max(0, Math.min(project.outLen, t));
        const loc = project.locate(playhead);
        curSeg = loc.i;
        // A stopped player shows no picture; paused, it shows the frame at the position
        if (!playing && player.playbackState === MediaPlayer.StoppedState)
            player.pause();
        player.setPosition(loc.src * 1000);
        syncTracks(loc.src, true);
    }

    function play() {
        if (project.segments.length === 0)
            return;
        if (playhead >= project.outLen - 0.05)
            playhead = 0;
        seek(playhead);
        player.play();
        for (let i = 0; i < project.tracks.length; i++)
            if (project.tracks[i].file !== "")
                trackPlayer(i)?.play();
        playing = true;
    }

    function pause() {
        player.pause();
        for (let i = 0; i < trackPlayers.count; i++)
            trackPlayer(i)?.pause();
        playing = false;
    }

    function toggle() {
        if (playing)
            pause();
        else
            play();
    }

    function select(s) {
        selected = s;
    }

    // Zoom so the whole output fits the lanes, within the zoom slider's range
    function fitZoom() {
        if (project.outLen > 0)
            pps = Math.max(4, Math.min(60, (timeline.width - timeline.labelW - 100) / project.outLen));
    }

    // ── Editing ──────────────────────────────────────────────

    function cut() {
        const i = project.cut(playhead);
        if (i >= 0)
            select({ kind: "seg", i });
    }

    function removeSelected() {
        if (!selected)
            return;
        if (selected.kind === "overlay")
            project.removeOverlay(selected.id);
        else if (selected.kind === "seg")
            project.removeSegment(selected.i);
        else
            return;
        select(null);
        seek(Math.min(playhead, project.outLen));
    }

    function addBlur() {
        select({ kind: "overlay", id: project.addBlur(playhead) });
    }

    function close() {
        pause();
        project.writeNow();
        closeRequested();
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const step = event.modifiers & Qt.ShiftModifier ? 5 : 1;
        if (event.key === Qt.Key_Space)
            toggle();
        else if (event.key === Qt.Key_C && !ctrl)
            cut();
        else if (event.key === Qt.Key_B)
            addBlur();
        else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
            removeSelected();
        else if (event.key === Qt.Key_Z && ctrl) {
            if (project.undo()) {
                select(null);
                seek(Math.min(playhead, project.outLen));
            }
        } else if (event.key === Qt.Key_Left)
            seek(playhead - step);
        else if (event.key === Qt.Key_Right)
            seek(playhead + step);
        else if (event.key === Qt.Key_Home)
            seek(0);
        else if (event.key === Qt.Key_End)
            seek(project.outLen);
        else if (event.key === Qt.Key_Escape)
            select(null);
        else
            return;
        event.accepted = true;
    }

    MediaPlayer {
        id: player

        videoOutput: video
        audioOutput: AudioOutput {
            // The video's own (mixed) sound plays only when there are no separate tracks
            volume: {
                if (project.separateTracks)
                    return 0;
                const t = project.tracks[0];
                return !t || t.muted ? 0 : t.level;
            }
        }
        onDurationChanged: {
            if (player.duration > 0) {
                project.setDuration(player.duration / 1000);
                root.fitZoom();
                root.seek(root.playhead);
            }
        }
        onHasAudioChanged: project.videoHasAudio = hasAudio
        // The file ran out before the last piece's end was seen
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && root.playing) {
                root.pause();
                root.playhead = project.outLen;
            }
        }
    }

    // One player per separate track; the model is a count, so changing a level keeps them
    Instantiator {
        id: trackPlayers

        model: project.tracks.length
        delegate: MediaPlayer {
            required property int index
            readonly property var track: project.tracks[index] ?? null

            source: track && track.file !== "" ? root.fileUrl(track.file) : ""
            audioOutput: AudioOutput {
                volume: !track || track.muted ? 0 : track.level
            }
        }
    }

    // Follows the video through the pieces: at the end of one, on to the next
    Timer {
        running: root.playing
        interval: 30
        repeat: true
        onTriggered: {
            const g = project.segments[root.curSeg];
            if (!g)
                return;
            const pos = player.position / 1000;
            if (pos >= g.b - 0.02) {
                if (root.curSeg + 1 < project.segments.length) {
                    root.curSeg += 1;
                    const next = project.segments[root.curSeg];
                    player.setPosition(next.a * 1000);
                    root.syncTracks(next.a, true);
                    root.playhead = project.segStart(root.curSeg);
                } else {
                    root.pause();
                    root.playhead = project.outLen;
                }
            } else if (pos >= g.a - 0.25) {
                root.playhead = project.segStart(root.curSeg) + Math.max(0, pos - g.a);
            }
        }
    }

    // Tracks drift a little against the video; pulled back when it gets audible
    Timer {
        running: root.playing
        interval: 500
        repeat: true
        onTriggered: root.syncTracks(player.position / 1000, false)
    }

    // ── Building blocks ──────────────────────────────────────

    component Panel: Rectangle {
        radius: Theme.rounding.large
        color: Theme.surface
    }

    // A dim line of text that wraps
    component Note: StyledText {
        Layout.fillWidth: true
        dim: true
        wrapMode: Text.Wrap
        font.pixelSize: Theme.size.small
    }

    // A thin slider with its name in front and its value behind
    component LabeledSlider: RowLayout {
        id: labeled

        property string title: ""
        property string valueText: ""
        property real value: 0

        signal moved(real value)

        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        StyledText {
            text: labeled.title
            dim: true
            font.pixelSize: Theme.size.small
            Layout.preferredWidth: 64
        }
        Slider {
            Layout.fillWidth: true
            thin: true
            value: labeled.value
            onMoved: v => labeled.moved(v)
        }
        StyledText {
            text: labeled.valueText
            tabular: true
            font.pixelSize: Theme.size.small
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 52
        }
    }

    // ── Layout ───────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding.drawer
        spacing: Theme.spacing.medium

        // Title and close
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: height / 2
                color: Theme.primaryContainer

                Icon {
                    anchors.centerIn: parent
                    icon: "movie_edit"
                    color: Theme.onPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: project.name
                    font.pixelSize: Theme.size.medium
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    dim: true
                    font.pixelSize: Theme.size.small
                    text: project.videoWidth > 0 ? `${project.videoWidth}×${project.videoHeight} · ${root.fmt(project.duration)} recorded, ${root.fmt(project.outLen)} after cuts`
                        : "recording"
                }
            }

            IconButton {
                icon: "close"
                onClicked: root.close()
            }
        }

        // Preview and inspector take what the timeline leaves
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing.medium

            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.padding.normal
                    spacing: Theme.spacing.normal

                    // A plain clipped item, not a ClippingRectangle: the blur boxes read the
                    // video straight from VideoOutput, which a layer in between would break
                    Item {
                        id: stage

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rounding.medium
                            color: Theme.page
                        }

                        VideoOutput {
                            id: video

                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectFit
                            onSourceRectChanged: {
                                if (sourceRect.width > 0) {
                                    project.videoWidth = Math.round(sourceRect.width);
                                    project.videoHeight = Math.round(sourceRect.height);
                                }
                            }
                        }

                        // The video's own rectangle inside the stage; overlays are fractions of it
                        Item {
                            id: frameArea

                            x: video.contentRect.x
                            y: video.contentRect.y
                            width: video.contentRect.width
                            height: video.contentRect.height

                            MouseArea {
                                anchors.fill: parent
                                onPressed: root.select(null)
                            }

                            Repeater {
                                model: project.overlays.length

                                delegate: OverlayBox {
                                    required property int index

                                    o: project.overlays[index] ?? null
                                    store: project
                                    frame: frameArea
                                    capture: video
                                    nativeWidth: project.videoWidth
                                    shown: o !== null && root.playhead >= o.start && root.playhead < o.end
                                    selected: o !== null && root.selOverlay !== null && root.selOverlay.id === o.id
                                    onPicked: {
                                        root.select({ kind: "overlay", id: o.id });
                                        root.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        // Pictures dragged in from Dolphin land where they are dropped
                        DropArea {
                            anchors.fill: parent
                            onEntered: drag => drag.accepted = drag.hasUrls
                            onDropped: drop => {
                                const p = frameArea.mapFromItem(stage, drop.x, drop.y);
                                for (const url of drop.urls) {
                                    const path = decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
                                    if (!/\.(png|jpe?g|webp|gif|bmp)$/i.test(path))
                                        continue;
                                    const id = project.addPicture(root.playhead, path,
                                        Math.max(0, Math.min(1, p.x / frameArea.width)), Math.max(0, Math.min(1, p.y / frameArea.height)));
                                    root.select({ kind: "overlay", id });
                                }
                                drop.accept();
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: player.error !== MediaPlayer.NoError
                            spacing: Theme.spacing.normal

                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "error"
                                size: Theme.icon.huge
                                color: Theme.error
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: player.errorString || "Cannot play this file"
                                color: Theme.error
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacing.small
                        dim: true
                        font.pixelSize: Theme.size.tiny
                        text: "space play · c cut · del remove · b blur box · ctrl+z undo · ←/→ 1 s (shift 5 s) · drop a picture on the preview"
                    }
                }
            }

            // The inspector
            Panel {
                Layout.preferredWidth: 340
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.padding.card
                    spacing: Theme.spacing.medium

                    StyledText {
                        text: root.selected === null ? "Project"
                            : root.selected.kind === "seg" ? `Piece ${root.selected.i + 1} of ${project.segments.length}`
                            : root.selected.kind === "track" ? "Channel"
                            : root.selOverlay?.type === "blur" ? "Blur box" : "Picture"
                        color: Theme.primary
                        font.pixelSize: Theme.size.small
                        font.weight: Font.DemiBold
                    }

                    // Nothing picked: the project
                    ColumnLayout {
                        visible: root.selected === null
                        Layout.fillWidth: true
                        spacing: Theme.spacing.normal

                        StyledText {
                            Layout.fillWidth: true
                            text: project.name
                            font.weight: Font.Medium
                        }
                        Note {
                            text: `${root.fmt(project.duration)} recorded, ${root.fmt(project.outLen)} after cuts · ${project.segments.length} piece${project.segments.length === 1 ? "" : "s"} · `
                                + `${project.overlays.filter(o => o.type === "picture").length} pictures · ${project.overlays.filter(o => o.type === "blur").length} blur boxes`
                        }
                        Note {
                            text: project.separateTracks
                                ? `${project.tracks.length} channels on their own tracks`
                                : project.videoHasAudio
                                    ? "The recording's own sound (no separate tracks: none were chosen while recording)"
                                    : "No sound: the recording was made without a channel"
                        }
                        Note {
                            wrapMode: Text.WrapAnywhere
                            text: `export: ${project.exportFile.slice(project.exportFile.lastIndexOf("/") + 1)}`
                        }
                        Note {
                            visible: project.exportError !== ""
                            color: Theme.error
                            text: project.exportError
                        }
                    }

                    // A picture or a blur box
                    ColumnLayout {
                        readonly property var o: root.selOverlay

                        visible: root.selOverlay !== null
                        Layout.fillWidth: true
                        spacing: Theme.spacing.medium

                        StyledText {
                            Layout.fillWidth: true
                            text: parent.o?.name ?? ""
                            font.weight: Font.Medium
                        }
                        Note {
                            text: parent.o ? `${parent.o.type === "blur" ? "Hides what is under it" : "Shown"} from ${root.fmt(parent.o.start)} to ${root.fmt(parent.o.end)}` : ""
                        }

                        SegmentedButtons {
                            visible: parent.o?.type === "blur"
                            model: [{ key: "blur", label: "blur", icon: "blur_on" }, { key: "pixel", label: "pixelate", icon: "grid_on" }]
                            current: root.selOverlay?.style === "pixel" ? "pixel" : "blur"
                            onSelected: key => project.updateOverlay(root.selOverlay.id, { style: key })
                        }

                        LabeledSlider {
                            visible: parent.o?.type === "blur"
                            title: "strength"
                            value: ((root.selOverlay?.strength ?? 14) - 4) / 26
                            valueText: String(root.selOverlay?.strength ?? "")
                            onMoved: v => project.updateOverlay(root.selOverlay.id, { strength: Math.round(4 + v * 26) }, false)
                        }

                        LabeledSlider {
                            visible: parent.o?.type === "picture"
                            title: "opacity"
                            value: root.selOverlay?.opacity ?? 1
                            valueText: `${Math.round((root.selOverlay?.opacity ?? 1) * 100)}%`
                            onMoved: v => project.updateOverlay(root.selOverlay.id, { opacity: Math.max(0.05, v) }, false)
                        }

                        Note {
                            text: parent.o && project.videoWidth > 0
                                ? `x ${Math.round(parent.o.x * project.videoWidth)} · y ${Math.round(parent.o.y * project.videoHeight)} · ${Math.round(parent.o.w * project.videoWidth)}×${Math.round((parent.o.h > 0 ? parent.o.h : parent.o.w) * project.videoHeight)} px`
                                : ""
                        }

                        RowLayout {
                            spacing: Theme.spacing.normal

                            Button {
                                text: "go to start"
                                icon: "first_page"
                                onClicked: root.seek(root.selOverlay.start)
                            }
                            Button {
                                text: "remove"
                                icon: "delete"
                                variant: "danger"
                                onClicked: root.removeSelected()
                            }
                        }
                    }

                    // A piece of the video
                    ColumnLayout {
                        readonly property var g: root.selected?.kind === "seg" ? project.segments[root.selected.i] ?? null : null

                        visible: root.selected?.kind === "seg"
                        Layout.fillWidth: true
                        spacing: Theme.spacing.medium

                        Note {
                            text: parent.g ? `Source ${root.fmt(parent.g.a)} to ${root.fmt(parent.g.b)}, ${(parent.g.b - parent.g.a).toFixed(1)} s` : ""
                        }
                        Note {
                            text: "Removing it closes the gap; pictures and blur boxes after it move along."
                        }
                        Button {
                            text: "remove piece"
                            icon: "content_cut"
                            variant: "danger"
                            disabled: project.segments.length < 2
                            onClicked: root.removeSelected()
                        }
                    }

                    // A channel
                    ColumnLayout {
                        id: channel

                        readonly property int i: root.selected?.kind === "track" ? root.selected.i : -1
                        readonly property var t: i >= 0 ? project.tracks[i] ?? null : null

                        visible: root.selected?.kind === "track"
                        Layout.fillWidth: true
                        spacing: Theme.spacing.medium

                        StyledText {
                            text: channel.t?.key ?? ""
                            font.weight: Font.Medium
                        }
                        Note {
                            wrapMode: Text.WrapAnywhere
                            text: channel.t ? (channel.t.file !== "" ? channel.t.file.slice(channel.t.file.lastIndexOf("/") + 1) + ", its own track" : "The sound inside the video") : ""
                        }

                        LabeledSlider {
                            title: "level"
                            value: channel.t?.level ?? 1
                            valueText: `${Math.round((channel.t?.level ?? 1) * 100)}%`
                            onMoved: v => project.updateTrack(channel.i, { level: v }, false)
                        }

                        // ± half a second around the measured start, for when a channel sounds late or early
                        LabeledSlider {
                            visible: (channel.t?.file ?? "") !== ""
                            title: "sync"
                            value: channel.t ? 0.5 + (channel.t.offset - (channel.t.base ?? channel.t.offset)) : 0.5
                            valueText: channel.t ? `${Math.round((channel.t.offset - (channel.t.base ?? channel.t.offset)) * 1000)} ms` : ""
                            onMoved: v => {
                                const base = channel.t.base ?? channel.t.offset;
                                project.updateTrack(channel.i, { offset: Math.max(0, base + (v - 0.5)), base }, false);
                                root.syncTracks(project.toSrc(root.playhead), true);
                            }
                        }

                        Button {
                            text: channel.t?.muted ? "unmute" : "mute"
                            icon: channel.t?.muted ? "volume_up" : "volume_off"
                            onClicked: project.updateTrack(channel.i, { muted: !channel.t.muted })
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        // As tall as its rows need (ruler, video, blur, pictures, one per channel), at most a bit
        // under half the window; more rows scroll (shift+wheel). A preferred height is a weight
        // for Qt's layouts, so a small one next to a minimum would starve the preview.
        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(240, Math.min(Math.round(root.height * 0.45), timeline.contentH + 96))

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding.normal
                spacing: Theme.spacing.normal

                // The transport and the tools
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    IconButton {
                        icon: root.playing ? "pause" : "play_arrow"
                        filled: true
                        active: root.playing
                        size: Theme.control.button
                        onClicked: root.toggle()
                    }

                    StyledText {
                        Layout.preferredWidth: 130
                        text: `${root.fmt(root.playhead)} / ${root.fmt(project.outLen)}`
                        tabular: true
                    }

                    Chip {
                        text: "cut"
                        icon: "content_cut"
                        onClicked: root.cut()
                    }
                    Chip {
                        text: "blur"
                        icon: "blur_on"
                        onClicked: root.addBlur()
                    }
                    Chip {
                        text: "pictures…"
                        icon: "add_photo_alternate"
                        onClicked: Quickshell.execDetached(["xdg-open", `${Quickshell.env("HOME")}/Pictures`])
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Icon {
                        icon: "zoom_in"
                        size: Theme.icon.small
                        dim: true
                    }
                    Slider {
                        Layout.preferredWidth: 120
                        thin: true
                        value: (root.pps - 4) / 56
                        onMoved: v => root.pps = 4 + v * 56
                    }

                    StyledText {
                        visible: project.exporting
                        Layout.leftMargin: Theme.spacing.normal
                        text: `exporting ${Math.round(project.exportProgress * 100)}%`
                        color: Theme.primary
                        tabular: true
                        font.pixelSize: Theme.size.small
                    }

                    Button {
                        visible: !root.confirmRaw
                        text: project.exporting ? "cancel" : "export"
                        icon: project.exporting ? "close" : "file_export"
                        variant: project.exporting ? "tonal" : "filled"
                        disabled: !project.exporting && (project.videoWidth <= 0 || project.segments.length === 0)
                        onClicked: project.exporting ? project.cancelExport() : project.startExport(false)
                    }

                    Button {
                        visible: !project.exporting && !root.confirmRaw
                        text: "export & delete raw"
                        icon: "delete"
                        variant: "danger"
                        disabled: project.videoWidth <= 0 || project.segments.length === 0
                        onClicked: root.confirmRaw = true
                    }

                    // Asked in place: no dialog
                    StyledText {
                        visible: root.confirmRaw
                        text: "Then the recording, its tracks and this edit go into the trash?"
                        color: Theme.error
                        font.pixelSize: Theme.size.small
                    }

                    Button {
                        visible: root.confirmRaw
                        text: "yes"
                        variant: "danger"
                        onClicked: {
                            root.confirmRaw = false;
                            project.startExport(true);
                        }
                    }

                    Button {
                        visible: root.confirmRaw
                        text: "no"
                        variant: "text"
                        onClicked: root.confirmRaw = false
                    }
                }

                // Export progress under the transport
                ProgressBar {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacing.small
                    Layout.rightMargin: Theme.spacing.small
                    thickness: 4
                    value: project.exportProgress
                    opacity: project.exporting ? 1 : 0
                    animated: false

                    Behavior on opacity {
                        Anim {}
                    }
                }

                EditorTimeline {
                    id: timeline

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    editor: root
                }
            }
        }
    }
}
