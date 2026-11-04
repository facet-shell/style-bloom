import QtQuick
import qs.config

// A row of choices with a pill that slides to the picked one: the dashboard's and control
// center's tabs ("tabs"), and the settings' segmented buttons ("segmented", see
// SegmentedButtons).
//
//   Tabs { model: [{ key: "home", label: "Dashboard", icon: "dashboard" }, …]
//          current: "home"; onSelected: key => current = key }
//
//   model     entries { key, label, icon } (icon optional); plain strings work too (the
//             string is key and label)
//   current   the picked key; set it from selected(key), Tabs never changes it itself
//   variant   "tabs": Theme.container behind, 4 px around, bigger text; "segmented":
//             Theme.high behind, 3 px around, smaller
//   signal selected(var key)
Rectangle {
    id: root

    property var model: []
    property var current: ""
    property string variant: "tabs"
    readonly property bool segmented: variant === "segmented"
    readonly property var entries: (model ?? []).map(e => typeof e === "object" ? e : { key: e, label: String(e) })
    readonly property int currentIndex: entries.findIndex(e => e.key === current)
    readonly property Item currentItem: repeater.count > 0 && currentIndex >= 0 ? repeater.itemAt(currentIndex) : null

    signal selected(var key)

    implicitWidth: row.implicitWidth + inset * 2
    implicitHeight: row.implicitHeight + inset * 2
    readonly property real inset: segmented ? 3 : 4
    radius: height / 2
    color: segmented ? Theme.high : Theme.container

    Behavior on color {
        ColorAnim {}
    }

    // The pill under the picked entry
    Rectangle {
        visible: root.currentItem !== null
        x: root.inset + (root.currentItem?.x ?? 0)
        y: root.inset
        width: root.currentItem?.width ?? 0
        height: row.height
        radius: height / 2
        color: Theme.primaryContainer

        Behavior on x {
            Anim {}
        }
        Behavior on width {
            Anim {}
        }
    }

    Row {
        id: row

        x: root.inset
        y: root.inset
        spacing: root.segmented ? 0 : 6

        Repeater {
            id: repeater

            model: root.entries

            delegate: Item {
                id: entry

                required property var modelData
                required property int index
                readonly property bool picked: index === root.currentIndex
                readonly property color foreground: picked ? Theme.textOnPrimaryContainer : area.containsMouse ? Theme.text : Theme.dim

                implicitWidth: content.implicitWidth + (root.segmented ? 24 : 32)
                implicitHeight: root.segmented ? 28 : 34
                width: implicitWidth
                height: implicitHeight

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        visible: !!entry.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        icon: entry.modelData.icon ?? ""
                        size: Theme.icon.small
                        color: entry.foreground
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label ?? ""
                        color: entry.foreground
                        font.pixelSize: root.segmented ? Theme.size.small : Theme.size.small + 1
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(entry.modelData.key)
                }
            }
        }
    }
}
