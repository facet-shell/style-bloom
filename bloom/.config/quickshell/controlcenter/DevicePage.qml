import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// The frame of a tile's page in the control center (Android's quick settings, macOS's
// control center): a header with the way back, the title with a status line under it and
// room on the right for the tile's switch, then the rows (the page's children) in a list
// that scrolls past maxHeight. WifiPage, BluetoothPage and AudioDevicePage fill it.
//
//   DevicePage {
//       title: "Wi-Fi"; subtitle: "connected"
//       control: Switch { … }
//       onBack: …
//       SettingRow { … }
//   }
ColumnLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property real maxHeight: 420
    property alias control: controlSlot.data
    default property alias rows: list.data

    signal back()

    spacing: Theme.spacing.medium

    // ── Header ───────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.normal

        IconButton {
            icon: "arrow_back"
            onClicked: root.back()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.size.medium
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                dim: true
                font.pixelSize: Theme.size.tiny
            }
        }

        Item {
            id: controlSlot

            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
    }

    // ── Rows ─────────────────────────────────────────────────

    // Scrolls past maxHeight with a thin scroll line, like the mixer's lists
    Item {
        Layout.fillWidth: true
        implicitHeight: Math.min(list.implicitHeight, root.maxHeight)

        Flickable {
            id: flick

            anchors.fill: parent
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list

                width: flick.width - (flick.contentHeight > flick.height ? 10 : 0)
                spacing: Theme.spacing.small
            }
        }

        Rectangle {
            visible: flick.contentHeight > flick.height
            anchors.right: parent.right
            width: 4
            radius: width / 2
            y: flick.visibleArea.yPosition * flick.height
            height: flick.visibleArea.heightRatio * flick.height
            color: Theme.outline
        }
    }
}
