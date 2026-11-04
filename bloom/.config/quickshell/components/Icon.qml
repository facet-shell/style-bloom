import QtQuick
import qs.config

// A Material Symbols Rounded icon by name (the ligature, as on fonts.google.com/icons):
//
//   Icon { icon: "volume_up" }
//
//   icon     the symbol's name ("" shows nothing)
//   size     pixel size, Theme.icon.normal by default
//   fill     0 outlined … 1 filled (animates), 1 by default like the mockup
//   weight   100 … 700, 500 by default
//   color    Theme.text by default (dim: true for Theme.dim)
Text {
    id: root

    property string icon: ""
    property real size: Theme.icon.normal
    property real fill: 1
    property int weight: 500
    property bool dim: false

    text: icon
    visible: icon !== ""
    color: dim ? Theme.dim : Theme.text
    font.family: Theme.iconFont
    font.pixelSize: Math.round(size)
    // The optical size follows the pixel size inside the font's 20…48 range
    font.variableAxes: ({ "FILL": fill, "wght": weight, "opsz": Math.max(20, Math.min(48, size)) })
    font.hintingPreference: Font.PreferNoHinting
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.QtRendering

    Behavior on fill {
        Anim {
            duration: Theme.anim.small
        }
    }
    Behavior on color {
        ColorAnim {}
    }
}
