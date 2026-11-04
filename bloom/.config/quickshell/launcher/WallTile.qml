import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config

// One wallpaper as a rounded picture with its name, a play mark on the moving ones and an
// "in use" pill. The picked one gets a primary ring and rounder corners; hover lifts it.
// Used by the big menu's grid and the quick row.
Item {
    id: root

    property var wall: null
    property string picture: ""
    property bool picked: false
    property bool inUse: false
    property real restRadius: Theme.rounding.medium
    property real pickedRadius: Theme.rounding.drawer
    readonly property bool hovered: area.containsMouse

    signal clicked()
    signal doubleClicked()

    // Ring and picture lift together
    Item {
        anchors.fill: parent
        transform: Translate {
            y: root.hovered ? -3 : 0

            Behavior on y {
                SpringAnim {}
            }
        }

        // The ring around the picked one, outside the picture
        Rectangle {
            anchors.fill: tile
            anchors.margins: -3
            radius: tile.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Theme.primary
            opacity: root.picked ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.small
                }
            }
        }

        ClippingRectangle {
            id: tile

            anchors.fill: parent
            radius: root.picked ? root.pickedRadius : root.restRadius
            color: Theme.high

            Behavior on radius {
                SpringAnim {}
            }

            // Without a picture (a video the engine made no preview for)
            Icon {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                icon: root.wall?.kind === "image" ? "image" : "movie"
                size: Theme.icon.large
                dim: true
            }

            Image {
                id: image

                anchors.fill: parent
                source: root.picture
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }

            // Keeps the name readable on light pictures
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(parent.height, 46)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Theme.scrim
                    }
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                anchors.bottomMargin: 8
                text: root.wall?.title ?? ""
                color: Theme.textOnScrim
                font.pixelSize: Theme.size.tiny
                font.weight: Font.Medium
            }

            Icon {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                visible: root.wall !== null && root.wall.kind !== "image"
                icon: "play_circle"
                size: Theme.icon.small
                color: Theme.textOnScrim
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 8
                visible: root.inUse
                implicitWidth: useText.implicitWidth + 16
                implicitHeight: 20
                radius: height / 2
                color: Theme.primary

                StyledText {
                    id: useText

                    anchors.centerIn: parent
                    text: "in use"
                    color: Theme.textOnPrimary
                    font.pixelSize: Theme.size.tiny
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }
}
