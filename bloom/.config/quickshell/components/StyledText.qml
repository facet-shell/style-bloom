import QtQuick
import qs.config

// Text in the bloom look: Rubik, Theme.text, Theme.size.normal. Everything else is plain Text
// (font.pixelSize, font.weight, color, elide …).
//
//   dim: true    Theme.dim instead of Theme.text (labels, secondary lines)
//   tabular: true  figures of the same width (clocks, percentages, counters)
Text {
    property bool dim: false
    property bool tabular: false

    color: dim ? Theme.dim : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.size.normal
    font.features: tabular ? ({ "tnum": 1 }) : ({})
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText

    Behavior on color {
        ColorAnim {}
    }
}
