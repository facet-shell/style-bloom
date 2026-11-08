import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.components
import qs.config
import qs.services
import qs.settings

ColumnLayout {
    id: root

    property string output: "*"
    property string projectPath: ""
    property string section: "all"
    readonly property var common: Wallpapers.globalOptions()
    readonly property var properties: Wallpapers.propertiesFor(output, projectPath)
    spacing: Theme.spacing.small

    function refresh() { Wallpapers.refreshSceneSettings(output, projectPath); }
    onOutputChanged: refresh()
    onProjectPathChanged: refresh()
    Connections {
        target: Wallpapers
        function onGlintStatusChanged() { root.refresh(); }
    }

    component Choice: Controls.ComboBox {
        id: choice
        implicitHeight: 36
        leftPadding: 14
        rightPadding: 38
        font.family: Theme.font
        font.pixelSize: Theme.size.small
        background: Rectangle {
            radius: height / 2
            color: choice.hovered ? Theme.highest : Theme.high
            border.width: choice.visualFocus ? 2 : 0
            border.color: Theme.primary
        }
        contentItem: Text {
            text: choice.displayText
            font: choice.font
            color: Theme.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Icon {
            x: choice.width - width - 12
            anchors.verticalCenter: parent.verticalCenter
            icon: choice.popup.visible ? "expand_less" : "expand_more"
            size: Theme.icon.small
            color: choice.visualFocus ? Theme.primary : Theme.dim
        }
        delegate: Controls.ItemDelegate {
            required property int index
            width: choice.width - 12
            implicitHeight: 36
            highlighted: choice.highlightedIndex === index
            contentItem: Text {
                text: choice.textAt(index)
                font: choice.font
                color: highlighted ? Theme.primary : Theme.text
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: 10
            }
            background: Rectangle {
                radius: Theme.rounding.normal
                color: parent.highlighted ? Theme.primaryContainer : parent.hovered ? Theme.highest : "transparent"
            }
        }
        popup: Controls.Popup {
            y: choice.height + 6
            width: choice.width
            padding: 6
            implicitHeight: Math.min(contentItem.implicitHeight + 12, 220)
            contentItem: ListView {
                implicitHeight: contentHeight
                clip: true
                model: choice.popup.visible ? choice.delegateModel : null
                currentIndex: choice.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
            }
            background: Rectangle {
                radius: Theme.rounding.normal
                color: Theme.container
                border.color: Theme.outline
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !Wallpapers.glintActive
        StyledText {
            Layout.fillWidth: true
            text: "Glint is not connected"
            dim: true
        }
        Button {
            icon: "play_arrow"
            text: "start engine"
            onClicked: Wallpapers.startGlint()
        }
    }

    // ── Engine: every display and wallpaper ──────────────────

    StyledText {
        visible: root.section !== "wallpaper"
        Layout.fillWidth: true
        text: root.output === "*" ? "For every display and wallpaper" : `For ${root.output}, every wallpaper`
        dim: true
        font.pixelSize: Theme.size.small
    }

    ColumnLayout {
        objectName: "glintGeneralSettings"
        Layout.fillWidth: true
        spacing: 4
        visible: root.section !== "wallpaper"
        enabled: Wallpapers.glintActive && root.common.count > 0
        opacity: enabled ? 1 : 0.5

        SettingRow {
            Layout.fillWidth: true
            icon: "speed"
            title: "Frame rate"
            subtitle: root.common.mixed.fps ? "differs between the displays" : "auto follows the display"

            SegmentedButtons {
                readonly property var rates: {
                    const list = ["0", "30", "60", "120"];
                    const now = String(root.common.fps);
                    return !root.common.mixed.fps && !list.includes(now) ? list.concat([now]) : list;
                }
                model: rates.map(r => ({ key: r, label: r === "0" ? "auto" : r }))
                current: root.common.mixed.fps ? "" : String(root.common.fps)
                onSelected: key => Wallpapers.setDisplaySetting(root.output, "fps", Number(key))
            }
        }

        SettingRow {
            Layout.fillWidth: true
            icon: "aspect_ratio"
            title: "Scaling"
            subtitle: root.common.mixed.scaling ? "differs between the displays" : "how it meets the screen"

            SegmentedButtons {
                model: ["fill", "fit", "center", "tile", "stretch"]
                current: root.common.mixed.scaling ? "" : root.common.scaling
                onSelected: key => Wallpapers.setDisplaySetting(root.output, "scaling", key)
            }
        }

        SettingRow {
            Layout.fillWidth: true
            icon: root.common.volume > 0 ? "volume_up" : "volume_off"
            title: "Sound"
            subtitle: "of wallpapers that play some"

            RowLayout {
                spacing: Theme.spacing.small

                Slider {
                    id: volume

                    property real staged: root.common.volume

                    Layout.preferredWidth: 180
                    thin: true
                    value: volumeSave.running ? staged : root.common.volume
                    onMoved: v => {
                        staged = v;
                        volumeSave.restart();
                    }

                    Timer {
                        id: volumeSave
                        interval: 250
                        onTriggered: Wallpapers.setDisplaySettings(root.output, { volume: volume.staged, mute: false })
                    }
                }
                StyledText {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    tabular: true
                    text: root.common.mixed.volume ? "mixed" : `${Math.round((volumeSave.running ? volume.staged : root.common.volume) * 100)} %`
                    font.pixelSize: Theme.size.small
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            icon: "blur_on"
            title: "Fade between wallpapers"
            subtitle: root.common.transition === "fade" ? "how long the fade takes" : "off: the new one is there at once"

            RowLayout {
                spacing: Theme.spacing.medium

                SegmentedButtons {
                    visible: root.common.transition === "fade"
                    readonly property var lengths: {
                        const list = ["300", "600", "1000", "2000"];
                        const now = String(root.common.duration);
                        return !root.common.mixed.duration && !list.includes(now) ? list.concat([now]).sort((a, b) => a - b) : list;
                    }
                    model: lengths.map(ms => ({ key: ms, label: Number(ms) >= 1000 ? `${Number(ms) / 1000} s` : `${ms} ms` }))
                    current: root.common.mixed.duration ? "" : String(root.common.duration)
                    onSelected: key => Wallpapers.setDisplaySetting(root.output, "duration", Number(key))
                }
                Switch {
                    checked: root.common.transition === "fade"
                    onToggled: on => Wallpapers.setDisplaySetting(root.output, "transition", on ? "fade" : "none")
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            icon: "format_color_fill"
            title: "Background"
            subtitle: "around a wallpaper that does not fill the screen"

            RowLayout {
                spacing: Theme.spacing.small

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 11
                    color: /^#[0-9a-f]{6}$/i.test(backgroundField.text) ? backgroundField.text : "transparent"
                    border.width: 1
                    border.color: Theme.outline
                }
                TextBox {
                    id: backgroundField

                    Layout.preferredWidth: 110
                    placeholder: root.common.mixed.color ? "mixed" : "#000000"
                    Binding {
                        target: backgroundField
                        property: "text"
                        when: !backgroundField.input.activeFocus
                        value: root.common.mixed.color ? "" : root.common.color
                    }
                    onAccepted: Wallpapers.setDisplaySetting(root.output, "color", text)
                }
            }
        }
    }

    // ── This wallpaper: the project's own properties ─────────

    StyledText {
        Layout.fillWidth: true
        visible: root.section !== "general"
        text: root.properties.length ? `Its own options${root.output === "*" ? "" : ` on ${root.output}`}`
            : "Apply this wallpaper first, then its own options show up here"
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.Wrap
    }

    ColumnLayout {
        visible: root.section !== "general"
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: root.properties

            SettingRow {
                id: setting

                required property var modelData

                Layout.fillWidth: true
                title: Wallpapers.propertyLabel(setting.modelData)
                subtitle: setting.modelData.mixed ? "differs between the displays" : ""

                // One child for the row's slot; the controls that do not fit the type hide
                RowLayout {
                    spacing: Theme.spacing.small

                    Switch {
                        visible: setting.modelData.type === "bool"
                        checked: setting.modelData.value === true && !setting.modelData.mixed
                        onToggled: on => Wallpapers.setSceneSetting(root.output, setting.modelData.name, on, root.projectPath)
                    }
                    RowLayout {
                        visible: setting.modelData.type === "slider"
                        spacing: Theme.spacing.small

                        Slider {
                            id: slider

                            property real lower: Number(setting.modelData.min ?? 0)
                            property real upper: Number(setting.modelData.max ?? 1)
                            property real staged: Number(setting.modelData.value ?? 0)

                            Layout.preferredWidth: 180
                            thin: true
                            value: upper > lower ? ((save.running ? staged : Number(setting.modelData.value)) - lower) / (upper - lower) : 0
                            onMoved: v => {
                                const step = Number(setting.modelData.step ?? 0);
                                let next = lower + v * (upper - lower);
                                if (step > 0)
                                    next = lower + Math.round((next - lower) / step) * step;
                                staged = Math.max(lower, Math.min(upper, next));
                                save.restart();
                            }

                            Timer {
                                id: save
                                interval: 150
                                onTriggered: Wallpapers.setSceneSetting(root.output, setting.modelData.name, slider.staged, root.projectPath)
                            }
                        }
                        StyledText {
                            Layout.preferredWidth: 44
                            horizontalAlignment: Text.AlignRight
                            tabular: true
                            text: setting.modelData.mixed ? "mixed" : String(Math.round((save.running ? slider.staged : Number(setting.modelData.value)) * 100) / 100)
                            font.pixelSize: Theme.size.small
                        }
                    }
                    Choice {
                        visible: setting.modelData.type === "combo"
                        Layout.preferredWidth: 220
                        model: setting.modelData.options ?? []
                        textRole: "label"
                        currentIndex: setting.modelData.mixed ? -1 : model.findIndex(o => JSON.stringify(o.value) === JSON.stringify(setting.modelData.value))
                        displayText: currentIndex < 0 ? "mixed" : currentText
                        onActivated: index => Wallpapers.setSceneSetting(root.output, setting.modelData.name, model[index].value, root.projectPath)
                    }
                    RowLayout {
                        visible: ["color", "textinput", "file", "directory", "scenetexture"].includes(setting.modelData.type)
                        spacing: Theme.spacing.small

                        // Wallpaper Engine colors are "r g b" from 0 to 1
                        Rectangle {
                            visible: setting.modelData.type === "color"
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: {
                                const c = String(setting.modelData.value ?? "").trim().split(/\s+/).map(Number);
                                return c.length >= 3 && c.every(n => !isNaN(n)) ? Qt.rgba(c[0], c[1], c[2], 1) : "transparent";
                            }
                            border.width: 1
                            border.color: Theme.outline
                        }
                        TextBox {
                            id: textField

                            Layout.preferredWidth: 200
                            Binding {
                                target: textField
                                property: "text"
                                when: !textField.input.activeFocus
                                value: setting.modelData.mixed ? "" : String(setting.modelData.value ?? "")
                            }
                            placeholder: setting.modelData.mixed ? "mixed" : ""
                            onAccepted: Wallpapers.setSceneSetting(root.output, setting.modelData.name, text, root.projectPath)
                        }
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Wallpapers.glintError !== ""
        text: Wallpapers.glintError
        color: Theme.error
        font.pixelSize: Theme.size.small
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
