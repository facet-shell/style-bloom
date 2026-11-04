import QtQuick
import QtQuick.Layouts
import qs.config

// The menu look (the tray's right-click menus, the power menu, any pick list): a dim header,
// rows with an icon and text, lines between groups, red rows for quitting. Only the list:
// put it into a Drawer (BarMenu does) or a Card.
//
//   Menu { title: "Steam"; entries: [{ text: "Library", icon: "grid_view" },
//          { separator: true }, { text: "Exit Steam", icon: "power_settings_new", danger: true }]
//          onActivated: (index, entry) => … }
//
//   entries   { text, icon (a Material Symbols name), image (a picture instead, tray icons),
//             danger, separator, enabled (true), checked (true/false; leave it out for none),
//             more (opens a submenu: shows a chevron), back (a "back" row: shows an arrow) }
//   title     the header ("" for none)
//   signal activated(int index, var entry): a row was clicked (separators and disabled
//          rows never are)
ColumnLayout {
    id: root

    property var entries: []
    property string title: ""

    signal activated(int index, var entry)

    spacing: 2

    StyledText {
        visible: root.title !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 6
        Layout.bottomMargin: 4
        text: root.title
        dim: true
        font.pixelSize: Theme.size.tiny
    }

    Repeater {
        model: root.entries

        delegate: Item {
            id: row

            required property var modelData
            required property int index
            readonly property bool separator: modelData.separator === true
            readonly property bool usable: !separator && modelData.enabled !== false
            readonly property color foreground: modelData.danger ? Theme.error : Theme.text

            Layout.fillWidth: true
            implicitWidth: separator ? 0 : line.implicitWidth + 24
            implicitHeight: separator ? 9 : 38

            Rectangle {
                visible: row.separator
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 1
                color: Theme.outline
            }

            Rectangle {
                visible: !row.separator
                anchors.fill: parent
                radius: Theme.rounding.normal
                color: area.containsMouse && row.usable ? Theme.highest : "transparent"
                opacity: row.usable ? 1 : 0.45

                Behavior on color {
                    ColorAnim {}
                }

                RowLayout {
                    id: line

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Icon {
                        visible: row.modelData.back === true || (row.modelData.icon ?? "") !== ""
                        icon: row.modelData.back === true ? "arrow_back" : row.modelData.icon ?? ""
                        size: Theme.icon.small
                        color: row.modelData.danger ? Theme.error : Theme.dim
                    }
                    Image {
                        visible: (row.modelData.image ?? "") !== "" && !row.modelData.icon
                        source: row.modelData.image ?? ""
                        sourceSize: Qt.size(36, 36)
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        asynchronous: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.text ?? ""
                        color: row.foreground
                        font.pixelSize: Theme.size.small + 1
                    }
                    Icon {
                        visible: row.modelData.checked === true || row.modelData.checked === false
                        icon: row.modelData.checked === true ? "check_box" : "check_box_outline_blank"
                        size: Theme.icon.small
                        color: row.modelData.checked === true ? Theme.primary : Theme.dim
                    }
                    Icon {
                        visible: row.modelData.more === true
                        icon: "chevron_right"
                        size: Theme.icon.small
                        dim: true
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(row.index, row.modelData)
                }
            }
        }
    }
}
