import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The media app's content: every screenshot and recording (plus folders dropped on it) as a
// grid of round tiles, newest first. Click picks one, Ctrl+click more, Shift+click a run;
// double click opens it in the editor. "delete" moves the picked ones into the trash together
// with what belongs to them (a recording's .tracks folder, an .edit.json).
// Files: quickshell/.local/bin/facet-media (core).
FocusScope {
    id: root

    signal closeRequested()

    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/facet-media`
    property string picturesDir: `${Quickshell.env("HOME")}/Pictures`
    readonly property string shotsDir: `${picturesDir}/screenshots`
    // Paint's pages (Editor.newPicture)
    readonly property string paintDir: `${picturesDir}/paintings`
    readonly property var fixedFolders: [shotsDir, paintDir, Recorder.folder]
    readonly property var folders: fixedFolders.concat(extraFolders)
    // "new picture" asks for the paper in place
    property bool choosePaper: false
    // Folders dropped on the app, kept in media.json
    property var extraFolders: []
    readonly property string thumbDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/facet/media`

    // Everything found: [{ path, name, kind, mtime, size, edited, tracks, duration, thumb }]
    property var all: []
    property string filter: "all"
    // path → true
    property var picked: ({})
    readonly property var pickedPaths: Object.keys(picked)
    property int anchorIndex: -1
    property bool confirmDelete: false
    property string status: ""
    // .edit.json files and .tracks folders whose picture or video is gone (facet-media leftovers)
    property var leftovers: []

    readonly property int columns: Math.max(2, Math.floor(grid.width / 280))
    readonly property var filters: [
        { key: "all", label: "All", icon: "perm_media" },
        { key: "pictures", label: "Pictures", icon: "image" },
        { key: "videos", label: "Videos", icon: "movie" },
        { key: "edited", label: "Edited", icon: "edit" }
    ]

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function fmtSize(bytes) {
        if (bytes >= 1e9)
            return `${(bytes / 1e9).toFixed(1)} GB`;
        if (bytes >= 1e6)
            return `${(bytes / 1e6).toFixed(1)} MB`;
        return `${Math.max(1, Math.round(bytes / 1e3))} KB`;
    }

    function fmtLength(s) {
        s = Math.round(s);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    function fits(it, f) {
        return f === "all" || (f === "pictures" && it.kind === "image")
            || (f === "videos" && it.kind === "video") || (f === "edited" && it.edited);
    }

    function count(f) {
        return all.filter(it => fits(it, f)).length;
    }

    function refresh() {
        if (listProc.running)
            return;
        listProc.command = [tool, "list"].concat(folders);
        listProc.running = true;
    }

    function rebuild() {
        shown.clear();
        for (const it of all)
            if (fits(it, filter))
                shown.append(it);
        const keep = {};
        for (const p of pickedPaths)
            if (all.some(it => it.path === p))
                keep[p] = true;
        picked = keep;
        anchorIndex = -1;
    }

    onFilterChanged: rebuild()

    // ── Picking ──────────────────────────────────────────────

    function click(index, modifiers) {
        const path = shown.get(index).path;
        if (modifiers & Qt.ControlModifier) {
            const next = Object.assign({}, picked);
            if (next[path])
                delete next[path];
            else
                next[path] = true;
            picked = next;
            anchorIndex = index;
        } else if ((modifiers & Qt.ShiftModifier) && anchorIndex >= 0) {
            const next = {};
            for (let i = Math.min(anchorIndex, index); i <= Math.max(anchorIndex, index); i++)
                next[shown.get(i).path] = true;
            picked = next;
        } else {
            picked = { [path]: true };
            anchorIndex = index;
        }
        confirmDelete = false;
    }

    function pickAll() {
        const next = {};
        for (let i = 0; i < shown.count; i++)
            next[shown.get(i).path] = true;
        picked = next;
    }

    function pickedSize() {
        let s = 0;
        for (const it of all)
            if (picked[it.path])
                s += it.size;
        return s;
    }

    // ── Actions ──────────────────────────────────────────────

    function openPicked() {
        if (pickedPaths.length > 0)
            Editor.open(pickedPaths[0]);
    }

    // One picture goes in as the picture, anything else as files (chats take both)
    function copyPicked() {
        const paths = pickedPaths;
        if (paths.length === 0)
            return;
        if (paths.length === 1 && Editor.isImage(paths[0]))
            Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "facet-media", paths[0]]);
        else
            Quickshell.execDetached(["sh", "-c", 'for f in "$@"; do printf "file://%s\\n" "$f"; done | wl-copy --type text/uri-list', "facet-media"].concat(paths));
        status = paths.length === 1 ? "Copied" : `${paths.length} files copied`;
    }

    function trash(paths) {
        if (paths.length === 0 || trashProc.running)
            return;
        trashProc.count = paths.length;
        trashProc.command = [tool, "trash"].concat(paths);
        trashProc.running = true;
    }

    function deletePicked() {
        trash(pickedPaths);
        confirmDelete = false;
    }

    function addFolder(path) {
        const dir = path.replace(/\/+$/, "");
        if (dir === "" || folders.includes(dir))
            return;
        extraFolders = extraFolders.concat([dir]);
        store.setText(JSON.stringify({ folders: extraFolders }));
        refresh();
    }

    function removeFolder(dir) {
        extraFolders = extraFolders.filter(d => d !== dir);
        store.setText(JSON.stringify({ folders: extraFolders }));
        refresh();
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_A && ctrl)
            pickAll();
        else if (event.key === Qt.Key_Delete)
            confirmDelete = pickedPaths.length > 0;
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            openPicked();
        else if (event.key === Qt.Key_C && ctrl)
            copyPicked();
        else if (event.key === Qt.Key_F5)
            refresh();
        else if (event.key === Qt.Key_Escape) {
            if (confirmDelete)
                confirmDelete = false;
            else if (pickedPaths.length > 0)
                picked = {};
            else
                root.closeRequested();
        } else
            return;
        event.accepted = true;
    }

    ListModel {
        id: shown
    }

    // ── Files ────────────────────────────────────────────────

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: {
                const old = {};
                for (const it of root.all)
                    old[it.path] = it;
                const next = [];
                for (const line of this.text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 6)
                        continue;
                    const path = f[3];
                    const mtime = Number(f[0]);
                    const before = old[path];
                    next.push({
                        path,
                        name: path.slice(path.lastIndexOf("/") + 1),
                        kind: f[2],
                        mtime,
                        size: Number(f[1]),
                        edited: f[4] === "1",
                        tracks: f[5] === "1",
                        duration: before && before.mtime === mtime ? before.duration : 0,
                        thumb: before && before.mtime === mtime ? before.thumb : ""
                    });
                }
                root.all = next;
                root.rebuild();
                thumbs.queue = next.filter(it => it.kind === "video" && it.thumb === "").map(it => it.path);
                thumbs.next();
                leftoverProc.command = [root.tool, "leftovers"].concat(root.folders);
                leftoverProc.running = true;
            }
        }
    }

    // Video thumbnails (ffmpeg, cached by path and time) and lengths, one after another
    Process {
        id: thumbs

        property var queue: []
        property string path: ""
        property string file: ""

        function next() {
            if (running || queue.length === 0)
                return;
            path = queue[0];
            queue = queue.slice(1);
            const it = root.all.find(x => x.path === path);
            if (!it) {
                next();
                return;
            }
            file = `${root.thumbDir}/${Qt.md5(path + ":" + it.mtime)}.jpg`;
            command = [root.tool, "thumb", path, file];
            running = true;
        }

        stdout: StdioCollector {
            id: thumbOut
        }
        onExited: {
            const duration = Number(thumbOut.text.trim()) || 0;
            const it = root.all.find(x => x.path === path);
            if (it) {
                it.thumb = file;
                it.duration = duration;
                for (let i = 0; i < shown.count; i++) {
                    if (shown.get(i).path === path) {
                        shown.setProperty(i, "thumb", file);
                        shown.setProperty(i, "duration", duration);
                        break;
                    }
                }
            }
            next();
        }
    }

    Process {
        id: leftoverProc

        stdout: StdioCollector {
            onStreamFinished: root.leftovers = this.text.split("\n").filter(l => l !== "")
        }
    }

    Process {
        id: trashProc

        property int count: 0

        stderr: StdioCollector {
            id: trashErrors
        }
        onExited: code => {
            root.status = code === 0 ? `${count} moved to the trash` : (trashErrors.text.trim().split("\n").pop() || "Could not delete");
            root.picked = {};
            root.refresh();
        }
    }

    Process {
        command: ["xdg-user-dir", "PICTURES"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = this.text.trim();
                if (dir !== "")
                    root.picturesDir = dir;
            }
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("media.json")
        printErrors: false
        onLoaded: {
            try {
                root.extraFolders = (JSON.parse(text()).folders ?? []).filter(d => typeof d === "string");
            } catch (e) {
                root.extraFolders = [];
            }
        }
    }

    // A small label pill on a thumbnail
    component Tag: Rectangle {
        property alias text: tagText.text
        property color textColor: Theme.textOnScrim

        implicitWidth: tagText.implicitWidth + 14
        implicitHeight: 22
        radius: height / 2
        color: Theme.scrim

        StyledText {
            id: tagText

            anchors.centerIn: parent
            color: parent.textColor
            font.pixelSize: Theme.size.tiny - 1
            font.weight: Font.Medium
        }
    }

    // ── Layout ───────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding.drawer
        spacing: Theme.spacing.medium

        // Title, filters, new picture, refresh
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: height / 2
                color: Theme.primaryContainer

                Icon {
                    anchors.centerIn: parent
                    icon: "photo_library"
                    color: Theme.textOnPrimaryContainer
                }
            }

            StyledText {
                Layout.rightMargin: Theme.spacing.medium
                text: "Media"
                font.pixelSize: Theme.size.large
                font.weight: Font.Medium
            }

            Repeater {
                model: root.filters

                Chip {
                    required property var modelData

                    text: `${modelData.label} ${root.count(modelData.key)}`
                    icon: modelData.icon
                    selected: root.filter === modelData.key
                    onClicked: root.filter = modelData.key
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                dim: true
                font.pixelSize: Theme.size.small
                text: listProc.running ? "looking…" : `${root.all.length} files · ${root.fmtSize(root.all.reduce((s, it) => s + it.size, 0))}`
            }

            // Edits and tracks of files deleted elsewhere (Dolphin): into the trash with one click
            Chip {
                visible: root.leftovers.length > 0
                text: `clean up ${root.leftovers.length} leftover${root.leftovers.length === 1 ? "" : "s"}`
                icon: "cleaning_services"
                onClicked: root.trash(root.leftovers)
            }

            // Paint: an empty page in the picture editor, the paper asked in place
            Button {
                visible: !root.choosePaper
                text: "new picture"
                icon: "brush"
                variant: "tonal"
                onClicked: root.choosePaper = true
            }
            StyledText {
                visible: root.choosePaper
                text: "paper"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Repeater {
                model: root.choosePaper ? Editor.papers : []

                Chip {
                    required property string modelData

                    text: modelData
                    icon: modelData === "theme" ? "palette" : modelData === "white" ? "crop_portrait" : "texture"
                    onClicked: {
                        root.choosePaper = false;
                        Editor.newPicture(modelData);
                    }
                }
            }
            IconButton {
                visible: root.choosePaper
                icon: "close"
                onClicked: root.choosePaper = false
            }

            IconButton {
                icon: "refresh"
                onClicked: root.refresh()
            }
        }

        // What is picked and what to do with it
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.control.button + Theme.padding.small * 2
            radius: height / 2
            color: root.pickedPaths.length > 0 ? Theme.container : "transparent"

            Behavior on color {
                ColorAnim {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padding.card
                anchors.rightMargin: Theme.padding.small
                spacing: Theme.spacing.normal

                StyledText {
                    visible: root.pickedPaths.length === 0
                    Layout.fillWidth: true
                    color: root.status !== "" ? Theme.ok : Theme.dim
                    font.pixelSize: Theme.size.small
                    text: root.status !== "" ? root.status
                        : "Click picks · ctrl+click more · shift+click a run · double click opens in the editor · drop a folder to add it"
                }

                StyledText {
                    visible: root.pickedPaths.length > 0
                    Layout.fillWidth: true
                    text: root.confirmDelete ? `Move ${root.pickedPaths.length} into the trash?`
                        : `${root.pickedPaths.length} picked · ${root.fmtSize(root.pickedSize())}`
                    color: root.confirmDelete ? Theme.error : Theme.text
                    font.weight: Font.Medium
                }

                Button {
                    visible: root.pickedPaths.length > 0 && !root.confirmDelete
                    text: root.pickedPaths.length === 1 ? "edit" : "edit first"
                    icon: "edit"
                    variant: "filled"
                    onClicked: root.openPicked()
                }
                Button {
                    visible: root.pickedPaths.length === 1 && !root.confirmDelete
                    text: "open"
                    icon: "open_in_new"
                    onClicked: Quickshell.execDetached(["xdg-open", root.pickedPaths[0]])
                }
                Button {
                    visible: root.pickedPaths.length > 0 && !root.confirmDelete
                    text: "copy"
                    icon: "content_copy"
                    onClicked: root.copyPicked()
                }
                Button {
                    visible: root.pickedPaths.length > 0 && !root.confirmDelete
                    text: "folder"
                    icon: "folder_open"
                    onClicked: Quickshell.execDetached(["xdg-open", root.pickedPaths[0].slice(0, root.pickedPaths[0].lastIndexOf("/"))])
                }
                Button {
                    visible: root.pickedPaths.length > 0 && !root.confirmDelete
                    text: `delete ${root.pickedPaths.length}`
                    icon: "delete"
                    variant: "danger"
                    onClicked: root.confirmDelete = true
                }

                // Asked in place: no dialog
                Button {
                    visible: root.confirmDelete
                    text: "yes, delete"
                    icon: "delete"
                    variant: "danger"
                    onClicked: root.deletePicked()
                }
                Button {
                    visible: root.confirmDelete
                    text: "no"
                    variant: "text"
                    onClicked: root.confirmDelete = false
                }
            }
        }

        // The grid
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rounding.large
            color: Theme.surface

            ColumnLayout {
                anchors.centerIn: parent
                visible: shown.count === 0 && !listProc.running
                spacing: Theme.spacing.normal

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: root.all.length === 0 ? "photo_camera" : "filter_alt_off"
                    size: Theme.icon.huge
                    dim: true
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    dim: true
                    text: root.all.length === 0 ? "Nothing yet · Print takes a screenshot, Super+Shift+R records" : "Nothing matches"
                }
            }

            GridView {
                id: grid

                anchors.fill: parent
                anchors.margins: Theme.padding.normal
                clip: true
                cellWidth: Math.floor(width / root.columns)
                cellHeight: Math.round(cellWidth * 0.5625) + 58
                model: shown
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: tile

                    required property int index
                    required property string path
                    required property string name
                    required property string kind
                    required property real mtime
                    required property real size
                    required property bool edited
                    required property bool tracks
                    required property real duration
                    required property string thumb
                    readonly property bool isPicked: root.picked[path] === true

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Item {
                        id: body

                        anchors.fill: parent
                        anchors.margins: Theme.spacing.normal
                        // Springs up a little under the mouse, down while pressed
                        scale: area.pressed ? 0.97 : area.containsMouse ? 1.025 : 1

                        Behavior on scale {
                            SpringAnim {}
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing.small

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // The picked ones' ring
                                Rectangle {
                                    anchors.fill: thumb
                                    anchors.margins: -3
                                    radius: thumb.radius + 3
                                    color: "transparent"
                                    border.width: 3
                                    border.color: Theme.primary
                                    opacity: tile.isPicked ? 1 : 0

                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.anim.small
                                        }
                                    }
                                }

                                ClippingRectangle {
                                    id: thumb

                                    anchors.fill: parent
                                    radius: tile.isPicked ? Theme.rounding.drawer : Theme.rounding.large
                                    color: Theme.container

                                    Behavior on radius {
                                        SpringAnim {}
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: tile.kind === "image" ? root.fileUrl(tile.path) : tile.thumb !== "" ? root.fileUrl(tile.thumb) : ""
                                        sourceSize: Qt.size(400, 225)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        visible: tile.kind === "video" && tile.thumb === ""
                                        icon: "movie"
                                        size: Theme.icon.large + 6
                                        dim: true
                                    }

                                    // Badges: edited / tracks top left, length bottom right
                                    Row {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: Theme.padding.small
                                        spacing: Theme.spacing.small

                                        Tag {
                                            visible: tile.edited
                                            text: "edited"
                                            color: Theme.tertiary
                                            textColor: Theme.page
                                        }
                                        Tag {
                                            visible: tile.tracks
                                            text: "tracks"
                                            color: Theme.secondaryContainer
                                            textColor: Theme.text
                                        }
                                    }

                                    Tag {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: Theme.padding.small
                                        visible: tile.kind === "video"
                                        text: tile.duration > 0 ? `▶ ${root.fmtLength(tile.duration)}` : "▶"
                                    }
                                }

                                // The check of a picked one, popping in
                                Rectangle {
                                    anchors.right: thumb.right
                                    anchors.top: thumb.top
                                    anchors.margins: Theme.padding.small
                                    width: 26
                                    height: 26
                                    radius: height / 2
                                    color: Theme.primary
                                    scale: tile.isPicked ? 1 : 0
                                    visible: scale > 0.01

                                    Behavior on scale {
                                        SpringAnim {}
                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        icon: "check"
                                        size: 17
                                        color: Theme.textOnPrimary
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.leftMargin: Theme.spacing.small
                                Layout.rightMargin: Theme.spacing.small
                                text: tile.name
                                elide: Text.ElideMiddle
                                font.pixelSize: Theme.size.small
                                font.weight: tile.isPicked ? Font.Medium : Font.Normal
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.leftMargin: Theme.spacing.small
                                Layout.rightMargin: Theme.spacing.small
                                text: `${Qt.formatDateTime(new Date(tile.mtime * 1000), "dd.MM.yyyy HH:mm")} · ${root.fmtSize(tile.size)}`
                                dim: true
                                tabular: true
                                font.pixelSize: Theme.size.tiny
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                root.forceActiveFocus();
                                root.status = "";
                                root.click(tile.index, mouse.modifiers);
                            }
                            onDoubleClicked: Editor.open(tile.path)
                        }
                    }
                }
            }

            // Files open in the editor; a folder becomes part of the grid
            DropArea {
                anchors.fill: parent
                onEntered: drag => drag.accepted = drag.hasUrls
                onDropped: drop => {
                    for (const url of drop.urls) {
                        const path = decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
                        if (Editor.isVideo(path) || Editor.isImage(path)) {
                            Editor.open(path);
                            break;
                        }
                        if (!/\.[A-Za-z0-9]{1,5}$/.test(path))
                            root.addFolder(path);
                    }
                    drop.accept();
                }
            }
        }

        // The folders the grid shows; dropped ones can go again
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            Repeater {
                model: root.folders

                Chip {
                    required property string modelData
                    required property int index

                    compact: true
                    icon: "folder"
                    text: modelData.replace(Quickshell.env("HOME"), "~")
                    closable: index >= root.fixedFolders.length
                    onClicked: Quickshell.execDetached(["xdg-open", modelData])
                    onCloseClicked: root.removeFolder(modelData)
                }
            }
        }
    }
}
