import QtQuick
import qs.config

// A rounded block on the surface (Theme.container): dashboard tiles, settings groups, the
// lockscreen's media and notes. Its one child (usually a ColumnLayout or RowLayout with
// anchors.fill: parent) sits inside the padding, and the card takes that child's implicit
// size plus the padding.
//
//   Card { ColumnLayout { anchors.fill: parent; … } }
//
//   padding      Theme.padding.card (16)
//   radius       Theme.rounding.large (22)
//   baseColor    Theme.container
//   interactive  hover turns it Theme.high, a press shrinks it a little; signal clicked(mouse)
Rectangle {
    id: root

    property real padding: Theme.padding.card
    property bool interactive: false
    property color baseColor: Theme.container
    default property alias content: inner.data
    readonly property bool hovered: layer.containsMouse
    readonly property Item contentChild: inner.children.length > 0 ? inner.children[0] : null

    signal clicked(var mouse)

    implicitWidth: (contentChild?.implicitWidth ?? 0) + padding * 2
    implicitHeight: (contentChild?.implicitHeight ?? 0) + padding * 2
    radius: Theme.rounding.large
    color: interactive && layer.containsMouse ? Theme.high : baseColor
    scale: interactive && layer.pressed ? 0.98 : 1

    Behavior on color {
        ColorAnim {}
    }
    Behavior on scale {
        SpringAnim {}
    }

    Item {
        id: inner

        anchors.fill: parent
        anchors.margins: root.padding
    }

    // Below the content, so buttons on the card still get their own clicks
    StateLayer {
        id: layer

        z: -1
        disabled: !root.interactive
        opacity: pressed ? 1 : 0
        onClicked: mouse => root.clicked(mouse)
    }
}
