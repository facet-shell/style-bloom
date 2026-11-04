import QtQuick
import qs.components
import qs.config
import "DrawEngine.js" as Engine

// The drawing tools in the bloom look: round pills on the surface, a row (floating at the
// bottom of a screen) or a column (docked on the left, the picture editor). Tools, the
// theme's colors as round swatches, four widths, then ruler, undo, redo and clear. Hovering
// a button names it in a small pill above the row (or under the column); `hint` has the
// whole text. The same API as tui's toolbar, so the picture editor can use it as it is.
Item {
    id: root

    required property DrawTools tools
    required property var store
    property bool vertical: false
    property string title: "draw"
    // Picture editor: a pointer that leaves the mouse to blur boxes and the crop
    property bool selectTool: false
    // Overlay: click through and dock / float
    property bool overlayButtons: false
    property string hint: ""

    readonly property int cell: Theme.control.iconButton
    readonly property int pad: 6

    implicitWidth: shell.implicitWidth
    implicitHeight: shell.implicitHeight + (vertical ? hintText.height + Theme.spacing.normal : 0)

    // Keys every place shares: the tool letters (DrawEngine.TOOLS), Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y.
    // true when the key was used.
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (ctrl && event.key === Qt.Key_Z) {
            if (event.modifiers & Qt.ShiftModifier)
                store.redo();
            else
                store.undo();
            return true;
        }
        if (ctrl && event.key === Qt.Key_Y) {
            store.redo();
            return true;
        }
        if (ctrl || (event.modifiers & Qt.AltModifier))
            return false;
        const tool = Engine.toolOfKey(event.text.toLowerCase());
        if (tool === "")
            return false;
        tools.tool = tool;
        return true;
    }

    function setHint(text, on) {
        if (on)
            hint = text;
        else if (hint === text)
            hint = "";
    }

    // The inline components below see only their own properties (not root); what they need
    // from the toolbar is set where they are used.

    // A tool or action: the picked tool is a filled primary square, toggles are tonal
    component ToolButton: IconButton {
        id: btn

        property string name: ""

        signal hint(string label, bool hovering)

        size: Theme.control.iconButton
        iconSize: 20
        onHoveredChanged: btn.hint(btn.name, btn.hovered)
    }

    // A round pill holding a few buttons: one row, or two columns when docked
    component Group: Rectangle {
        id: group

        property bool vertical: false
        default property alias content: cells.data

        implicitWidth: cells.implicitWidth + 12
        implicitHeight: cells.implicitHeight + 12
        radius: group.vertical ? Theme.rounding.large : height / 2
        color: Theme.container

        Grid {
            id: cells

            anchors.centerIn: parent
            columns: group.vertical ? 2 : 100
            spacing: Theme.spacing.tiny
        }
    }

    // A round cell for the swatches and widths, with its own hover wash
    component RoundCell: Rectangle {
        id: roundCell

        property string name: ""
        property bool picked: false

        signal clicked()
        signal hint(string label, bool hovering)

        width: Theme.control.iconButton
        height: Theme.control.iconButton
        radius: height / 2
        color: "transparent"

        StateLayer {
            onClicked: roundCell.clicked()
            onContainsMouseChanged: roundCell.hint(roundCell.name, containsMouse)
        }
    }

    // Clicks between the buttons must not draw underneath
    MouseArea {
        anchors.fill: shell
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: shell

        implicitWidth: groups.implicitWidth + root.pad * 2
        implicitHeight: groups.implicitHeight + root.pad * 2
        width: implicitWidth
        height: implicitHeight
        radius: root.vertical ? Theme.rounding.drawer : height / 2
        color: Theme.surface

        Grid {
            id: groups

            anchors.centerIn: parent
            columns: root.vertical ? 1 : 100
            spacing: Theme.spacing.small + 2
            verticalItemAlignment: Grid.AlignVCenter
            horizontalItemAlignment: Grid.AlignHCenter

            Group {
                vertical: root.vertical

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    visible: root.selectTool
                    icon: Engine.ICONS.select
                    name: "select · blur boxes and crop (v)"
                    filled: root.tools.tool === ""
                    active: filled
                    onClicked: root.tools.tool = ""
                }

                Repeater {
                    model: Engine.TOOLS

                    ToolButton {
                        required property var modelData

                        onHint: (label, hovering) => root.setHint(label, hovering)

                        icon: modelData.icon
                        name: `${modelData.name} (${modelData.key})`
                        filled: root.tools.tool === modelData.id
                        active: filled
                        onClicked: root.tools.tool = modelData.id
                    }
                }
            }

            Group {
                vertical: root.vertical

                Repeater {
                    model: Engine.COLORS

                    RoundCell {
                        id: swatch

                        required property string modelData

                        onHint: (label, hovering) => root.setHint(label, hovering)

                        name: modelData
                        picked: root.tools.color === modelData
                        onClicked: root.tools.color = modelData

                        // A ring around the picked one
                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.text
                            opacity: swatch.picked ? 1 : 0
                            scale: swatch.picked ? 1 : 0.7

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.anim.small
                                }
                            }
                            Behavior on scale {
                                SpringAnim {}
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: width / 2
                            color: Theme[swatch.modelData] ?? Theme.primary
                            border.width: 1
                            border.color: Theme.outline
                        }
                    }
                }
            }

            Group {
                vertical: root.vertical

                Repeater {
                    model: Engine.WIDTHS

                    RoundCell {
                        id: widthCell

                        required property int modelData

                        onHint: (label, hovering) => root.setHint(label, hovering)

                        name: `${modelData} px`
                        picked: root.tools.width === modelData
                        color: picked ? Theme.high : "transparent"
                        onClicked: root.tools.width = modelData

                        Behavior on color {
                            ColorAnim {}
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(18, widthCell.modelData + 3)
                            height: width
                            radius: width / 2
                            color: widthCell.picked ? Theme.text : Theme.dim
                        }
                    }
                }
            }

            Group {
                vertical: root.vertical

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    icon: Engine.ICONS.ruler
                    name: "ruler · drag it, turn it by its ends or the wheel, the pen follows its edge"
                    tonal: root.tools.ruler
                    iconColor: root.tools.ruler || hovered ? Theme.text : Theme.dim
                    onClicked: root.tools.ruler = !root.tools.ruler
                }

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    visible: root.overlayButtons
                    icon: Engine.ICONS.through
                    name: "click through · the drawing stays, the windows get the mouse"
                    tonal: root.tools.through
                    iconColor: root.tools.through || hovered ? Theme.text : Theme.dim
                    onClicked: root.tools.through = !root.tools.through
                }

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    visible: root.overlayButtons
                    icon: root.tools.docked ? Engine.ICONS.dockBottom : Engine.ICONS.dockLeft
                    name: root.tools.docked ? "toolbar to the bottom" : "toolbar to the left"
                    onClicked: root.tools.docked = !root.tools.docked
                }

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    icon: Engine.ICONS.undo
                    name: "undo (ctrl+z)"
                    disabled: (root.store.undoStack?.length ?? 1) === 0
                    onClicked: root.store.undo()
                }

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    icon: Engine.ICONS.redo
                    name: "redo (ctrl+shift+z)"
                    disabled: (root.store.redoStack?.length ?? 1) === 0
                    onClicked: root.store.redo()
                }

                ToolButton {
                    onHint: (label, hovering) => root.setHint(label, hovering)
                    icon: Engine.ICONS.clear
                    name: "clear the drawing (undo brings it back)"
                    iconColor: Theme.error
                    onClicked: root.store.clearShapes()
                }
            }
        }
    }

    // Row: what the hovered button does, in a pill above it (or the title, e.g. click through)
    Rectangle {
        readonly property string text: root.hint !== "" ? root.hint : root.title

        visible: !root.vertical
        anchors.horizontalCenter: shell.horizontalCenter
        y: -height - Theme.spacing.normal
        width: Math.min(hintLabel.implicitWidth + 28, Math.max(shell.width, 420))
        height: 32
        radius: height / 2
        color: Theme.surface
        opacity: root.hint !== "" || root.tools.through ? 1 : 0
        scale: opacity > 0 ? 1 : 0.92

        Behavior on opacity {
            Anim {
                duration: Theme.anim.small
            }
        }
        Behavior on scale {
            SpringAnim {}
        }

        StyledText {
            id: hintLabel

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 28)
            text: parent.text
            font.pixelSize: Theme.size.small
        }
    }

    // Column: only the name, the column is narrow (the host can show the rest)
    StyledText {
        id: hintText

        visible: root.vertical
        anchors.top: shell.bottom
        anchors.topMargin: Theme.spacing.normal
        width: shell.width
        text: root.hint.split(" · ")[0]
        dim: true
        wrapMode: Text.Wrap
        maximumLineCount: 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        font.pixelSize: Theme.size.tiny
        // Room for two lines, so the toolbar does not jump while hovering
        height: font.pixelSize * 2.8
    }
}
