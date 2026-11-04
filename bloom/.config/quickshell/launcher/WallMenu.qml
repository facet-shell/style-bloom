import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The big wallpaper menu ("wall" on its own): the picked one large with apply, tabs (all,
// still, moving, your folder), a grid, and the options under it (fit, what moving ones do,
// pause in games, colors from the wallpaper). The field keeps the keyboard; the launcher
// sends the arrows here (move), Enter (apply) and Tab (nextTab).
Item {
    id: root

    property Item modes: null
    property string screenName: ""
    property real factor: 1
    property string tab: "all"
    property int current: 0
    // The backend the moving ones come back with after "still frame"
    property string movingBackend: "both"
    // Moved by hand: a list that arrives late no longer jumps to the one in use
    property bool touched: false

    readonly property int columns: 3
    readonly property var tabs: [
        { key: "all", label: "All" },
        { key: "still", label: "Still", icon: "image" },
        { key: "moving", label: "Moving", icon: "play_circle" },
        { key: "folder", label: "Your folder", icon: "folder" }
    ]
    readonly property var list: modes ? modes.wallFilter(Wallpapers.items, tab, "") : []
    readonly property var selected: list.length > 0 ? list[Math.min(current, list.length - 1)] : null
    readonly property string inUse: Wallpapers.current(screenName)
    readonly property bool selectedInUse: selected !== null && selected.path === inUse
    readonly property string folder: `${Quickshell.env("HOME")}/Pictures/wallpapers`

    // Opening: the one in use is picked
    function reset() {
        tab = "all";
        touched = false;
        Qt.callLater(pickInUse);
    }

    function pickInUse() {
        const at = list.findIndex(w => w.path === inUse);
        current = Math.max(0, at);
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    // Left/right one, up/down a row
    function move(step) {
        if (list.length === 0)
            return;
        touched = true;
        current = Math.max(0, Math.min(list.length - 1, current + step));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    function nextTab(step) {
        const at = tabs.findIndex(t => t.key === tab);
        tab = tabs[(at + step + tabs.length) % tabs.length].key;
    }

    // On every screen, or with onlyHere just this one
    function apply(onlyHere) {
        if (!selected)
            return;
        Wallpapers.apply(selected.path, onlyHere ? screenName : "*");
        bounce.restart();
    }

    function kindLabel(w) {
        if (!w)
            return "";
        if (w.source === "file" && w.kind === "image")
            return "your folder";
        return w.kind === "image" ? "still" : `moving · ${w.kind === "scene" ? "engine" : w.kind === "video" ? "mpv" : "web"}`;
    }

    // After the list followed the new tab
    onTabChanged: Qt.callLater(pickInUse)
    onListChanged: {
        if (!touched)
            Qt.callLater(pickInUse);
        else if (current >= list.length)
            current = Math.max(0, list.length - 1);
    }
    onSelectedChanged: pop.restart()

    Connections {
        target: Wallpapers

        function onSettingsChanged() {
            const b = Wallpapers.settings.backend ?? "both";
            if (b !== "image")
                root.movingBackend = b;
        }
    }

    implicitWidth: 1144 * factor
    implicitHeight: layout.implicitHeight

    GridLayout {
        id: layout

        anchors.fill: parent
        columns: 2
        columnSpacing: Theme.spacing.large
        rowSpacing: Theme.spacing.large

        // ── The picked one, large ────────────────────────────

        ClippingRectangle {
            id: preview

            Layout.preferredWidth: 520 * root.factor
            Layout.preferredHeight: 320 * root.factor
            radius: Theme.rounding.drawer
            color: Theme.container

            ParallelAnimation {
                id: pop

                Anim {
                    target: big
                    property: "opacity"
                    from: 0.4
                    to: 1
                }
                Anim {
                    target: preview
                    property: "scale"
                    from: 0.98
                    to: 1
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: big.status !== Image.Ready
                icon: root.selected === null ? "wallpaper" : root.selected.kind === "image" ? "image" : "movie"
                size: Theme.icon.huge
                dim: true
            }

            Image {
                id: big

                anchors.fill: parent
                source: root.modes?.wallPicture(root.selected) ?? ""
                sourceSize.width: 1100
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }

            // What it is, top left
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 14
                visible: root.selected !== null
                implicitWidth: tagRow.implicitWidth + 20
                implicitHeight: Theme.control.chip - 4
                radius: height / 2
                color: Theme.scrim

                Row {
                    id: tagRow

                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: root.selected?.kind === "image" ? (root.selected?.source === "file" ? "folder" : "image") : "play_circle"
                        size: Theme.icon.small - 2
                        color: Theme.onScrim
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kindLabel(root.selected)
                        color: Theme.onScrim
                        font.pixelSize: Theme.size.tiny
                    }
                }
            }

            // Name, details and apply along the bottom
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bottomRow.implicitHeight + 32
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
                    id: bottomRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    spacing: 10

                    StyledText {
                        text: root.selected?.title ?? ""
                        color: Theme.onScrim
                        font.pixelSize: Theme.size.large - 2
                        font.weight: Font.DemiBold
                        Layout.maximumWidth: preview.width * 0.5
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: (root.selected?.tags ?? []).slice(0, 3).join(" · ")
                            || (root.selected?.source === "workshop" ? "Steam Workshop" : "")
                        color: Theme.onScrim
                        opacity: 0.75
                        font.pixelSize: Theme.size.small
                    }
                    Button {
                        id: applyButton

                        visible: root.selected !== null
                        variant: "filled"
                        icon: root.selectedInUse ? "check_circle" : "check"
                        text: root.selectedInUse ? "in use" : "apply"
                        done: root.selectedInUse
                        onClicked: root.apply(false)

                        SequentialAnimation {
                            id: bounce

                            SpringAnim {
                                target: applyButton
                                property: "scale"
                                from: 0.9
                                to: 1
                            }
                        }
                    }
                }
            }
        }

        // ── Tabs and the grid ────────────────────────────────

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacing.medium

            Tabs {
                model: root.tabs
                current: root.tab
                onSelected: key => root.tab = key
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200 * root.factor

                GridView {
                    id: grid

                    anchors.fill: parent
                    // Room for the picked one's ring and the hover lift
                    anchors.margins: -4
                    topMargin: 4
                    bottomMargin: 4
                    leftMargin: 4
                    rightMargin: 4
                    clip: true
                    cellWidth: (width - 8) / root.columns
                    cellHeight: 106 * root.factor
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.list

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        width: grid.cellWidth
                        height: grid.cellHeight

                        WallTile {
                            anchors.fill: parent
                            anchors.margins: 5
                            wall: cell.modelData
                            picture: root.modes?.wallPicture(cell.modelData) ?? ""
                            picked: cell.index === root.current
                            inUse: cell.modelData.path === root.inUse
                            onClicked: {
                                root.touched = true;
                                root.current = cell.index;
                            }
                            onDoubleClicked: {
                                root.touched = true;
                                root.current = cell.index;
                                root.apply(false);
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: root.list.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    dim: true
                    text: !Wallpapers.available ? "frame-wallpaper is not installed (the wallpaper package)"
                        : Wallpapers.loading ? "looking for wallpapers …"
                        : Wallpapers.items.length === 0 ? "no wallpapers yet · put files in ~/Pictures/wallpapers or subscribe in the workshop"
                        : "none in this tab"
                }
            }
        }

        // ── Options ──────────────────────────────────────────

        RowLayout {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            StyledText {
                Layout.leftMargin: 6
                text: "fit"
                dim: true
                font.pixelSize: Theme.size.small
            }
            SegmentedButtons {
                model: [{ key: "fill", label: "fill" }, { key: "fit", label: "fit" }]
                current: Wallpapers.settings.scaling ?? "fill"
                onSelected: key => Wallpapers.option("scaling", key)
            }

            StyledText {
                Layout.leftMargin: 6
                text: "moving ones"
                dim: true
                font.pixelSize: Theme.size.small
            }
            SegmentedButtons {
                model: [{ key: "video", label: "video" }, { key: "still", label: "still frame" }]
                current: (Wallpapers.settings.backend ?? "both") === "image" ? "still" : "video"
                onSelected: key => Wallpapers.setBackend(key === "still" ? "image" : root.movingBackend)
            }

            StyledText {
                Layout.leftMargin: 6
                text: "pause in games"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Switch {
                checked: Wallpapers.settings.pause === true
                onToggled: on => Wallpapers.option("pause", on)
            }

            StyledText {
                Layout.leftMargin: 6
                text: "colors from it"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Switch {
                checked: Config.colorMode === "dynamic"
                onToggled: on => Config.set("colorMode", on ? "dynamic" : "theme")
            }

            Item {
                Layout.fillWidth: true
            }

            // frame-wallpaper reads this folder; there is no list of more folders yet
            Chip {
                icon: "folder_open"
                text: "your folder"
                onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$0" && exec xdg-open "$0"', root.folder])
            }
        }
    }
}
