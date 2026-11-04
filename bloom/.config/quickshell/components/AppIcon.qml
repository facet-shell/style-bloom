import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config

// An app's icon in a rounded square (launcher results, notifications, the mixer, the task
// manager): the icon from the icon theme, or the first letter on a color made from the name
// when there is none.
//
//   AppIcon { name: "vesktop" }   or   AppIcon { source: notification.image; letter: "D" }
//
//   name      icon name from the desktop entry or the app id ("" for none)
//   source    an image path or URL instead (wins over name)
//   letter    the fallback text (the name's first letter by default)
//   size      Theme.control.appIcon (40); radius follows (14 at 40)
//   round     a circle instead (avatars, voice)
//   tint      the fallback's color (made from the name by default)
Item {
    id: root

    property string name: ""
    property string source: ""
    property string letter: (name || "?").charAt(0).toUpperCase()
    property real size: Theme.control.appIcon
    property bool round: false
    property color tint: Qt.hsla(hue(name || letter), 0.45, 0.45, 1)

    readonly property string resolved: source !== "" ? source : name !== "" ? Quickshell.iconPath(name, true) : ""
    readonly property bool hasImage: resolved !== "" && image.status !== Image.Error

    // The same name always gets the same color
    function hue(text) {
        let h = 0;
        for (let i = 0; i < text.length; i++)
            h = (h * 31 + text.charCodeAt(i)) % 360;
        return h / 360;
    }

    implicitWidth: size
    implicitHeight: size

    ClippingRectangle {
        anchors.fill: parent
        radius: root.round ? width / 2 : Math.round(root.size * 0.35)
        color: root.hasImage ? "transparent" : root.tint

        StyledText {
            anchors.centerIn: parent
            visible: !root.hasImage
            text: root.letter
            color: "#ffffff"
            font.pixelSize: Math.round(root.size * 0.38)
            font.weight: Font.Bold
        }

        Image {
            id: image

            anchors.fill: parent
            visible: root.hasImage
            source: root.resolved
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }
}
