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

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacing.medium

        Repeater {
            model: root.list

            delegate: WallTile {
                id: tile

                required property var modelData
                required property int index

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

                Behavior on width {
                    Anim {}
                }
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
