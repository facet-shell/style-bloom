import QtQuick
import qs.config

// The hover and press wash of anything clickable, and its mouse handling. Put it as the last
// child of the thing (a Rectangle); it fills it and takes its corner radius.
//
//   StateLayer { onClicked: mouse => … }
//
//   color       the wash, Theme.text by default (Theme.textOnPrimary on a primary fill …)
//   radius      follows the parent's radius
//   disabled    no wash, no clicks
//   cursorShape PointingHandCursor by default
// It is a MouseArea: acceptedButtons, onClicked, onPressAndHold, onWheel … all work, and
// containsMouse / pressed tell the parent its state (for "on" colors or a pressed scale).
MouseArea {
    id: root

    property color color: Theme.text
    property real radius: parent?.radius ?? 0
    property bool disabled: false

    anchors.fill: parent
    enabled: !disabled
    hoverEnabled: true
    cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.color
        opacity: root.disabled ? 0 : root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0

        Behavior on opacity {
            Anim {
                duration: Theme.anim.small
            }
        }
    }
}
