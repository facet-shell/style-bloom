import QtQuick
import qs.components
import qs.config

// A small text field for settings rows (SearchField is the launcher's big one): a round
// field in Theme.high with a primary ring while typing.
//
//   text, placeholder, input (the TextInput); signal accepted(), finished() (focus left)
Rectangle {
    id: root

    property alias text: field.text
    property string placeholder: ""
    readonly property alias input: field

    signal accepted()
    signal finished()

    implicitWidth: 280
    implicitHeight: Theme.control.button
    radius: height / 2
    color: Theme.high
    border.width: 2
    border.color: field.activeFocus ? Theme.primary : "transparent"

    Behavior on border.color {
        ColorAnim {}
    }

    TextInput {
        id: field

        anchors.fill: parent
        anchors.leftMargin: Theme.padding.card
        anchors.rightMargin: Theme.padding.card
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.primaryContainer
        selectedTextColor: Theme.textOnPrimaryContainer
        font.family: Theme.font
        font.pixelSize: Theme.size.normal
        clip: true
        selectByMouse: true
        onAccepted: root.accepted()
        onEditingFinished: root.finished()
    }

    StyledText {
        anchors.fill: field
        visible: field.text === "" && !field.activeFocus
        text: root.placeholder
        dim: true
        opacity: 0.7
    }
}
