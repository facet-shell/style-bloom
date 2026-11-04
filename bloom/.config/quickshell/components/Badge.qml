import QtQuick
import qs.config

// A small dot for "something new" (the bell, a tray icon that wants attention): Theme.tertiary
// with a ring in the color behind it, so it stands off whatever it sits on.
//
//   shown      pops in and out with a spring
//   size       the dot without the ring (8)
//   color      Theme.tertiary
//   ringColor  the color around it, Theme.container by default
Rectangle {
    id: root

    property bool shown: true
    property real size: 8
    property color ringColor: Theme.container

    width: size + 4
    height: width
    radius: width / 2
    color: Theme.tertiary
    border.width: 2
    border.color: ringColor
    scale: shown ? 1 : 0
    visible: scale > 0.01

    Behavior on scale {
        SpringAnim {}
    }
}
