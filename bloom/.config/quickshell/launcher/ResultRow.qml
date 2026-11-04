import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// One result: the app icon, avatar, picture, emoji or a Material symbol in a rounded square,
// the title (matched letters in primary) with a dim line under it, the category on the right.
// The selection's colour is drawn by ResultList, so it can glide from row to row.
Item {
    id: root

    property var entry: ({})
    property bool active: false
    // Fades and rises in after `order` steps (the staggered entrance)
    property bool animateIn: false
    property int order: 0

    readonly property bool passive: entry.kind === "info"
    readonly property string symbol: entry.symbol ?? ""
    readonly property string image: entry.image ?? ""
    readonly property string iconName: entry.iconName ?? ""
    readonly property bool useIcon: image !== "" || iconName !== "" || ((entry.letter ?? "") !== "" && symbol === "")

    signal hovered()
    signal clicked(var mouse)

    function escapeHtml(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Encoded per path part: a "#" or "?" in a file name would end the URL early
    function fileUrl(path) {
        const p = String(path ?? "");
        if (p === "" || p.includes("://"))
            return p;
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    implicitHeight: 56

    Component.onCompleted: {
        if (animateIn && Theme.animated) {
            body.opacity = 0;
            entrance.start();
        }
    }

    SequentialAnimation {
        id: entrance

        PauseAnimation {
            duration: Theme.anim.small * (0.3 + 0.14 * root.order)
        }
        ParallelAnimation {
            Anim {
                target: body
                property: "opacity"
                to: 1
            }
            Anim {
                target: rise
                property: "y"
                from: 10
                to: 0
            }
        }
    }

    Item {
        id: body

        anchors.fill: parent
        transform: Translate {
            id: rise
        }

        StateLayer {
            radius: Theme.rounding.medium
            disabled: root.passive
            onEntered: root.hovered()
            onClicked: mouse => root.clicked(mouse)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 14
            spacing: 14

            // The lead: picture or icon, a symbol when there is none (or it fails to load)
            Item {
                implicitWidth: Theme.control.appIcon
                implicitHeight: Theme.control.appIcon
                opacity: root.passive ? 0.7 : 1

                Rectangle {
                    anchors.fill: parent
                    visible: (entry.emoji ?? "") !== "" || (root.symbol !== "" && !(root.useIcon && icon.hasImage))
                    radius: Math.round(width * 0.35)
                    color: root.active && !root.passive ? Theme.surface : Theme.high

                    Behavior on color {
                        ColorAnim {}
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: (entry.emoji ?? "") === ""
                        icon: root.symbol
                        size: Theme.icon.normal
                        color: root.passive ? Theme.dim : entry.tint ?? Theme.primary
                        fill: root.active ? 1 : 0.4
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: (entry.emoji ?? "") !== ""
                        text: entry.emoji ?? ""
                        font.pixelSize: Theme.size.large
                    }
                }

                AppIcon {
                    id: icon

                    anchors.fill: parent
                    visible: root.useIcon && (hasImage || root.symbol === "")
                    size: Theme.control.appIcon
                    name: root.image === "" ? root.iconName : ""
                    source: root.image !== "" ? root.fileUrl(root.image) : ""
                    letter: entry.letter ?? "?"
                    round: entry.round === true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: entry.markup ?? root.escapeHtml(entry.title ?? "")
                    textFormat: Text.StyledText
                    color: root.passive ? Theme.dim : Theme.text
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: entry.desc ?? ""
                    dim: true
                    font.pixelSize: Theme.size.small
                }
            }

            StyledText {
                visible: text !== ""
                text: entry.category ?? ""
                dim: true
                font.pixelSize: Theme.size.tiny
            }

            Icon {
                visible: root.active && !root.passive
                icon: "keyboard_return"
                size: Theme.icon.small
                dim: true
            }
        }
    }
}
