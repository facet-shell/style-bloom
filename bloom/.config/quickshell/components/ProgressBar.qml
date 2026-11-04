import QtQuick
import qs.config

// A thin round track with the done part in a color: song progress, a GoXLR fader in the OSD,
// a notification's time left, a download.
//
//   ProgressBar { value: player.position / player.length }
//
//   value      0..1
//   thickness  the height (6; 3 for the song line)
//   color      Theme.primary; trackColor Theme.high
//   animated   value changes glide (emphasized); off for things that tick every frame
Item {
    id: root

    property real value: 0
    property real thickness: 6
    property color color: Theme.primary
    property color trackColor: Theme.high
    property bool animated: true

    implicitWidth: 200
    implicitHeight: thickness

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        clip: true

        Rectangle {
            width: Math.max(0, Math.min(1, root.value)) * parent.width
            height: parent.height
            radius: height / 2
            color: root.color

            Behavior on width {
                enabled: root.animated
                Anim {
                    duration: Theme.anim.drawerOut
                }
            }
            Behavior on color {
                ColorAnim {}
            }
        }
    }
}
