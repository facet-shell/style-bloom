import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The wallpaper menu: search on top, the picked wallpaper large on the left with "apply",
// tabs and round tiles on the right, the backend's options underneath. A click picks a tile,
// a double click, Enter or "apply" puts it on; Up/Down move a row, Tab one on, Esc closes.
ColumnLayout {
    id: root

    signal closeRequested()

    property string query: ""
    // all | still | moving | folder (own files, not the workshop)
    property string tab: "all"
    // Screen the wallpaper goes on, "*" = all screens
    property string target: "*"
    property int current: 0
    // Picked by hand since opening: the list arriving late must not move the pick away
    property bool touched: false

    readonly property int columns: 3
    readonly property bool stillOnly: Wallpapers.settings.backend === "image"
    readonly property var shown: filter(Wallpapers.items, query, tab)
    readonly property var picked: shown[current] ?? null
    readonly property string active: Wallpapers.current(target)
    readonly property string folder: `${Quickshell.env("HOME")}/Pictures/wallpapers`

    readonly property var backendHints: ({
        both: "workshop scenes and videos through linux-wallpaperengine, files through mpvpaper and swaybg",
        mpv: "only files from ~/Pictures/wallpapers and assets/wallpapers, videos through mpvpaper",
        image: "still pictures only, through swaybg · the least power"
    })

    spacing: Theme.spacing.medium

    function reset() {
        search.text = "";
        target = "*";
        tab = "all";
        touched = false;
        fpsSlider.pending = Wallpapers.settings.fps ?? 30;
        volumeSlider.pending = Wallpapers.settings.volume ?? 0;
        Wallpapers.refresh();
        pickActive();
        search.focusField();
    }

    function filter(items, query, tab) {
        const q = query.trim().toLowerCase();
        return items.filter(w => {
            if (tab === "still" && w.kind !== "image")
                return false;
            if (tab === "moving" && w.kind === "image")
                return false;
            if (tab === "folder" && w.source !== "file")
                return false;
            return q === "" || `${w.title} ${(w.tags ?? []).join(" ")}`.toLowerCase().includes(q);
        });
    }

    function fileUrl(path) {
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    // The one on screen now, so opening shows what is there
    function pickActive() {
        current = Math.max(0, shown.findIndex(w => w.path === active));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    function move(step) {
        if (shown.length === 0)
            return;
        touched = true;
        current = Math.max(0, Math.min(shown.length - 1, current + step));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    function applyCurrent() {
        if (picked)
            Wallpapers.apply(picked.path, target);
    }

    onTabChanged: current = 0
    onStillOnlyChanged: if (stillOnly && tab === "moving") tab = "all"

    Connections {
        target: Wallpapers

        function onItemsChanged() {
            if (!root.touched)
                root.pickActive();
        }

        // The sliders follow the saved state unless a change still waits to be saved
        function onSettingsChanged() {
            if (!fpsSave.running)
                fpsSlider.pending = Wallpapers.settings.fps ?? 30;
            if (!volumeSave.running)
                volumeSlider.pending = Wallpapers.settings.volume ?? 0;
        }
    }

    // Sliders save once they stop moving; every save restarts the backend
    Timer {
        id: fpsSave
        interval: 600
        onTriggered: Wallpapers.option("fps", fpsSlider.pending)
    }

    Timer {
        id: volumeSave
        interval: 600
        onTriggered: Wallpapers.option("volume", volumeSlider.pending)
    }

    // ── Building blocks ──────────────────────────────────────

    // A dim label in front of a control in the options row
    component OptionLabel: StyledText {
        dim: true
        font.pixelSize: Theme.size.small
        Layout.leftMargin: Theme.spacing.small
    }

    // ── Search and screens ───────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.normal

        SearchField {
            id: search

            Layout.fillWidth: true
            icon: "wallpaper"
            placeholder: "Search title or tags"
            hint: Wallpapers.loading ? "looking…" : `${root.shown.length} wallpapers`
            onTextChanged: {
                root.query = text;
                root.current = 0;
            }
            onAccepted: root.applyCurrent()
            onEscaped: root.closeRequested()
            onNavigated: key => {
                if (key === Qt.Key_Down)
                    root.move(root.columns);
                else if (key === Qt.Key_Up)
                    root.move(-root.columns);
                else
                    root.move(1);
            }
        }

        // Which screen it goes on, only with more than one
        Repeater {
            model: Quickshell.screens.length > 1 ? ["*"].concat(Quickshell.screens.map(s => s.name)) : []

            Chip {
                required property string modelData

                text: modelData === "*" ? "all screens" : modelData
                icon: modelData === "*" ? "desktop_windows" : "monitor"
                selected: root.target === modelData
                onClicked: root.target = modelData
            }
        }
    }

    // ── Preview and tiles ────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 320
        spacing: Theme.spacing.large

        // The picked one, large
        ClippingRectangle {
            Layout.preferredWidth: Math.min(520, root.width * 0.46)
            Layout.fillHeight: true
            radius: Theme.rounding.hole
            color: Theme.container

            Image {
                id: big

                anchors.fill: parent
                source: root.fileUrl(root.picked?.preview ?? "")
                sourceSize: Qt.size(1040, 640)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: big.status !== Image.Ready
                spacing: Theme.spacing.normal

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: root.picked ? (root.picked.kind === "image" ? "image" : "play_circle") : "wallpaper"
                    size: Theme.icon.huge
                    dim: true
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 380
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    dim: true
                    font.pixelSize: Theme.size.small
                    text: !Wallpapers.available ? "The wallpaper package is not installed · run: facet install wallpaper"
                        : Wallpapers.loading && Wallpapers.items.length === 0 ? "Looking for wallpapers…"
                        : Wallpapers.items.length === 0 ? "No wallpapers yet · put files in ~/Pictures/wallpapers or subscribe in the workshop"
                        : root.shown.length === 0 ? "Nothing matches"
                        : "No preview"
                }
            }

            // Its kind, top left
            ScrimPill {
                x: Theme.padding.normal + 2
                y: Theme.padding.normal + 2
                visible: root.picked !== null
                implicitHeight: 30
                spacing: 6

                Icon {
                    icon: root.picked?.kind === "image" ? "image" : root.picked?.kind === "scene" ? "auto_awesome" : "movie"
                    size: 16
                    color: Theme.textOnScrim
                }
                StyledText {
                    text: root.picked ? `${root.picked.kind} · ${root.picked.source}` : ""
                    color: Theme.textOnScrim
                    font.pixelSize: Theme.size.tiny
                }
            }

            // Name, tags and apply over a shade at the bottom
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: root.picked !== null
                height: 92
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Theme.scrim
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.padding.card
                    anchors.topMargin: 30
                    spacing: Theme.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.picked?.title ?? ""
                            color: Theme.textOnScrim
                            font.pixelSize: Theme.size.large - 2
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: (root.picked?.tags ?? []).join(" · ")
                            color: Theme.textOnScrim
                            opacity: 0.75
                            font.pixelSize: Theme.size.small
                        }
                    }

                    Button {
                        readonly property bool isOn: root.picked !== null && root.picked.path === root.active

                        text: isOn ? "on now" : "apply"
                        icon: "check"
                        variant: "filled"
                        done: isOn
                        disabled: root.picked === null
                        onClicked: root.applyCurrent()
                    }
                }
            }
        }

        // Tabs and the grid
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing.medium

            Tabs {
                model: [{ key: "all", label: "All" }, { key: "still", label: "Still", icon: "image" }]
                    .concat(root.stillOnly ? [] : [{ key: "moving", label: "Moving", icon: "play_circle" }])
                    .concat([{ key: "folder", label: "Your folder", icon: "folder" }])
                current: root.tab
                onSelected: key => root.tab = key
            }

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / root.columns)
                cellHeight: 106
                model: root.shown
                boundsBehavior: Flickable.StopAtBounds
                // Room for the lifted tile and its ring at the top row
                topMargin: 4

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.current
                    readonly property bool inUse: modelData.path === root.active

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Item {
                        anchors.fill: parent
                        anchors.margins: 5

                        // Lifts a little under the mouse
                        transform: Translate {
                            y: area.containsMouse ? -3 : 0

                            Behavior on y {
                                SpringAnim {}
                            }
                        }

                        // The picked one's ring; it grows rounder with the tile
                        Rectangle {
                            anchors.fill: thumb
                            anchors.margins: -3
                            radius: thumb.radius + 3
                            color: "transparent"
                            border.width: 3
                            border.color: Theme.primary
                            opacity: tile.selected ? 1 : 0

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.anim.small
                                }
                            }
                        }

                        ClippingRectangle {
                            id: thumb

                            anchors.fill: parent
                            radius: tile.selected ? Theme.rounding.hole : Theme.rounding.medium
                            color: Theme.high

                            Behavior on radius {
                                SpringAnim {}
                            }

                            Image {
                                anchors.fill: parent
                                source: root.fileUrl(tile.modelData.preview ?? "")
                                sourceSize: Qt.size(360, 200)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 40
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Theme.scrim
                                    }
                                }
                            }

                            StyledText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: Theme.padding.small + 2
                                text: tile.modelData.title
                                color: Theme.textOnScrim
                                font.pixelSize: Theme.size.small
                                font.weight: Font.Medium
                            }

                            // Moving ones carry a play mark
                            Icon {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.padding.small
                                visible: tile.modelData.kind !== "image"
                                icon: "play_circle"
                                size: Theme.icon.small
                                color: Theme.textOnScrim
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: Theme.padding.small
                                visible: tile.inUse
                                implicitWidth: useText.implicitWidth + 16
                                implicitHeight: 20
                                radius: height / 2
                                color: Theme.primary

                                StyledText {
                                    id: useText

                                    anchors.centerIn: parent
                                    text: "in use"
                                    color: Theme.textOnPrimary
                                    font.pixelSize: Theme.size.tiny - 1
                                }
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.touched = true;
                                root.current = tile.index;
                                search.focusField();
                            }
                            onDoubleClicked: {
                                root.current = tile.index;
                                root.applyCurrent();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Options ──────────────────────────────────────────────

    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        RowLayout {
            spacing: Theme.spacing.normal

            OptionLabel {
                text: "fit"
            }
            SegmentedButtons {
                model: [{ key: "fill", label: "fill" }, { key: "fit", label: "fit" }]
                current: Wallpapers.settings.scaling ?? "fill"
                onSelected: key => Wallpapers.option("scaling", key)
            }
        }

        RowLayout {
            spacing: Theme.spacing.normal

            OptionLabel {
                text: "engine"
            }
            SegmentedButtons {
                model: [{ key: "both", label: "engine + mpv" }, { key: "mpv", label: "mpvpaper" }, { key: "image", label: "still only" }]
                current: Wallpapers.settings.backend ?? "both"
                onSelected: key => Wallpapers.setBackend(key)
            }
        }

        // Still pictures do not move, so fps and sound mean nothing there
        RowLayout {
            spacing: Theme.spacing.normal
            enabled: !root.stillOnly
            opacity: enabled ? 1 : 0.38

            OptionLabel {
                text: "fps"
            }
            Slider {
                id: fpsSlider

                // 15 to 144
                property int pending: 30

                implicitWidth: 110
                thin: true
                value: (pending - 15) / (144 - 15)
                onMoved: v => {
                    pending = Math.round(15 + v * (144 - 15));
                    fpsSave.restart();
                }
            }
            StyledText {
                text: String(fpsSlider.pending)
                tabular: true
                font.pixelSize: Theme.size.small
                Layout.preferredWidth: 28
            }

            OptionLabel {
                text: "sound"
            }
            Slider {
                id: volumeSlider

                property int pending: 0

                implicitWidth: 110
                thin: true
                value: pending / 100
                onMoved: v => {
                    pending = Math.round(v * 100);
                    volumeSave.restart();
                }
            }
            StyledText {
                text: volumeSlider.pending === 0 ? "muted" : `${volumeSlider.pending}%`
                tabular: true
                font.pixelSize: Theme.size.small
                Layout.preferredWidth: 44
            }
        }

        RowLayout {
            spacing: Theme.spacing.normal

            OptionLabel {
                text: "pause in fullscreen"
            }
            Switch {
                checked: Wallpapers.settings.pause === true
                onToggled: on => Wallpapers.option("pause", on)
            }

            // The bloom tones from the wallpaper (Theme.dynamic once a generator writes them)
            OptionLabel {
                text: "colors from it"
            }
            Switch {
                checked: Config.colorMode === "dynamic"
                onToggled: on => Config.set("colorMode", on ? "dynamic" : "theme")
            }
        }

        Chip {
            text: "your folder"
            icon: "folder_open"
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "frame-wallpaper", root.folder])
        }
    }

    StyledText {
        Layout.fillWidth: true
        dim: true
        font.pixelSize: Theme.size.tiny
        text: `${root.backendHints[Wallpapers.settings.backend] ?? ""} · ↑↓ move · tab next · enter apply · esc close`
    }
}
