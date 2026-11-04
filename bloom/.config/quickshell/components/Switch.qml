import QtQuick
import qs.config

// The Material switch: a track with a thumb that grows and springs across when it is on.
//
//   Switch { checked: Config.frameHidesInGame; onToggled: on => Config.set("frameHidesInGame", on) }
//
//   checked    its state; the switch does not change it by itself, so a binding to a setting
//              stays intact: handle toggled(on) and write the setting
//   disabled   dimmed, no clicks
//   signal toggled(bool on)
Item {
    id: root

    property bool checked: false
    property bool disabled: false

    signal toggled(bool on)

    implicitWidth: Theme.control.switchWidth
    implicitHeight: Theme.control.switchHeight
    opacity: disabled ? 0.38 : 1

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.high
        border.width: 2
        border.color: root.checked ? Theme.primary : Theme.outline

        Behavior on color {
            ColorAnim {}
        }
        Behavior on border.color {
            ColorAnim {}
        }

        Rectangle {
            id: thumb

            readonly property real side: root.checked || area.pressed ? 24 : 16

            width: area.pressed ? 28 : side
            height: side
            radius: height / 2
            x: root.checked ? parent.width - width - 4 : (area.pressed ? 2 : 6)
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? Theme.textOnPrimary : Theme.outline

            Behavior on x {
                SpringAnim {}
            }
            Behavior on width {
                SpringAnim {}
            }
            Behavior on height {
                SpringAnim {}
            }
            Behavior on color {
                ColorAnim {}
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
