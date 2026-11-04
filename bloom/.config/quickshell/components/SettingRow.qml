import QtQuick
import QtQuick.Layouts
import qs.config

// One row of a settings list (the mockup's .srow): a title, a dim line under it, and the
// control on the right (a Switch, SegmentedButtons, a Chip …) as the row's child.
//
//   SettingRow { title: "Compact in a game"; subtitle: "a see-through pill, one line, no frame"
//                Switch { checked: …; onToggled: … } }
//
//   title, subtitle ("" hides it), icon (in front, optional)
//   baseColor   Theme.container
//   interactive the whole row is clickable (signal clicked(mouse)), e.g. to open a page
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool interactive: false
    property color baseColor: Theme.container
    default property alias control: slot.data

    signal clicked(var mouse)

    implicitWidth: 480
    implicitHeight: Math.max(56, row.implicitHeight + 24)
    radius: Theme.rounding.medium
    color: interactive && layer.containsMouse ? Theme.high : baseColor

    Behavior on color {
        ColorAnim {}
    }

    StateLayer {
        id: layer

        z: -1
        disabled: !root.interactive
        opacity: pressed ? 1 : 0
        onClicked: mouse => root.clicked(mouse)
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 14

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            dim: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                dim: true
                font.pixelSize: Theme.size.small
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        Item {
            id: slot

            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
    }
}
