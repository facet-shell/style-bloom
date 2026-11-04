import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// Sound: where the sound goes and which microphone apps get, one switch per device like the
// mockup. Only one can be the default, so a switch only turns on (the others go off).
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    function label(node) {
        return node.description || node.nickname || node.name;
    }

    PageHeading {
        text: "Output"
    }

    Repeater {
        model: Audio.sinks

        delegate: ConfigRow {
            id: sink

            required property var modelData
            readonly property bool picked: Pipewire.defaultAudioSink?.id === modelData.id

            title: page.label(modelData)
            icon: picked ? "volume_up" : "speaker"
            interactive: !picked
            onClicked: Pipewire.preferredDefaultAudioSink = modelData

            Switch {
                checked: sink.picked
                onToggled: on => {
                    if (on)
                        Pipewire.preferredDefaultAudioSink = sink.modelData;
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Audio.sinks.length === 0
        text: "no output found"
        dim: true
        font.pixelSize: Theme.size.small
    }

    PageHeading {
        text: "Input"
    }

    Repeater {
        model: Audio.inputs

        delegate: ConfigRow {
            id: source

            required property var modelData
            readonly property bool picked: Pipewire.defaultAudioSource?.id === modelData.id

            title: page.label(modelData)
            icon: "mic"
            interactive: !picked
            onClicked: Pipewire.preferredDefaultAudioSource = modelData

            Switch {
                checked: source.picked
                onToggled: on => {
                    if (on)
                        Pipewire.preferredDefaultAudioSource = source.modelData;
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Audio.inputs.length === 0
        text: "no microphone found"
        dim: true
        font.pixelSize: Theme.size.small
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        text: "Levels per app and the GoXLR's channels are in the control center's mixer."
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
