import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// Sound: where the sound goes and which microphone apps get, one switch per device like the
// mockup. Only one can be the default, so a switch only turns on (the others go off). Then the
// channels: where they come from (a GoXLR, the virtual ones from `facet audio channels on`),
// and with the virtual ones the rules that put apps on them. Without a GoXLR and without the
// virtual channels only a line says how to get them.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    function label(node) {
        return node.description || node.nickname || node.name;
    }

    PageHeading {
        text: Audio.virtualActive ? "Output · where the channels play" : "Output"
    }

    // With the virtual channels the default output is their System channel; picking a device
    // here moves the channels onto it instead (Audio.pickOutput)
    Repeater {
        model: Audio.masterOutputs

        delegate: ConfigRow {
            id: sink

            required property var modelData
            readonly property bool picked: Audio.masterOutput?.id === modelData.id

            title: page.label(modelData)
            icon: picked ? "volume_up" : "speaker"
            interactive: !picked
            onClicked: Audio.pickOutput(modelData)

            Switch {
                checked: sink.picked
                onToggled: on => {
                    if (on)
                        Audio.pickOutput(sink.modelData);
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Audio.masterOutputs.length === 0
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

    // ── Channels ──

    PageHeading {
        text: "Channels"
    }

    ConfigChoice {
        visible: Audio.goxlrAvailable || Audio.virtualAvailable
        key: "audioChannels"
        title: "Channels from"
        subtitle: `in use: ${Audio.channelSource === "goxlr" ? "the GoXLR" : Audio.channelSource === "virtual" ? "the virtual channels" : "none, plain devices"}`
        icon: "tune"
        options: [["auto", "Auto"]]
            .concat(Audio.goxlrAvailable ? [["goxlr", "GoXLR"]] : [])
            .concat(Audio.virtualAvailable ? [["virtual", "Virtual"]] : [])
            .concat([["none", "None"]])
    }

    // Nothing to pick from: only how to get the virtual channels
    StyledText {
        Layout.fillWidth: true
        visible: !Audio.goxlrAvailable && Audio.virtualSetup === null
        text: "No GoXLR here. facet audio channels on (in a terminal) makes virtual System, Game, Chat and Music outputs: every app on its own channel, a fader each in the control center, a track each in recordings."
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    ConfigRow {
        visible: Audio.virtualSetup !== null
        title: Audio.virtualAvailable ? Audio.virtualChannels.map(c => c.label).join(", ") : "Virtual channels missing"
        subtitle: Audio.virtualAvailable
            ? `into ${page.label(Audio.channelOutput ?? { name: "no output" })} · other channels: facet audio channels on <names> · gone again: facet audio channels off`
            : "set up, but not in PipeWire right now · facet audio channels status"
        icon: Audio.virtualAvailable ? "graphic_eq" : "warning"
    }

    ConfigSwitch {
        visible: Audio.virtualActive
        key: "audioRulesOn"
        title: "Apps to their channel by themselves"
        subtitle: "the rules below, for apps that start on System"
    }

    AudioRules {
        visible: Audio.virtualActive && Config.audioRulesOn
    }

    ConfigRow {
        visible: Audio.virtualActive && Object.keys(Channels.choices).length > 0
        title: "Picked in the mixer"
        subtitle: Object.keys(Channels.choices).map(k => `${k} → ${Channels.choices[k]}`).join(", ")
        icon: "history"

        Button {
            text: "Forget"
            icon: "delete"
            variant: "plain"
            onClicked: Channels.forgetChoices()
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        text: Audio.goxlr ? "Levels per app and the GoXLR's channels are in the control center's mixer."
            : Audio.virtualActive ? "Levels per channel are in the control center, per app in its mixer."
            : "Levels per app are in the control center's mixer."
        dim: true
        font.pixelSize: Theme.size.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
