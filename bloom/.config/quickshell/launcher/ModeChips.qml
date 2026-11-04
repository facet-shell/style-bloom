import QtQuick
import qs.components
import qs.config

// The modes while the field is empty: a chip each with the letter to type, its icon and its
// name. A click puts the prefix into the field (picked(key)).
//
//   entries  [{ key, icon, name }]
Flow {
    id: root

    property var entries: []

    signal picked(string key)

    spacing: 6

    Repeater {
        model: root.entries

        delegate: Rectangle {
            id: chip

            required property var modelData
            required property int index

            implicitWidth: row.implicitWidth + 18
            implicitHeight: Theme.control.chip + 6
            radius: height / 2
            color: layer.containsMouse ? Theme.high : Theme.container
            scale: layer.pressed ? 0.94 : 1
            opacity: 0

            Component.onCompleted: entrance.start()
            // Again each time they come back (the launcher opens, the field is emptied)
            onVisibleChanged: {
                if (visible) {
                    opacity = 0;
                    entrance.restart();
                }
            }

            // Staggered like the rows, one step after the other
            SequentialAnimation {
                id: entrance

                PauseAnimation {
                    duration: Theme.anim.small * (0.6 + 0.08 * chip.index)
                }
                Anim {
                    target: chip
                    property: "opacity"
                    to: 1
                }
            }

            Behavior on color {
                ColorAnim {}
            }
            Behavior on scale {
                SpringAnim {}
            }

            Row {
                id: row

                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 8

                // The letter, like a key cap
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(height, letter.implicitWidth + 12)
                    height: Theme.control.chip - 6
                    radius: height / 2
                    color: Theme.secondaryContainer

                    StyledText {
                        id: letter

                        anchors.centerIn: parent
                        text: chip.modelData.key
                        font.family: Theme.mono
                        font.pixelSize: Theme.size.tiny
                        font.weight: Font.DemiBold
                    }
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: chip.modelData.icon
                    size: Theme.icon.small
                    color: layer.containsMouse ? Theme.text : Theme.dim
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.name
                    color: layer.containsMouse ? Theme.text : Theme.dim
                    font.pixelSize: Theme.size.small
                }
            }

            StateLayer {
                id: layer

                opacity: pressed ? 1 : 0
                onClicked: root.picked(chip.modelData.key)
            }
        }
    }
}
