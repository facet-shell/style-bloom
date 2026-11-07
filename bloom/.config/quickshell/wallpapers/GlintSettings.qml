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

    StyledText {
        visible: root.section !== "wallpaper"
        Layout.fillWidth: true
        text: "Global settings · all displays and wallpapers"
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.Wrap
    }

    GridLayout {
        objectName: "glintGeneralSettings"
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.spacing.medium
        rowSpacing: Theme.spacing.medium
        visible: root.section !== "wallpaper"
        enabled: Wallpapers.glintActive && root.common.count > 0
        opacity: enabled ? 1 : 0.5

        StyledText {
            Layout.preferredWidth: 100
            text: "FPS"
            dim: true
            font.pixelSize: Theme.size.small
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            TextBox {
                id: fpsField
                Layout.preferredWidth: 84
                Layout.minimumWidth: 84
                Layout.maximumWidth: 84
                Binding {
                    target: fpsField
                    property: "text"
                    when: !fpsField.input.activeFocus
                    value: root.common.mixed.fps ? "" : String(root.common.fps)
                }
                placeholder: root.common.mixed.fps ? "mixed" : "0 = auto"
                input.validator: IntValidator { bottom: 0; top: 1000 }
                onAccepted: {
                    if (text !== "" && input.acceptableInput)
                        Wallpapers.setDisplaySetting(root.output, "fps", Number(text));
                }
            }
            StyledText { Layout.fillWidth: true; text: "0 = display rate"; dim: true; wrapMode: Text.Wrap; font.pixelSize: Theme.size.tiny }
        }

        StyledText {
            Layout.preferredWidth: 100
            text: "Scaling"
            dim: true
            font.pixelSize: Theme.size.small
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            Choice {
                objectName: "glintScalingChoice"
                Layout.fillWidth: true
                Layout.maximumWidth: 220
                model: ["fill", "fit", "center", "tile", "stretch"]
                currentIndex: root.common.mixed.scaling ? -1 : model.indexOf(root.common.scaling)
                displayText: currentIndex < 0 ? "mixed" : currentText
                onActivated: index => Wallpapers.setDisplaySetting(root.output, "scaling", model[index])
            }
        }

        StyledText {
            Layout.preferredWidth: 100
            text: "Sound"
            dim: true
            font.pixelSize: Theme.size.small
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            Slider {
                id: volume
                Layout.fillWidth: true
                Layout.minimumWidth: 60
                Layout.maximumWidth: 220
                thin: true
                property real staged: root.common.volume
                value: volumeSave.running ? staged : root.common.volume
                onMoved: v => { staged = v; volumeSave.restart(); }
                Timer {
                    id: volumeSave
                    interval: 250
                    onTriggered: Wallpapers.setDisplaySettings(root.output, { volume: volume.staged, mute: false })
                }
            }
            StyledText {
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignRight
                text: root.common.mixed.volume ? "mixed" : `${Math.round(root.common.volume * 100)}%`
                font.pixelSize: Theme.size.small
            }
        }

        StyledText {
            Layout.preferredWidth: 100
            text: "Transition"
            dim: true
            font.pixelSize: Theme.size.small
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            Switch {
                checked: root.common.transition === "fade"
                onToggled: on => Wallpapers.setDisplaySetting(root.output, "transition", on ? "fade" : "none")
            }
            TextBox {
                id: durationField
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                placeholder: root.common.mixed.duration ? "mixed" : "ms"
                input.validator: IntValidator { bottom: 0; top: 10000 }
                Binding {
                    target: durationField
                    property: "text"
                    when: !durationField.input.activeFocus
                    value: root.common.mixed.duration ? "" : String(root.common.duration)
                }
                onAccepted: {
                    if (text !== "" && input.acceptableInput)
                        Wallpapers.setDisplaySetting(root.output, "duration", Number(text));
                }
            }
            StyledText { text: "ms"; dim: true; font.pixelSize: Theme.size.small }
        }

        StyledText {
            Layout.preferredWidth: 100
            text: "Background"
            dim: true
            font.pixelSize: Theme.size.small
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            TextBox {
                id: backgroundField
                Layout.fillWidth: true
                Layout.maximumWidth: 220
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

    StyledText {
        Layout.fillWidth: true
        visible: root.section !== "general"
        text: root.properties.length ? "Wallpaper settings · changes apply to matching projects on the selected displays"
            : "Apply this wallpaper on the selected displays to edit its project settings"
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.Wrap
    }

    Flickable {
        visible: root.section !== "general"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(propertiesColumn.implicitHeight, 180)
        contentHeight: propertiesColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: propertiesColumn
            width: parent.width
            spacing: Theme.spacing.small
            Repeater {
                model: root.properties
                RowLayout {
                    id: setting
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium
                    StyledText {
                        Layout.preferredWidth: Math.min(260, root.width * 0.35)
                        text: Wallpapers.propertyLabel(setting.modelData)
                        elide: Text.ElideRight
                        font.pixelSize: Theme.size.small
                    }
                    Switch {
                        visible: setting.modelData.type === "bool"
                        checked: setting.modelData.value === true && !setting.modelData.mixed
                        onToggled: on => Wallpapers.setSceneSetting(root.output, setting.modelData.name, on, root.projectPath)
                    }
                    Slider {
                        id: slider
                        visible: setting.modelData.type === "slider"
                        property real lower: Number(setting.modelData.min ?? 0)
                        property real upper: Number(setting.modelData.max ?? 1)
                        property real staged: Number(setting.modelData.value ?? 0)
                        Layout.preferredWidth: 180
                        thin: true
                        value: upper > lower ? ((save.running ? staged : Number(setting.modelData.value)) - lower) / (upper - lower) : 0
                        onMoved: v => {
                            const step = Number(setting.modelData.step ?? 0);
                            let next = lower + v * (upper - lower);
                            if (step > 0) next = lower + Math.round((next - lower) / step) * step;
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
                        visible: setting.modelData.type === "slider"
                        text: setting.modelData.mixed ? "mixed" : String(Math.round(Number(setting.modelData.value) * 100) / 100)
                        font.pixelSize: Theme.size.small
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
                    TextBox {
                        id: textField
                        visible: ["color", "textinput", "file", "directory", "scenetexture"].includes(setting.modelData.type)
                        Layout.preferredWidth: 220
                        Binding {
                            target: textField
                            property: "text"
                            when: !textField.input.activeFocus
                            value: setting.modelData.mixed ? "" : String(setting.modelData.value ?? "")
                        }
                        placeholder: setting.modelData.mixed ? "mixed" : ""
                        onAccepted: Wallpapers.setSceneSetting(root.output, setting.modelData.name, text, root.projectPath)
                    }
                    Item { Layout.fillWidth: true }
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
