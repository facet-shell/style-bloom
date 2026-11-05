import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// One entry of a category's menu (MenuPage): the page's icon on a tinted tile, its name, a
// dim line under it, what it is set to right now on the right, and a chevron. The rows sit
// in one card per group; the row draws the separator above itself and its own hover.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string value: ""
    // The first row of a card has no separator
    property bool first: false

    signal clicked()

    implicitHeight: 62

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.rounding.normal
        color: layer.containsMouse ? Theme.high : "transparent"

        Behavior on color {
            ColorAnim {}
        }

        StateLayer {
            id: layer

            onClicked: root.clicked()
        }
    }

    Rectangle {
        visible: !root.first
        x: 14 + 36 + 14
        width: parent.width - x - 14
        height: 1
        color: Theme.outline
        opacity: 0.35
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 14

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: Theme.rounding.small
            color: Theme.primaryContainer

            Icon {
                anchors.centerIn: parent
                icon: root.icon
                size: 20
                color: Theme.textOnPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.title
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                dim: true
                font.pixelSize: Theme.size.small
            }
        }

        StyledText {
            Layout.maximumWidth: 220
            visible: root.value !== ""
            text: root.value
            dim: true
            font.pixelSize: Theme.size.small
            horizontalAlignment: Text.AlignRight
        }

        Icon {
            icon: "chevron_right"
            size: Theme.icon.small + 2
            dim: true
        }
    }
}
