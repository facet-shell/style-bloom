import QtQuick
import qs.components
import qs.config

// The results as rounded rows, a window of `rows` of them at a time (long lists scroll with
// the selection). The selection is one pill behind the rows that glides to the picked one.
// `generation` going up rebuilds the rows with the staggered entrance (opening, a new mode).
Item {
    id: root

    property var results: []
    property int current: 0
    property int rows: 6
    property bool stagger: false
    property int generation: 0
    readonly property int rowHeight: 56
    readonly property int gap: Theme.spacing.small
    readonly property int first: Math.max(0, Math.min(current - rows + 1, results.length - rows))
    readonly property var shown: results.slice(first, first + rows)
    readonly property bool selectable: (results[current]?.kind ?? "info") !== "info"

    signal hoveredRow(int position)
    signal clickedRow(int position, var mouse)

    // No animation here: the drawer itself glides to the new height
    implicitHeight: shown.length > 0 ? shown.length * rowHeight + (shown.length - 1) * gap : 0

    // The selection
    Rectangle {
        width: parent.width
        height: root.rowHeight
        y: (root.current - root.first) * (root.rowHeight + root.gap)
        radius: Theme.rounding.medium
        color: Theme.secondaryContainer
        opacity: root.selectable && root.shown.length > 0 ? 1 : 0

        Behavior on y {
            Anim {
                duration: Theme.anim.small
            }
        }
        Behavior on opacity {
            Anim {
                duration: Theme.anim.small
            }
        }
        Behavior on color {
            ColorAnim {}
        }
    }

    Column {
        width: parent.width
        spacing: root.gap

        Repeater {
            // The generation in front makes a new one rebuild the rows even with equal results
            model: (root.generation, root.shown.slice())

            delegate: ResultRow {
                required property var modelData
                required property int index

                width: parent?.width ?? 0
                entry: modelData
                active: root.first + index === root.current
                animateIn: root.stagger
                order: index
                onHovered: root.hoveredRow(root.first + index)
                onClicked: mouse => root.clickedRow(root.first + index, mouse)
            }
        }
    }
}
