import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.wallpapers

// Shared wallpaper menu: preview and library or settings beside it.
// The launcher forwards arrow keys, Enter and Tab while its search field has focus.
Item {
    id: root

    property Item modes: null
    property string screenName: ""
    property string targetOutput: "*"
    property real factor: 1
    property string tab: "all"
    property string page: "library"
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
    readonly property string inUse: Wallpapers.current(targetOutput)
    readonly property bool selectedInUse: selected !== null && selected.path === inUse
    readonly property string folder: `${Quickshell.env("HOME")}/Pictures/wallpapers`


    // Opening: the one in use is picked
    function reset() {
        tab = "all";
        page = "library";
        targetOutput = "*";
        touched = false;
        Wallpapers.refresh();
        Qt.callLater(pickInUse);
    }

    function pickInUse() {
        const at = list.findIndex(w => w.path === inUse);
        current = Math.max(0, at);
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    // Left/right one, up/down a row
    function move(step) {
        if (list.length === 0 || (Wallpapers.useGlint && page !== "library"))
            return;
        touched = true;
        current = Math.max(0, Math.min(list.length - 1, current + step));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    function nextTab(step) {
        if (Wallpapers.useGlint) {
            const pages = ["library", "general", "wallpaper"];
            page = pages[(pages.indexOf(page) + step + pages.length) % pages.length];
            return;
        }
        const at = tabs.findIndex(t => t.key === tab);
        tab = tabs[(at + step + tabs.length) % tabs.length].key;
    }

    // On every screen, or with onlyHere just this one
    function apply(onlyHere) {
        if (!selected)
            return;
        Wallpapers.apply(selected.path, onlyHere ? screenName : targetOutput);
        bounce.restart();
    }

    function kindLabel(w) {
        if (!w)
            return "";
        if (w.source === "file" && w.kind === "image")
            return "your folder";
        return w.kind === "image" ? "still" : `moving · ${w.kind === "scene" ? "engine" : w.kind === "video" ? "video" : "web"}`;
    }

    // After the list followed the new tab
    onInUseChanged: {
        touched = false;
        Qt.callLater(pickInUse);
    }
    onTargetOutputChanged: Qt.callLater(pickInUse)
    onTabChanged: Qt.callLater(pickInUse)
    onListChanged: {
        if (!touched)
            Qt.callLater(pickInUse);
        else if (current >= list.length)
            current = Math.max(0, list.length - 1);
    }
    onSelectedChanged: pop.restart()

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
                        color: Theme.textOnScrim
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kindLabel(root.selected)
                        color: Theme.textOnScrim
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
                        color: Theme.textOnScrim
                        font.pixelSize: Theme.size.large - 2
                        font.weight: Font.DemiBold
                        Layout.maximumWidth: preview.width * 0.5
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: (root.selected?.tags ?? []).slice(0, 3).join(" · ")
                            || (root.selected?.source === "workshop" ? "Steam Workshop" : "")
                        color: Theme.textOnScrim
                        opacity: 0.75
                        font.pixelSize: Theme.size.small
                    }
                    // Its own options (the "This wallpaper" page)
                    IconButton {
                        visible: Wallpapers.useGlint && root.selected !== null
                        icon: "tune"
                        restColor: Theme.scrim
                        iconColor: Theme.textOnScrim
                        active: root.page === "wallpaper"
                        onClicked: root.page = root.page === "wallpaper" ? "library" : "wallpaper"
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
                visible: Wallpapers.useGlint
                model: [
                    { key: "library", label: "Library", icon: "grid_view" },
                    { key: "general", label: "Engine", icon: "settings" },
                    { key: "wallpaper", label: "This wallpaper", icon: "tune" }
                ]
                current: root.page
                onSelected: key => root.page = key
            }

            // The library's filter, and what can be done with the library itself
            RowLayout {
                Layout.fillWidth: true
                visible: !Wallpapers.useGlint || root.page === "library"
                spacing: Theme.spacing.small

                SegmentedButtons {
                    model: root.tabs
                    current: root.tab
                    onSelected: key => root.tab = key
                }
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    visible: Wallpapers.useGlint
                    icon: "refresh"
                    tonal: true
                    disabled: Wallpapers.loading
                    onClicked: Wallpapers.refresh()
                }
                Button {
                    visible: Wallpapers.useGlint
                    compact: true
                    variant: "tonal"
                    icon: "open_in_new"
                    text: "Workshop"
                    onClicked: Quickshell.execDetached(["xdg-open", "steam://openurl/https://steamcommunity.com/app/431960/workshop/"])
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200 * root.factor

                GridView {
                    id: grid
                    visible: !Wallpapers.useGlint || root.page === "library"

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

                Flickable {
                    anchors.fill: parent
                    visible: Wallpapers.useGlint && root.page !== "library"
                    contentHeight: settingsPanel.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    GlintSettings {
                        id: settingsPanel
                        width: parent.width
                        section: root.page
                        output: root.targetOutput
                        projectPath: root.selected?.path ?? ""
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: root.list.length === 0 && (!Wallpapers.useGlint || root.page === "library")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    dim: true
                    text: !Wallpapers.available ? (Wallpapers.useGlint ? "Glint is not connected · start it below" : "facet-wallpaper is not installed (the wallpaper package)")
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
            visible: !Wallpapers.useGlint

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

            // facet-wallpaper reads this folder; there is no list of more folders yet
            Chip {
                icon: "folder_open"
                text: "your folder"
                onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$0" && exec xdg-open "$0"', root.folder])
            }
        }

        // Which displays apply and the settings go to
        RowLayout {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            visible: Wallpapers.useGlint && Wallpapers.glintOutputs.length > 0
            spacing: Theme.spacing.medium

            Icon {
                icon: "desktop_windows"
                dim: true
                size: Theme.icon.small
            }
            StyledText {
                text: "show on"
                dim: true
                font.pixelSize: Theme.size.small
            }
            SegmentedButtons {
                model: [{ key: "*", label: "all displays" }].concat(Wallpapers.glintOutputs.map(output => ({ key: output.name, label: output.name })))
                current: root.targetOutput
                onSelected: key => root.targetOutput = key
            }
            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            visible: Wallpapers.useGlint && !Wallpapers.glintActive
            StyledText { Layout.fillWidth: true; text: Wallpapers.glintError || "Glint is not connected"; dim: true }
            Button { text: "start engine"; icon: "play_arrow"; onClicked: Wallpapers.startGlint() }
        }
    }
}
