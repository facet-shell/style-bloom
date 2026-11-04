import QtQuick
import QtQuick.Layouts
import qs.config

// The launcher's search pill: an icon, the text field, and a small label on the right (the
// mode the launcher is in). Also for any other text entry in bloom.
//
//   SearchField { placeholder: "Search apps"; hint: "apps"; onAccepted: … }
//
//   text         what is typed (alias of the input's text)
//   placeholder  shown while empty
//   icon         in front ("search")
//   hint         the small label on the right ("" hides it)
//   password     dots instead of the text
//   baseColor    Theme.container
//   input        the TextInput itself (forceActiveFocus(), selectAll(), cursorPosition …)
//   signal accepted(), escaped(); Up/Down/Tab come through as navigated(key)
Rectangle {
    id: root

    property alias text: field.text
    property string placeholder: ""
    property string icon: "search"
    property string hint: ""
    property bool password: false
    property color baseColor: Theme.container
    readonly property alias input: field

    signal accepted()
    signal escaped()
    signal navigated(int key)

    function focusField() {
        field.forceActiveFocus();
    }

    implicitWidth: 480
    implicitHeight: Theme.control.field
    radius: height / 2
    color: baseColor

    Behavior on color {
        ColorAnim {}
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 14
        spacing: 10

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            dim: true
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: field

                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.primaryContainer
                selectedTextColor: Theme.onPrimaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.size.medium
                font.weight: Font.Medium
                echoMode: root.password ? TextInput.Password : TextInput.Normal
                clip: true
                focus: true

                Keys.onReturnPressed: root.accepted()
                Keys.onEnterPressed: root.accepted()
                Keys.onEscapePressed: root.escaped()
                Keys.onUpPressed: root.navigated(Qt.Key_Up)
                Keys.onDownPressed: root.navigated(Qt.Key_Down)
                Keys.onTabPressed: root.navigated(Qt.Key_Tab)
            }

            StyledText {
                anchors.fill: parent
                visible: field.text === ""
                text: root.placeholder
                dim: true
                opacity: 0.7
                font.pixelSize: Theme.size.medium
            }
        }

        Rectangle {
            visible: root.hint !== ""
            implicitWidth: hintText.implicitWidth + 18
            implicitHeight: 24
            radius: height / 2
            color: Theme.high

            StyledText {
                id: hintText

                anchors.centerIn: parent
                text: root.hint
                dim: true
                font.pixelSize: Theme.size.tiny
            }
        }
    }
}
