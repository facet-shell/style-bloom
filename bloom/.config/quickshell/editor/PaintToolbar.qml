import QtQuick
import qs.components
import qs.config
import "PaintEngine.js" as Engine

// The picture editor's drawing tools, a column on the left: the pointer, the tools, the
// theme's colors as round swatches, four widths, then ruler, undo, redo and clear. The picked
// tool rounds into a soft square on Theme.primaryContainer. Hovering a button names it in
// `hint` (the editor shows the whole text under the picture).
Rectangle {
    id: root

    required property PaintTools tools
    required property var store
    property string hint: ""

    readonly property int cell: 40
    readonly property int pad: Theme.padding.small + 2

    implicitWidth: column.implicitWidth + pad * 2
    implicitHeight: column.implicitHeight + pad * 2
    radius: Theme.rounding.large
    color: Theme.surface

    // Keys the editor passes on: the tool letters (PaintEngine.TOOLS), Ctrl+Z, Ctrl+Shift+Z,
    // Ctrl+Y. true when the key was used.
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

    component ToolButton: Rectangle {
        id: btn

        property string icon: ""
        property string name: ""
        property bool active: false
        property bool danger: false

        signal clicked()

        width: root.cell
        height: root.cell
        radius: active ? Theme.rounding.normal : height / 2
        color: active ? Theme.primaryContainer : layer.containsMouse ? Theme.high : "transparent"
        scale: layer.pressed ? 0.88 : 1

        Behavior on radius {
            SpringAnim {}
        }
        Behavior on scale {
            SpringAnim {}
        }
        Behavior on color {
            ColorAnim {}
        }

        Icon {
            anchors.centerIn: parent
            icon: btn.icon
            size: Theme.icon.normal
            fill: btn.active ? 1 : 0
            color: btn.active ? Theme.onPrimaryContainer
                : btn.danger ? Theme.error
                : layer.containsMouse ? Theme.text : Theme.dim
        }

        StateLayer {
            id: layer

            color: btn.active ? Theme.onPrimaryContainer : Theme.text
            onClicked: btn.clicked()
            onContainsMouseChanged: root.setHint(btn.name, containsMouse)
        }
    }

    component Separator: Rectangle {
        width: root.cell * 2 + Theme.spacing.small
        height: 1
        color: Theme.outline
        opacity: 0.5
    }

    // Two buttons a row
    component Group: Grid {
        columns: 2
        spacing: Theme.spacing.small
    }

    // Clicks between the buttons must not draw underneath
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    Column {
        id: column

        x: root.pad
        y: root.pad
        spacing: Theme.spacing.normal

        Group {
            ToolButton {
                icon: Engine.ICONS.select
                name: "pointer · blur boxes and crop (v)"
                active: root.tools.tool === ""
                onClicked: root.tools.tool = ""
            }

            Repeater {
                model: Engine.TOOLS

                ToolButton {
                    required property var modelData

                    icon: modelData.icon
                    name: `${modelData.name} (${modelData.key})`
                    active: root.tools.tool === modelData.id
                    onClicked: root.tools.tool = modelData.id
                }
            }
        }

        Separator {}

        Group {
            Repeater {
                model: Engine.COLORS

                Item {
                    id: swatch

                    required property string modelData
                    readonly property bool picked: root.tools.color === modelData

                    width: root.cell
                    height: root.cell

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.primary
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
                        color: Theme[swatch.modelData] ?? Theme.tertiary
                        border.width: 1
                        border.color: Theme.outline
                        scale: swatchArea.pressed ? 0.8 : swatchArea.containsMouse ? 1.12 : 1

                        Behavior on scale {
                            SpringAnim {}
                        }
                    }

                    MouseArea {
                        id: swatchArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tools.color = swatch.modelData
                        onContainsMouseChanged: root.setHint(swatch.modelData, containsMouse)
                    }
                }
            }
        }

        Separator {}

        Group {
            Repeater {
                model: Engine.WIDTHS

                Rectangle {
                    id: widthButton

                    required property int modelData
                    readonly property bool picked: root.tools.width === modelData

                    width: root.cell
                    height: root.cell
                    radius: picked ? Theme.rounding.normal : height / 2
                    color: picked ? Theme.secondaryContainer : widthArea.containsMouse ? Theme.high : "transparent"

                    Behavior on radius {
                        SpringAnim {}
                    }
                    Behavior on color {
                        ColorAnim {}
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(18, widthButton.modelData + 3)
                        height: width
                        radius: width / 2
                        color: widthButton.picked ? Theme.text : Theme.dim
                    }

                    MouseArea {
                        id: widthArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tools.width = widthButton.modelData
                        onContainsMouseChanged: root.setHint(`${widthButton.modelData} px`, containsMouse)
                    }
                }
            }
        }

        Separator {}

        Group {
            ToolButton {
                icon: Engine.ICONS.ruler
                name: "ruler · drag it, turn it by its ends or the wheel, the pen follows its edge"
                active: root.tools.ruler
                onClicked: root.tools.ruler = !root.tools.ruler
            }

            ToolButton {
                icon: Engine.ICONS.undo
                name: "undo (ctrl+z)"
                onClicked: root.store.undo()
            }

            ToolButton {
                icon: Engine.ICONS.redo
                name: "redo (ctrl+shift+z)"
                onClicked: root.store.redo()
            }

            ToolButton {
                icon: Engine.ICONS.clear
                name: "clear the drawing (undo brings it back)"
                danger: true
                onClicked: root.store.clearShapes()
            }
        }
    }
}
