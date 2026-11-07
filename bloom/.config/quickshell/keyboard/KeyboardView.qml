import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The keyboard app's content: the device and the tabs the board can do on top (lighting, fn
// keys, colors), the picked board drawn with round keys (its rows come from the board registry,
// facet-keyboard board --json), the tab's controls, and what the last command sent (in a dry
// run: would have sent). Keys carry their physical id (US names) and a QWERTZ label.
FocusScope {
    id: root

    signal closeRequested()

    property string tab: "lighting"

    // lighting
    property string effectName: ""
    property int brightness: 4
    property int speed: 2
    // "" = leave as it is, "0".."6" = factory slot, "multi", or "#rrggbb"
    property string effectColor: ""

    // fn keys
    property string selected: ""
    property string action: ""

    // colors: pending changes { id: "#rrggbb" } on top of what the keyboard has
    property var painted: ({})
    property string paintColor: Theme.primary.toString()
    property int keyBrightness: 4

    // Key size: 48 px, smaller for boards wider than the window (a full-size F99)
    readonly property real rowUnits: Math.max(1, ...keyRows.map(r => r.reduce((sum, k) => sum + k[2], 0)))
    readonly property int unit: Math.max(28, Math.min(48, Math.floor((width - 80) / rowUnits)))
    readonly property int gap: 5

    // [label, physical key id, width in keys] from the board file; the AULA F75 until it is read
    readonly property var keyRows: Keyboard.keyRows.length > 0 ? Keyboard.keyRows : fallbackRows
    readonly property var fallbackRows: [
        [["esc", "esc", 1], ["", "", 0.5], ["F1", "f1", 1], ["F2", "f2", 1], ["F3", "f3", 1], ["F4", "f4", 1], ["", "", 0.5],
         ["F5", "f5", 1], ["F6", "f6", 1], ["F7", "f7", 1], ["F8", "f8", 1], ["", "", 0.5],
         ["F9", "f9", 1], ["F10", "f10", 1], ["F11", "f11", 1], ["F12", "f12", 1], ["", "", 0.5], ["◉", "knob", 1]],
        [["^", "grave", 1], ["1", "1", 1], ["2", "2", 1], ["3", "3", 1], ["4", "4", 1], ["5", "5", 1], ["6", "6", 1],
         ["7", "7", 1], ["8", "8", 1], ["9", "9", 1], ["0", "0", 1], ["ß", "minus", 1], ["´", "equal", 1],
         ["⌫", "backspace", 2], ["del", "delete", 1]],
        [["tab", "tab", 1.5], ["Q", "q", 1], ["W", "w", 1], ["E", "e", 1], ["R", "r", 1], ["T", "t", 1], ["Z", "y", 1],
         ["U", "u", 1], ["I", "i", 1], ["O", "o", 1], ["P", "p", 1], ["Ü", "bracketleft", 1], ["+", "bracketright", 1],
         ["#", "backslash", 1.5], ["pgup", "prior", 1]],
        [["caps", "caps_lock", 1.75], ["A", "a", 1], ["S", "s", 1], ["D", "d", 1], ["F", "f", 1], ["G", "g", 1], ["H", "h", 1],
         ["J", "j", 1], ["K", "k", 1], ["L", "l", 1], ["Ö", "semicolon", 1], ["Ä", "apostrophe", 1], ["⏎", "return", 2.25],
         ["pgdn", "next", 1]],
        [["shift", "shift_l", 2.25], ["Y", "z", 1], ["X", "x", 1], ["C", "c", 1], ["V", "v", 1], ["B", "b", 1], ["N", "n", 1],
         ["M", "m", 1], [",", "comma", 1], [".", "period", 1], ["-", "slash", 1], ["shift", "shift_r", 1.75], ["↑", "up", 1],
         ["end", "end", 1]],
        [["ctrl", "control_l", 1.25], ["super", "super_l", 1.25], ["alt", "alt_l", 1.25], ["space", "space", 6.25],
         ["fn", "fn", 1.25], ["ctrl", "control_r", 1.25], ["", "", 0.5], ["←", "left", 1], ["↓", "down", 1], ["→", "right", 1]]
    ]
    readonly property var labels: {
        const out = {};
        for (const row of keyRows)
            for (const k of row)
                if (k[1] !== "")
                    out[k[1]] = k[0];
        return out;
    }

    // LED colors for the board, not UI colors: the factory color table slots 0–6 (as on the
    // L65) and a few plain ones to paint with
    readonly property var slotColors: ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", "#ffffff"]
    readonly property var named: ({ red: "#ff0000", green: "#00ff00", blue: "#0000ff", white: "#ffffff", off: "#000000" })
    // The theme's colors go onto the board as they are
    readonly property var roles: ["primary", "secondary", "tertiary", "text", "error", "warn", "ok"]

    readonly property var effectSpec: Keyboard.effects.find(e => e.name === effectName) ?? null
    readonly property var keyInfo: selected === "" ? null : Keyboard.info?.keys?.[selected] ?? null

    function reset() {
        selected = "";
        setAction("");
        painted = {};
        loadEffect(Keyboard.info?.effect ?? "");
        forceActiveFocus();
    }

    function loadEffect(name) {
        effectName = name;
        effectColor = "";
        const saved = Keyboard.info?.effects?.[name];
        if (saved) {
            brightness = saved.brightness;
            speed = saved.speed;
        }
    }

    function roleColor(role) {
        return Theme[role].toString();
    }

    function keyColor(id) {
        // Unknown keys show as unlit
        return painted[id] ?? Keyboard.info?.colors?.[id] ?? "#000000";
    }

    // Light or dark text, whatever the paint under it (c is a color property)
    function inkOn(c) {
        return c.hslLightness > 0.55 ? Theme.page : Theme.textOnScrim;
    }

    function setAction(text) {
        action = text;
        actionField.text = text;
    }

    function clickKey(id) {
        if (tab === "keys") {
            selected = id;
            setAction("");
        } else if (tab === "colors") {
            painted = Object.assign({}, painted, { [id]: paintColor });
        }
    }

    function applyLighting() {
        if (effectName === "")
            return;
        Keyboard.effect(effectName, brightness, effectSpec?.speed ? speed : -1, effectSpec?.color ? effectColor : "");
    }

    function applyAction() {
        if (selected === "" || selected === "fn" || action.trim() === "")
            return;
        if (action === "factory")
            Keyboard.resetKeys([selected]);
        else
            Keyboard.assign([`${selected}=${action.trim()}`]);
        setAction("");
    }

    function fillAll() {
        const out = {};
        for (const id in labels)
            out[id] = paintColor;
        painted = out;
    }

    Keys.onEscapePressed: root.closeRequested()

    // The lighting tab follows the keyboard until an effect is picked
    Connections {
        target: Keyboard

        function onInfoChanged() {
            if (root.effectName === "")
                root.loadEffect(Keyboard.info?.effect ?? "");
        }
    }

    // ── Building blocks ──────────────────────────────────────

    // The name in front of a row of controls
    component RowLabel: StyledText {
        dim: true
        font.pixelSize: Theme.size.small
        Layout.preferredWidth: 104
    }

    // A panel on the window's dark page
    component Panel: Rectangle {
        radius: Theme.rounding.large
        color: Theme.surface
    }

    // A round color to pick; the picked one gets a ring in the accent
    component Swatch: Item {
        id: swatch

        property color swatchColor: "transparent"
        property string label: ""
        property bool selected: false

        signal clicked()

        implicitWidth: 34
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            opacity: swatch.selected ? 1 : 0
            scale: swatch.selected ? 1 : 0.8

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
            anchors.fill: parent
            anchors.margins: 5
            radius: width / 2
            color: swatch.swatchColor
            border.width: 1
            border.color: Theme.outline
            scale: swatchArea.pressed ? 0.85 : swatchArea.containsMouse ? 1.08 : 1

            Behavior on scale {
                SpringAnim {}
            }

            StyledText {
                anchors.centerIn: parent
                text: swatch.label
                color: root.inkOn(swatch.swatchColor)
                font.pixelSize: Theme.size.tiny - 1
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: swatchArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swatch.clicked()
        }
    }

    // A pill field for an own color, "#rrggbb" and Enter
    component HexField: Rectangle {
        id: hex

        signal picked(string color)

        implicitWidth: 120
        implicitHeight: Theme.control.chip
        radius: height / 2
        color: hexInput.activeFocus ? Theme.highest : Theme.high

        Behavior on color {
            ColorAnim {}
        }

        TextInput {
            id: hexInput

            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            selectionColor: Theme.primaryContainer
            font.family: Theme.mono
            font.pixelSize: Theme.size.small
            maximumLength: 7
            clip: true
            onAccepted: {
                const t = text.trim().replace(/^#?/, "#");
                if (/^#[0-9a-fA-F]{6}$/.test(t)) {
                    hex.picked(t.toLowerCase());
                    text = "";
                }
            }
            Keys.onEscapePressed: root.closeRequested()

            StyledText {
                anchors.fill: parent
                visible: hexInput.text === ""
                text: "#rrggbb ⏎"
                dim: true
                opacity: 0.7
                font.family: Theme.mono
                font.pixelSize: Theme.size.small
            }
        }
    }

    // Whole steps 0..max on a thin slider, the value beside it
    component Steps: RowLayout {
        id: steps

        property string title: ""
        property int max: 9
        property int value: 0

        signal picked(int value)

        spacing: Theme.spacing.medium

        RowLabel {
            text: steps.title
        }
        Slider {
            Layout.fillWidth: true
            thin: true
            step: 1 / steps.max
            value: steps.value / steps.max
            onMoved: v => steps.picked(Math.round(v * steps.max))
        }
        StyledText {
            text: `${steps.value}/${steps.max}`
            tabular: true
            font.pixelSize: Theme.size.small
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 40
        }
    }

    // One key of the board
    component Key: Rectangle {
        id: key

        property var spec: ["", "", 1]
        readonly property string keyId: spec[1]
        readonly property bool isFn: keyId === "fn"
        readonly property bool hasAction: root.tab === "keys" && Keyboard.layer !== "base" && !!Keyboard.info?.keys?.[keyId]
        readonly property bool isSelected: root.tab === "keys" && root.selected === keyId
        readonly property bool isPainted: root.tab === "colors" && root.painted[keyId] !== undefined
        readonly property color paint: root.keyColor(keyId)
        readonly property bool clickable: root.tab !== "lighting"

        anchors.fill: parent
        visible: keyId !== ""
        radius: Theme.rounding.normal
        color: root.tab === "colors" ? paint
            : hasAction ? Theme.primary
            : keyArea.containsMouse && clickable ? Theme.highest
            : Theme.high
        scale: keyArea.pressed && clickable ? 0.9 : 1

        Behavior on color {
            ColorAnim {}
        }
        Behavior on scale {
            SpringAnim {}
        }

        // The picked key (fn keys) or a key painted but not written yet (colors)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: key.isSelected ? Theme.text : Theme.secondary
            opacity: key.isSelected || key.isPainted ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.small
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: key.spec[0]
            color: root.tab === "colors" ? root.inkOn(key.paint)
                : key.hasAction ? Theme.textOnPrimary
                : key.isFn && root.tab === "keys" ? Theme.tertiary
                : Theme.dim
            font.pixelSize: key.spec[0].length > 2 ? Theme.size.tiny - 1 : Theme.size.normal
            font.weight: key.hasAction ? Font.Medium : Font.Normal
        }

        MouseArea {
            id: keyArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: key.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.clickKey(key.keyId)
        }
    }

    // ── Layout ───────────────────────────────────────────────

    // The window: dark page, rounded; swallows clicks so they do not close it
    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.drawer
        color: Theme.page

        MouseArea {
            anchors.fill: parent
            onClicked: root.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding.drawer
        spacing: Theme.spacing.medium

        // Device, tabs, dry run or live, close
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: height / 2
                color: Theme.primaryContainer

                Icon {
                    anchors.centerIn: parent
                    icon: "keyboard"
                    color: Theme.textOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Keyboard.boardName
                    font.pixelSize: Theme.size.medium
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    dim: true
                    font.pixelSize: Theme.size.small
                    text: !Keyboard.available ? "facet-keyboard is not in ~/.local/bin (facet add keyboard)"
                        : Keyboard.connected ? `usb cable${Keyboard.info?.node ? " · " + Keyboard.info.node : ""}`
                        : Keyboard.dongleOnly ? "only the 2.4 GHz dongle is there · plug the cable in"
                        : "not on the USB cable · another board: facet keyboard set"
                }
            }

            Tabs {
                // Only what the board can do
                model: [
                    { key: "lighting", label: "Lighting", icon: "light_mode", on: Keyboard.can.effects },
                    { key: "keys", label: "Fn keys", icon: "keyboard_command_key", on: Keyboard.can.fn },
                    { key: "colors", label: "Colors", icon: "palette", on: Keyboard.can.perkey }
                ].filter(t => t.on)
                current: root.tab
                onSelected: key => {
                    root.tab = key;
                    root.selected = "";
                }
            }

            // Off: facet-keyboard only prints what it would send
            RowLayout {
                spacing: Theme.spacing.normal

                StyledText {
                    text: Keyboard.live ? "live" : "dry run"
                    color: Keyboard.live ? Theme.error : Theme.dim
                    font.pixelSize: Theme.size.small
                }
                Switch {
                    checked: Keyboard.live
                    onToggled: on => Keyboard.setLive(on)
                }
            }

            IconButton {
                icon: "close"
                onClicked: root.closeRequested()
            }
        }

        // Why nothing happens on the board
        Rectangle {
            Layout.fillWidth: true
            visible: warning.text !== ""
            implicitHeight: warning.implicitHeight + Theme.padding.small * 2
            radius: Theme.rounding.normal
            color: Keyboard.error !== "" ? Theme.errorContainer : Theme.container

            RowLayout {


                anchors.fill: parent
                anchors.leftMargin: Theme.padding.normal
                anchors.rightMargin: Theme.padding.normal
                spacing: Theme.spacing.normal

                Icon {
                    icon: Keyboard.error !== "" ? "error" : "science"
                    size: Theme.icon.small
                    color: Keyboard.error !== "" ? Theme.textOnErrorContainer : Theme.warn
                }
                StyledText {
                    id: warning

                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.size.small
                    color: Keyboard.error !== "" ? Theme.textOnErrorContainer : Theme.text
                    text: Keyboard.error !== "" ? Keyboard.error
                        : Keyboard.info?.dry ? "Dry run: placeholder data, nothing is sent · the log at the bottom shows the packets"
                        : ""
                }
            }
        }

        // The board
        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: board.implicitHeight + Theme.padding.card * 2 + 8

            Column {
                id: board

                anchors.centerIn: parent
                spacing: root.gap

                Repeater {
                    model: root.keyRows

                    Row {
                        id: keyRow

                        required property var modelData

                        spacing: root.gap

                        Repeater {
                            model: keyRow.modelData

                            // Gaps stay in the row as empty space; Row skips invisible items
                            Item {
                                id: slot

                                required property var modelData

                                width: modelData[2] * root.unit - root.gap
                                height: root.unit - root.gap

                                Key {
                                    spec: slot.modelData
                                }
                            }
                        }
                    }
                }
            }
        }

        // The tab's controls
        Panel {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── lighting ──
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding.card + 2
                visible: root.tab === "lighting"
                spacing: Theme.spacing.medium

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    Repeater {
                        model: Keyboard.effects

                        Chip {
                            required property var modelData

                            text: modelData.name
                            selected: root.effectName === modelData.name
                            onClicked: root.loadEffect(modelData.name)
                        }
                    }
                }

                Steps {
                    Layout.fillWidth: true
                    title: "brightness"
                    max: Keyboard.can.brightness ?? 9
                    value: Math.min(root.brightness, max)
                    onPicked: v => root.brightness = v
                }

                Steps {
                    Layout.fillWidth: true
                    visible: root.effectSpec?.speed ?? false
                    title: "speed"
                    max: Keyboard.can.speed ?? 4
                    value: Math.min(root.speed, max)
                    onPicked: v => root.speed = v
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.effectSpec?.color ?? false
                    spacing: Theme.spacing.medium

                    RowLabel {
                        text: "color"
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 8
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        Repeater {
                            model: root.slotColors

                            Swatch {
                                required property string modelData
                                required property int index

                                swatchColor: modelData
                                label: String(index)
                                selected: root.effectColor === String(index)
                                onClicked: root.effectColor = String(index)
                            }
                        }

                        Chip {
                            text: "multi"
                            icon: "gradient"
                            selected: root.effectColor === "multi"
                            onClicked: root.effectColor = "multi"
                        }

                        Repeater {
                            model: ["primary", "secondary", "tertiary"]

                            Swatch {
                                required property string modelData

                                swatchColor: root.roleColor(modelData)
                                selected: root.effectColor === root.roleColor(modelData)
                                onClicked: root.effectColor = root.roleColor(modelData)
                            }
                        }

                        HexField {
                            onPicked: c => root.effectColor = c
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        dim: true
                        font.pixelSize: Theme.size.small
                        text: root.effectColor.startsWith("#")
                            ? `Own color ${root.effectColor} goes into slot 0 of ${root.effectName}`
                            : `On the keyboard now: ${Keyboard.info?.effect ?? "?"}`
                    }

                    Button {
                        text: "apply"
                        icon: "check"
                        variant: "filled"
                        disabled: root.effectName === "" || Keyboard.busy
                        onClicked: root.applyLighting()
                    }
                }
            }

            // ── fn keys ──
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding.card + 2
                visible: root.tab === "keys"
                spacing: Theme.spacing.medium

                RowLayout {
                    spacing: Theme.spacing.medium

                    RowLabel {
                        text: "layer"
                    }
                    SegmentedButtons {
                        model: [{ key: "fn1", label: "with fn" }, { key: "fn2", label: "fn 2" }, { key: "base", label: "without fn" }]
                            .filter(l => (Keyboard.can.layers ?? []).includes(l.key))
                        current: Keyboard.layer
                        onSelected: key => {
                            root.selected = "";
                            Keyboard.setLayer(key);
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.selected === "" ? "Click a key on the board"
                        : root.selected === "fn" ? "fn stays fn (otherwise there is no way back to this layer)"
                        : `${root.labels[root.selected]}: ${root.keyInfo ? root.keyInfo.text + "  ·  " + root.keyInfo.bytes : "nothing"}`
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.selected !== "" && root.selected !== "fn"
                    spacing: Theme.spacing.medium

                    RowLabel {
                        text: "does"
                    }
                    SearchField {
                        id: actionField

                        Layout.fillWidth: true
                        implicitHeight: Theme.control.button + 4
                        baseColor: Theme.container
                        icon: "keyboard_command_key"
                        placeholder: "a key or combo: f5, ctrl+alt+t, super+z … or pick one below"
                        onTextChanged: root.action = text
                        onAccepted: root.applyAction()
                        onEscaped: root.closeRequested()
                        // The field asks for focus by itself; here the window keeps it (Esc)
                        // until the field is clicked
                        Component.onCompleted: input.focus = false
                    }
                    Button {
                        text: "assign"
                        icon: "check"
                        variant: "filled"
                        disabled: root.action.trim() === "" || Keyboard.busy
                        onClicked: root.applyAction()
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.selected !== "" && root.selected !== "fn"
                    spacing: Theme.spacing.small

                    Repeater {
                        model: Keyboard.actions.media.concat(Keyboard.actions.lighting).concat(
                            Keyboard.layer === "fn1" ? ["none", "factory"] : ["none"])

                        Chip {
                            required property string modelData

                            text: modelData
                            compact: true
                            icon: modelData === "factory" ? "restart_alt" : ""
                            selected: root.action === modelData
                            onClicked: root.setAction(modelData)
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    dim: true
                    font.pixelSize: Theme.size.small
                    text: Keyboard.layer === "base"
                        ? "Without fn: this changes what the key does normally"
                        : "Lit keys do something together with fn · factory puts the maker's default back"
                }
            }

            // ── colors ──
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding.card + 2
                visible: root.tab === "colors"
                spacing: Theme.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    RowLabel {
                        text: "paint"
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 8
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        Repeater {
                            model: root.roles

                            Swatch {
                                required property string modelData

                                swatchColor: root.roleColor(modelData)
                                selected: root.paintColor === root.roleColor(modelData)
                                onClicked: root.paintColor = root.roleColor(modelData)
                            }
                        }

                        Repeater {
                            model: Object.keys(root.named)

                            Swatch {
                                required property string modelData

                                swatchColor: root.named[modelData]
                                label: modelData === "off" ? "off" : ""
                                selected: root.paintColor === root.named[modelData]
                                onClicked: root.paintColor = root.named[modelData]
                            }
                        }

                        HexField {
                            onPicked: c => root.paintColor = c
                        }
                    }
                }

                RowLayout {
                    spacing: Theme.spacing.normal

                    RowLabel {
                        text: "keys"
                    }
                    Chip {
                        text: "fill all"
                        icon: "format_color_fill"
                        onClicked: root.fillAll()
                    }
                    Chip {
                        text: "undo changes"
                        icon: "undo"
                        onClicked: root.painted = {}
                    }
                    StyledText {
                        Layout.leftMargin: Theme.spacing.large
                        text: "from the theme"
                        dim: true
                        font.pixelSize: Theme.size.small
                    }

                    Repeater {
                        model: ["solid", "split", "rows"]

                        Chip {
                            required property string modelData

                            text: modelData
                            onClicked: {
                                root.painted = {};
                                Keyboard.style(modelData, root.keyBrightness);
                            }
                        }
                    }
                }

                Steps {
                    Layout.fillWidth: true
                    title: "brightness"
                    max: Keyboard.can.brightness ?? 9
                    value: Math.min(root.keyBrightness, max)
                    onPicked: v => root.keyBrightness = v
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        dim: true
                        font.pixelSize: Theme.size.small
                        text: `Click keys to paint them · ${Object.keys(root.painted).length} changed · `
                            + "the colors are saved on the keyboard, so write them when you are done"
                    }

                    Button {
                        text: "write colors"
                        icon: "save"
                        variant: "filled"
                        disabled: Object.keys(root.painted).length === 0 || Keyboard.busy
                        onClicked: {
                            Keyboard.paint(root.painted, root.keyBrightness);
                            root.painted = {};
                        }
                    }
                }
            }
        }

        // What the last command sent (dry run: would have sent)
        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            color: Theme.surface

            StyledText {
                id: logTitle

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: Theme.padding.card
                anchors.topMargin: Theme.padding.normal
                text: Keyboard.busy ? "working …" : Keyboard.live ? "last command" : "last command · dry run"
                dim: true
                font.pixelSize: Theme.size.tiny
            }

            Flickable {
                id: logView

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: logTitle.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.padding.card
                anchors.rightMargin: Theme.padding.card
                anchors.topMargin: Theme.spacing.small
                anchors.bottomMargin: Theme.padding.normal
                clip: true
                contentHeight: logText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: logText

                    width: logView.width
                    text: Keyboard.log === "" ? "nothing yet" : Keyboard.log
                    color: Theme.secondary
                    font.family: Theme.mono
                    font.pixelSize: Theme.size.tiny - 1
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
