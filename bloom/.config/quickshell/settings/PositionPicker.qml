import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Where a popup sits (Config positions): six arrows laid out like the screen they stand for,
// the picked one in primaryContainer. The subtitle says the spot in words.
ConfigRow {
    id: place

    readonly property var spots: [
        ["top-left", "north_west"], ["top", "north"], ["top-right", "north_east"],
        ["bottom-left", "south_west"], ["bottom", "south"], ["bottom-right", "south_east"]
    ]

    title: "Where"
    subtitle: String(Config[key] ?? "").replace("-", " ")

    Rectangle {
        implicitWidth: grid.implicitWidth + Theme.spacing.small * 2
        implicitHeight: grid.implicitHeight + Theme.spacing.small * 2
        radius: Theme.rounding.normal
        color: Theme.high

        GridLayout {
            id: grid

            anchors.centerIn: parent
            columns: 3
            columnSpacing: Theme.spacing.tiny
            rowSpacing: Theme.spacing.tiny

            Repeater {
                model: place.spots

                delegate: Rectangle {
                    id: spot

                    required property var modelData
                    readonly property bool picked: Config[place.key] === modelData[0]

                    implicitWidth: Theme.control.iconButton + Theme.spacing.small
                    implicitHeight: Theme.control.chip - Theme.spacing.small
                    radius: Theme.rounding.small
                    color: picked ? Theme.primaryContainer : "transparent"

                    Behavior on color {
                        ColorAnim {}
                    }

                    Icon {
                        anchors.centerIn: parent
                        icon: spot.modelData[1]
                        size: Theme.icon.small
                        color: spot.picked ? Theme.onPrimaryContainer : Theme.dim
                    }

                    StateLayer {
                        onClicked: Config.set(place.key, spot.modelData[0])
                    }
                }
            }
        }
    }
}
