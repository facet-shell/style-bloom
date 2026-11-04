import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// One theme in the Look page (the mockup's .th): a strip of four of its colors, the name,
// a check while it is in use and a primary ring around it.
//
//   name, description (dim, under the name), swatch [four colors], picked, icon (in front
//   of the name, e.g. "wallpaper" for the colors from the wallpaper); signal clicked()
Rectangle {
    id: card

    property string name: ""
    property string description: ""
    property var swatch: []
    property bool picked: false
    property string icon: ""

    signal clicked()

    implicitWidth: 200
    implicitHeight: content.implicitHeight + Theme.padding.normal * 2
    radius: Theme.rounding.large
    color: layer.containsMouse ? Theme.high : Theme.container
    border.width: 2
    border.color: picked ? Theme.primary : "transparent"
    scale: layer.pressed ? 0.97 : 1

    Behavior on color {
        ColorAnim {}
    }
    Behavior on border.color {
        ColorAnim {}
    }
    Behavior on scale {
        SpringAnim {}
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.padding.normal
        spacing: Theme.spacing.medium

        // Four stripes in one rounded strip: the outer two are round rectangles reaching
        // under the inner two, so only the strip's own corners show round
        Item {
            id: strip

            readonly property real part: width / 4
            readonly property real round: Math.min(Theme.rounding.normal, part)

            Layout.fillWidth: true
            implicitHeight: 46

            Rectangle {
                x: 0
                width: strip.part + strip.round
                height: parent.height
                radius: strip.round
                color: card.swatch[0] ?? Theme.high

                Behavior on color {
                    ColorAnim {
                        duration: Theme.anim.color
                    }
                }
            }
            Rectangle {
                x: strip.width - width
                width: strip.part + strip.round
                height: parent.height
                radius: strip.round
                color: card.swatch[3] ?? Theme.high

                Behavior on color {
                    ColorAnim {
                        duration: Theme.anim.color
                    }
                }
            }
            Rectangle {
                x: strip.part
                width: strip.part
                height: parent.height
                color: card.swatch[1] ?? Theme.high

                Behavior on color {
                    ColorAnim {
                        duration: Theme.anim.color
                    }
                }
            }
            Rectangle {
                x: strip.part * 2
                width: strip.part
                height: parent.height
                color: card.swatch[2] ?? Theme.high

                Behavior on color {
                    ColorAnim {
                        duration: Theme.anim.color
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Icon {
                visible: card.icon !== ""
                icon: card.icon
                size: Theme.icon.small
                dim: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: card.name
                    font.pixelSize: Theme.size.small + 1
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: card.description !== ""
                    text: card.description
                    dim: true
                    font.pixelSize: Theme.size.tiny
                }
            }
            Icon {
                icon: "check_circle"
                size: Theme.icon.small
                color: Theme.primary
                opacity: card.picked ? 1 : 0
                scale: card.picked ? 1 : 0.5

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.small
                    }
                }
                Behavior on scale {
                    SpringAnim {}
                }
            }
        }
    }

    StateLayer {
        id: layer

        onClicked: card.clicked()
    }
}
