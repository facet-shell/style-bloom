import QtQuick
import qs.config

// The thick bloom slider (volume, brightness): a round track, the filled part in
// Theme.primary, an icon inside on the left. `thin` makes the 10 px line of the app mixer.
//
//   Slider { icon: "volume_up"; value: sink.audio.volume; onMoved: v => sink.audio.volume = v }
//
//   value      0..1, shown; like Switch it is not changed by the slider itself, so handle
//              moved(value) (while dragging, clicking, scrolling) and write it back
//   icon       Material Symbols name inside the track (thick only)
//   thin       the mixer's line instead of the 48 px track
//   step       for the wheel and the arrow keys (0.05)
//   disabled
//   signal moved(real value), released()
Item {
    id: root

    property real value: 0
    property string icon: ""
    property bool thin: false
    property real step: 0.05
    property bool disabled: false
    readonly property bool dragging: area.pressed
    readonly property real shown: Math.max(0, Math.min(1, value))

    signal moved(real value)
    signal released()

    implicitWidth: 240
    implicitHeight: thin ? Theme.control.sliderThin : Theme.control.slider
    opacity: disabled ? 0.38 : 1

    function valueAt(x) {
        return Math.max(0, Math.min(1, x / width));
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Theme.high
        clip: true

        Behavior on color {
            ColorAnim {}
        }

        Rectangle {
            // The fill never gets narrower than its own roundness, so 0 still shows a stub
            // under the icon
            width: Math.max(root.thin ? 0 : height, root.shown * parent.width)
            height: parent.height
            radius: height / 2
            color: Theme.primary

            Behavior on width {
                enabled: !root.dragging
                Anim {
                    duration: Theme.anim.small
                }
            }
            Behavior on color {
                ColorAnim {}
            }
        }

        Icon {
            visible: !root.thin && root.icon !== ""
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: Theme.icon.normal
            color: Theme.onPrimary
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        // A thin line is hard to hit: the area reaches a bit above and below it
        anchors.topMargin: root.thin ? -8 : 0
        anchors.bottomMargin: root.thin ? -8 : 0
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
        onReleased: root.released()
        onWheel: wheel => {
            const up = wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0;
            root.moved(Math.max(0, Math.min(1, root.value + (up ? root.step : -root.step))));
        }
    }

    Keys.onLeftPressed: root.moved(Math.max(0, value - step))
    Keys.onRightPressed: root.moved(Math.min(1, value + step))
}
