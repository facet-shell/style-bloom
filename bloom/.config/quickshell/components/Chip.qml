import QtQuick
import QtQuick.Layouts
import qs.config

// A small rounded label that can be picked: filters, the mixer's channel, entries of a list
// (the game list), "update now".
//
//   Chip { text: "Gaming"; selected: true }
//
//   text, icon (in front)
//   selected   Theme.secondaryContainer with Theme.text; otherwise Theme.high with Theme.dim
//   closable   a close icon at the end; signal closeClicked()
//   compact    24 high with smaller text (inside list rows)
//   signal clicked(mouse); a press bounces it
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool closable: false
    property bool compact: false
    readonly property color foreground: selected ? Theme.text : Theme.dim

    signal clicked(var mouse)
    signal closeClicked()

    implicitHeight: compact ? 24 : Theme.control.chip
    implicitWidth: row.implicitWidth + (compact ? 20 : 24)
    radius: height / 2
    color: selected ? Theme.secondaryContainer : layer.containsMouse ? Theme.highest : Theme.high
    scale: layer.pressed ? 0.92 : 1

    Behavior on color {
        ColorAnim {}
    }
    Behavior on scale {
        SpringAnim {}
    }

    StateLayer {
        id: layer

        opacity: pressed ? 1 : 0
        onClicked: mouse => root.clicked(mouse)
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            size: root.compact ? 15 : Theme.icon.small
            color: root.foreground
        }
        StyledText {
            text: root.text
            color: root.foreground
            font.pixelSize: root.compact ? Theme.size.tiny : Theme.size.small
        }
        Icon {
            visible: root.closable
            icon: "close"
            size: root.compact ? 14 : 16
            color: root.foreground

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }
}
