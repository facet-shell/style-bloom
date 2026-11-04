import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// The launcher's round search field with the mode chip on the right. SearchField's look, but
// every key comes through keyPressed(event) first, so the launcher sees Shift+Enter, Ctrl+C
// and the arrows and decides itself (accept the event to keep it from the text).
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string icon: "search"
    // The mode chip: its name and icon
    property string mode: "apps"
    property string modeIcon: ""
    readonly property alias input: input

    signal keyPressed(var event)

    function focusField() {
        input.forceActiveFocus();
    }

    implicitWidth: 480
    implicitHeight: Theme.control.field
    radius: height / 2
    color: Theme.container

    Behavior on color {
        ColorAnim {}
    }

    // A click anywhere on the pill puts the cursor back in the field
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 12
        spacing: 10

        Icon {
            id: lead

            icon: root.icon
            dim: true

            // A short pop when the mode changes the icon
            onIconChanged: pop.restart()
            SequentialAnimation {
                id: pop

                SpringAnim {
                    target: lead
                    property: "scale"
                    from: 0.6
                    to: 1
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: input

                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.primaryContainer
                selectedTextColor: Theme.onPrimaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.size.medium
                font.weight: Font.Medium
                clip: true
                focus: true

                Keys.onPressed: event => root.keyPressed(event)
            }

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: root.placeholder
                dim: true
                opacity: 0.7
                font.pixelSize: Theme.size.medium
            }
        }

        // The mode chip
        Rectangle {
            implicitWidth: chipRow.implicitWidth + 20
            implicitHeight: 28
            radius: height / 2
            color: Theme.high
            clip: true

            Behavior on implicitWidth {
                Anim {
                    duration: Theme.anim.small
                }
            }

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.modeIcon !== ""
                    icon: root.modeIcon
                    size: 15
                    color: Theme.primary
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.mode
                    dim: true
                    font.pixelSize: Theme.size.tiny
                }
            }
        }
    }
}
