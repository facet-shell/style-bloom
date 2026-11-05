import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// The device list behind the volume slider's arrow (output) and the Mic mute tile's arrow
// (input): what settings > sound shows, one row per device, a click picks it. The output
// goes through Audio.pickOutput, so with the virtual channels it moves the channels onto
// the device instead of the default output.
DevicePage {
    id: root

    property bool input: false

    readonly property var devices: input ? Audio.inputs : Audio.masterOutputs
    readonly property var current: input ? Audio.defaultSource : Audio.masterOutput

    title: input ? "Microphone" : "Output"
    subtitle: devices.length === 0 ? ""
        : !input && Audio.virtualActive ? `the channels play into ${Audio.deviceLabel(current)}`
        : Audio.deviceLabel(current)

    function picked(node) {
        return current !== null && current.id === node.id;
    }

    function pick(node) {
        if (input)
            Pipewire.preferredDefaultAudioSource = node;
        else
            Audio.pickOutput(node);
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.devices.length === 0
        text: root.input ? "no microphone found" : "no output found"
        dim: true
        font.pixelSize: Theme.size.small
    }

    Repeater {
        model: root.devices

        delegate: SettingRow {
            id: row

            required property var modelData
            readonly property bool picked: root.picked(modelData)

            Layout.fillWidth: true
            baseColor: picked ? Theme.secondaryContainer : Theme.container
            icon: root.input ? "mic" : picked ? "volume_up" : "speaker"
            title: Audio.deviceLabel(modelData)
            interactive: !picked
            onClicked: root.pick(modelData)

            Icon {
                visible: row.picked
                icon: "check"
                size: Theme.icon.small
                color: Theme.primary
            }
        }
    }
}
