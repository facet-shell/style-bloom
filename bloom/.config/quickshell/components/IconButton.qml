import QtQuick
import qs.config

// A round button with one icon: bar buttons, media controls, close buttons.
//
//   IconButton { icon: "search"; onClicked: … }
//
//   icon        Material Symbols name
//   size        the button (Theme.control.iconButton, 36); iconSize (Theme.icon.normal)
//   active      drawn "on": Theme.high behind it, the icon in Theme.text
//   filled      the main action (play): Theme.primary with the icon in textOnPrimary; it rounds
//               into a soft square while `active` (the mockup's play/pause)
//   tonal       Theme.secondaryContainer behind it
//   restColor   behind it at rest ("transparent"; Theme.high for media buttons on a card)
//   iconColor   the icon (Theme.dim at rest, Theme.text hovered or active, textOnPrimary filled)
//   badge       a dot top right (Badge); badgeRing its ring color
//   disabled    dimmed, no clicks
//   signal clicked(mouse); acceptedButtons; a press shrinks it with a spring
Item {
    id: root

    property string icon: ""
    property real size: Theme.control.iconButton
    property real iconSize: Theme.icon.normal
    property bool active: false
    property bool filled: false
    property bool tonal: false
    property color restColor: "transparent"
    property color iconColor: filled ? Theme.textOnPrimary : active || layer.containsMouse ? Theme.text : Theme.dim
    property bool badge: false
    property color badgeRing: Theme.surface
    property bool disabled: false
    property alias acceptedButtons: layer.acceptedButtons
    readonly property bool hovered: layer.containsMouse
    readonly property bool pressed: layer.pressed

    signal clicked(var mouse)

    implicitWidth: size
    implicitHeight: size
    opacity: disabled ? 0.38 : 1

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: root.filled && root.active ? Theme.rounding.normal : height / 2
        color: root.filled ? Theme.primary
            : root.tonal ? Theme.secondaryContainer
            : root.active || layer.containsMouse ? Theme.high
            : root.restColor
        scale: layer.pressed ? 0.86 : 1

        Behavior on radius {
            SpringAnim {}
        }
        Behavior on scale {
            SpringAnim {}
        }
        Behavior on color {
            ColorAnim {}
        }

        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: root.iconSize
            color: root.iconColor
        }

        StateLayer {
            id: layer

            color: root.filled ? Theme.textOnPrimary : Theme.text
            disabled: root.disabled
            onClicked: mouse => root.clicked(mouse)
        }
    }

    Badge {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.size * 0.1
        anchors.topMargin: root.size * 0.1
        shown: root.badge
        ringColor: root.badgeRing
    }
}
