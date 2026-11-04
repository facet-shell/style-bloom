import QtQuick
import qs.components
import qs.config
import qs.services

// "wall <word>": a quick row of the wallpapers that match, the picked one wider. A click or
// Enter puts it on every screen (Shift+Enter: only this one).
Item {
    id: root

    property Item modes: null
    property string word: ""
    property string screenName: ""
    property real factor: 1
    property int current: 0

    readonly property var list: modes ? modes.wallFilter(Wallpapers.items, "all", word).slice(0, 6) : []
    readonly property var selected: list.length > 0 ? list[Math.min(current, list.length - 1)] : null
    readonly property string inUse: Wallpapers.current(screenName)

    function move(step) {
        if (list.length > 0)
            current = Math.max(0, Math.min(list.length - 1, current + step));
    }

    function apply(onlyHere) {
        if (selected)
            Wallpapers.apply(selected.path, onlyHere ? screenName : "*");
    }

    onWordChanged: current = 0

    implicitHeight: 160 * factor

    // A list, not a centred Row: six matches are wider than the launcher, and a Row ran out
    // past both rounded sides with the picked first one half outside. Centred while it fits,
    // otherwise it scrolls so the picked one is whole (also while it widens).
    ListView {
        id: row

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Theme.spacing.medium
        clip: true
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        leftMargin: Math.max(0, (width - contentWidth) / 2)
        model: root.list
        currentIndex: root.current
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: WallTile {
            id: tile

            required property var modelData
            required property int index

            y: (row.height - height) / 2
            width: (picked ? 210 : 120) * root.factor
            height: 150 * root.factor
            wall: modelData
            picture: root.modes?.wallPicture(modelData) ?? ""
            picked: index === root.current
            inUse: modelData.path === root.inUse
            restRadius: Theme.rounding.large
            onClicked: {
                root.current = index;
                root.apply(false);
            }
            onWidthChanged: if (picked)
                row.positionViewAtIndex(index, ListView.Contain)

            Behavior on width {
                Anim {}
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.list.length === 0
        dim: true
        text: !Wallpapers.available ? "frame-wallpaper is not installed (the wallpaper package)"
            : Wallpapers.loading ? "looking for wallpapers …"
            : `no wallpaper matches “${root.word}” · wall alone shows all`
    }
}
