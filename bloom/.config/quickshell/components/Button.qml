import QtQuick
import QtQuick.Layouts
import qs.config

// A pill button with text and an optional icon in front.
//
//   Button { text: "apply"; icon: "check"; variant: "filled"; onClicked: … }
//
//   variant   "filled" (Theme.primary), "tonal" (secondaryContainer), "plain" (Theme.high,
//             like the notification actions), "text" (no background), "ok" (answer a call),
//             "danger" (decline, delete)
//   compact   30 high with smaller text (in-game pills, dense rows)
//   done      morphs into a soft square, as "applied" feedback
//   disabled
//   signal clicked(mouse); a press shrinks it with a spring
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "plain"
    property bool compact: false
    property bool done: false
    property bool disabled: false
    readonly property bool hovered: layer.containsMouse

    readonly property color foreground: variant === "filled" ? Theme.textOnPrimary
        : variant === "ok" ? Theme.textOnOk
        : variant === "danger" ? Theme.textOnErrorContainer
        : variant === "text" ? Theme.primary
        : Theme.text

    signal clicked(var mouse)

    implicitHeight: compact ? 30 : 36
    implicitWidth: row.implicitWidth + (compact ? 20 : 28)
    radius: done ? Theme.rounding.normal : height / 2
    color: variant === "filled" ? Theme.primary
        : variant === "tonal" ? Theme.secondaryContainer
        : variant === "ok" ? Theme.ok
        : variant === "danger" ? Theme.errorContainer
        : variant === "text" ? "transparent"
        : Theme.high
    opacity: disabled ? 0.38 : 1
    scale: layer.pressed ? 0.93 : 1

    Behavior on scale {
        SpringAnim {}
    }
    Behavior on radius {
        SpringAnim {}
    }
    Behavior on color {
        ColorAnim {}
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            size: root.compact ? 16 : 18
            color: root.foreground
        }
        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.foreground
            font.pixelSize: root.compact ? Theme.size.tiny : Theme.size.small + 1
            font.weight: Font.Medium
        }
    }

    StateLayer {
        id: layer

        color: root.foreground
        disabled: root.disabled
        onClicked: mouse => root.clicked(mouse)
    }
}
