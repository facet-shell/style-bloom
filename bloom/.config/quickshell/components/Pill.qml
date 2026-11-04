import QtQuick
import QtQuick.Layouts
import qs.config

// The rounded container of the bar and of small groups: a row of icons and text on
// Theme.container, fully round. Children go into a RowLayout (centered vertically).
//
//   Pill { interactive: true; onClicked: …; Icon { icon: "lan" } Icon { icon: "volume_up" } }
//
//   interactive   hover turns it Theme.high, clicks and the wheel come through
//   active        drawn "on" (Theme.high), e.g. while the panel it opens is out
//   padding       inside, left and right (14); spacing between children (10)
//   baseColor / activeColor
//   hovered       the mouse is on it
//   signal clicked(mouse), scrolled(wheel); acceptedButtons for right clicks
Rectangle {
    id: root

    property bool interactive: false
    property bool active: false
    property real padding: 14
    property alias spacing: row.spacing
    property color baseColor: Theme.container
    property color activeColor: Theme.high
    property alias acceptedButtons: layer.acceptedButtons
    readonly property bool hovered: layer.containsMouse
    default property alias content: row.data

    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.control.pill
    radius: height / 2
    color: active || (interactive && layer.containsMouse) ? activeColor : baseColor

    Behavior on color {
        ColorAnim {}
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 10
    }

    StateLayer {
        id: layer

        // The color change is the hover; the wash only shows the press
        disabled: !root.interactive
        opacity: pressed ? 1 : 0
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.scrolled(wheel)
    }
}
