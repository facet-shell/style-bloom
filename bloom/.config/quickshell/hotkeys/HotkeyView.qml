import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The hotkey card: a German QWERTZ keyboard with every key lit that does something together
// with Super (a dot when only Super+Shift+key is bound), then all binds grouped (shell,
// apps, canvas, windows, …) as cards. Hovering a key says what Super+key and
// Super+Shift+key do.
Rectangle {
    id: root

    property string hovered: ""

    readonly property int unit: 44
    readonly property int gap: 4
    // Rows per group; long groups get cut, the card has to fit on one screen
    readonly property int maxRows: 8

    // [label, key name as Hyprland calls it, width in keys]
    readonly property var keyRows: [
        [["^", "asciicircum", 1], ["1", "1", 1], ["2", "2", 1], ["3", "3", 1], ["4", "4", 1], ["5", "5", 1], ["6", "6", 1],
         ["7", "7", 1], ["8", "8", 1], ["9", "9", 1], ["0", "0", 1], ["ß", "ssharp", 1], ["´", "dead_acute", 1], ["⌫", "backspace", 2]],
        [["tab", "tab", 1.5], ["Q", "q", 1], ["W", "w", 1], ["E", "e", 1], ["R", "r", 1], ["T", "t", 1], ["Z", "z", 1], ["U", "u", 1],
         ["I", "i", 1], ["O", "o", 1], ["P", "p", 1], ["Ü", "udiaeresis", 1], ["+", "plus", 1], ["⏎", "return", 1.5]],
        [["caps", "caps_lock", 1.75], ["A", "a", 1], ["S", "s", 1], ["D", "d", 1], ["F", "f", 1], ["G", "g", 1], ["H", "h", 1],
         ["J", "j", 1], ["K", "k", 1], ["L", "l", 1], ["Ö", "odiaeresis", 1], ["Ä", "adiaeresis", 1], ["#", "numbersign", 1], ["", "", 1.25]],
        [["shift", "shift_l", 1.25], ["<", "less", 1], ["Y", "y", 1], ["X", "x", 1], ["C", "c", 1], ["V", "v", 1], ["B", "b", 1],
         ["N", "n", 1], ["M", "m", 1], [",", "comma", 1], [".", "period", 1], ["-", "minus", 1], ["shift", "shift_r", 2.75]],
        [["ctrl", "control_l", 1.5], ["super", "super_l", 1.25], ["alt", "alt_l", 1.25], ["space", "space", 7],
         ["alt gr", "iso_level3_shift", 1.25], ["menu", "menu", 1.25], ["ctrl", "control_r", 1.5]]
    ]
    readonly property var arrowRows: [
        [["", "", 1], ["↑", "up", 1], ["", "", 1]],
        [["←", "left", 1], ["↓", "down", 1], ["→", "right", 1]]
    ]

    // Super+1 … Super+0 share one row in Binds
    function bindsOf(keyId) {
        return keyId === "" ? [] : Binds.forKey(/^[0-9]$/.test(keyId) ? "1…0" : keyId);
    }

    function plain(keyId) {
        return bindsOf(keyId).some(r => !r.mods.includes("shift"));
    }

    function shifted(keyId) {
        return bindsOf(keyId).some(r => r.mods.includes("shift"));
    }

    function capsOf(row) {
        return row.mods.concat([row.key]);
    }

    function setHovered(keyId, on) {
        if (on)
            hovered = keyId;
        else if (hovered === keyId)
            hovered = "";
    }

    readonly property string hoverText: {
        if (hovered === "")
            return "hover a key: what super + key and super + shift + key do";
        const list = bindsOf(hovered);
        if (list.length === 0)
            return "nothing bound with super";
        return list.map(r => `${r.mods.join(" + ")} + ${r.key}: ${r.label}`).join("   ·   ");
    }

    implicitWidth: content.implicitWidth + Theme.padding.drawer * 2 + 12
    implicitHeight: content.implicitHeight + Theme.padding.drawer * 2 + 12
    width: implicitWidth
    height: implicitHeight
    radius: Theme.rounding.drawer
    color: Theme.surface

    // The inline components below see only their own properties; what they need is set
    // where they are used.

    // A key or modifier in a bind row: a small rounded cap
    component KeyCap: Rectangle {
        id: cap

        property string text: ""

        implicitWidth: Math.max(22, capText.implicitWidth + 12)
        implicitHeight: 22
        radius: Theme.rounding.small * 0.7
        color: Theme.high

        StyledText {
            id: capText

            anchors.centerIn: parent
            text: cap.text
            font.pixelSize: Theme.size.tiny
            font.weight: Font.Medium
        }
    }

    // One key of the map: lit when Super+key is bound, a dot when only Super+Shift+key is
    component Key: Rectangle {
        id: key

        property var spec: ["", "", 1]
        property real unit: 44
        property real gap: 4
        property bool lit: false
        property bool marked: false
        readonly property string keyId: spec[1]
        readonly property bool isSuper: keyId === "super_l"
        readonly property bool hot: keyHover.hovered && keyId !== ""

        signal hover(string keyId, bool hovering)

        width: spec[2] * unit - gap
        height: unit - gap
        radius: Theme.rounding.small
        color: keyId === "" ? "transparent" : lit ? Theme.primary : isSuper ? Theme.primaryContainer : Theme.container
        border.width: hot ? 2 : 0
        border.color: lit ? Theme.onPrimary : Theme.primary
        scale: hot ? 1.06 : 1

        Behavior on scale {
            SpringAnim {}
        }
        Behavior on color {
            ColorAnim {}
        }

        StyledText {
            anchors.centerIn: parent
            text: key.spec[0]
            color: key.lit ? Theme.onPrimary : key.isSuper ? Theme.onPrimaryContainer : Theme.dim
            font.pixelSize: key.spec[0].length > 1 ? Theme.size.tiny : Theme.size.normal
            font.weight: key.lit || key.isSuper ? Font.Medium : Font.Normal
        }

        Rectangle {
            visible: key.marked
            anchors { right: parent.right; top: parent.top; margins: 6 }
            width: 6
            height: 6
            radius: 3
            color: Theme.tertiary
        }

        HoverHandler {
            id: keyHover

            onHoveredChanged: key.hover(key.keyId, hovered)
        }
    }

    // Swallows clicks so they do not close the overlay
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spacing.large

        // Title and the legend
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Icon {
                icon: "keyboard"
                size: Theme.icon.large
                color: Theme.primary
            }
            StyledText {
                text: "Hotkeys"
                font.pixelSize: Theme.size.large
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing.small
                text: "hold super"
                dim: true
                font.pixelSize: Theme.size.small
            }

            Rectangle {
                implicitWidth: 14
                implicitHeight: 14
                radius: 4
                color: Theme.primary
            }
            StyledText {
                text: "super + key"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Rectangle {
                Layout.leftMargin: Theme.spacing.medium
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: Theme.tertiary
            }
            StyledText {
                text: "only with shift"
                dim: true
                font.pixelSize: Theme.size.small
            }
        }

        // Keyboard and arrow keys
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.unit / 2

            Column {
                spacing: root.gap

                Repeater {
                    model: root.keyRows

                    Row {
                        id: keyRow

                        required property var modelData

                        spacing: root.gap

                        Repeater {
                            model: keyRow.modelData

                            Key {
                                required property var modelData

                                spec: modelData
                                unit: root.unit
                                gap: root.gap
                                lit: root.plain(modelData[1])
                                marked: !lit && root.shifted(modelData[1])
                                onHover: (keyId, hovering) => root.setHovered(keyId, hovering)
                            }
                        }
                    }
                }
            }

            Column {
                Layout.alignment: Qt.AlignBottom
                spacing: root.gap

                Repeater {
                    model: root.arrowRows

                    Row {
                        id: arrowRow

                        required property var modelData

                        spacing: root.gap

                        Repeater {
                            model: arrowRow.modelData

                            Key {
                                required property var modelData

                                spec: modelData
                                unit: root.unit
                                gap: root.gap
                                lit: root.plain(modelData[1])
                                marked: !lit && root.shifted(modelData[1])
                                onHover: (keyId, hovering) => root.setHovered(keyId, hovering)
                            }
                        }
                    }
                }
            }
        }

        // What the hovered key does
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: height / 2
            color: root.hovered === "" ? Theme.container : Theme.secondaryContainer

            Behavior on color {
                ColorAnim {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 16
                spacing: Theme.spacing.normal

                Icon {
                    icon: root.hovered === "" ? "mouse" : "info"
                    size: Theme.icon.small
                    dim: root.hovered === ""
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.hoverText
                    dim: root.hovered === ""
                    font.pixelSize: Theme.size.small
                }
            }
        }

        // All binds by group: four columns, so the card also fits a 1080p screen
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: Theme.spacing.medium
            rowSpacing: Theme.spacing.medium

            Repeater {
                model: Binds.groupOrder.filter(g => Binds.inGroup(g).length > 0)

                Card {
                    id: group

                    required property string modelData
                    readonly property var rows: Binds.inGroup(modelData)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 360

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: Theme.spacing.small + 2

                        StyledText {
                            Layout.bottomMargin: Theme.spacing.small
                            text: group.modelData
                            color: Theme.primary
                            font.pixelSize: Theme.size.small
                            font.weight: Font.DemiBold
                            font.capitalization: Font.Capitalize
                        }

                        Repeater {
                            model: group.rows.slice(0, root.maxRows)

                            RowLayout {
                                id: bindRow

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Theme.spacing.small

                                Repeater {
                                    model: root.capsOf(bindRow.modelData)

                                    KeyCap {
                                        required property string modelData

                                        text: modelData
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Theme.spacing.small
                                    text: bindRow.modelData.label
                                    font.pixelSize: Theme.size.small
                                }

                                StyledText {
                                    text: bindRow.modelData.source
                                    color: bindRow.modelData.source === "frame" ? Theme.primary : Theme.dim
                                    font.pixelSize: Theme.size.tiny - 1
                                }
                            }
                        }

                        StyledText {
                            visible: group.rows.length > root.maxRows
                            text: `+ ${group.rows.length - root.maxRows} more`
                            dim: true
                            font.pixelSize: Theme.size.tiny
                        }
                    }
                }
            }
        }

        StyledText {
            visible: !Binds.loaded
            text: "reading binds from hyprctl …"
            dim: true
        }

        StyledText {
            text: "release super to close · read live from hyprctl binds; descriptions come from the binds"
            dim: true
            font.pixelSize: Theme.size.tiny
        }
    }
}
