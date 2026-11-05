import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.components
import qs.config
import qs.services

// The Bluetooth tile's page: the paired devices (Quickshell.Bluetooth), connected ones
// first, with an icon by type, the battery when the device reports one and their state.
// A click connects or disconnects. "Pair a new device" starts discovery on the adapter and
// what shows up lists below it; a click pairs it, trusts it and connects.
DevicePage {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: Bluetooth.devices.values
    readonly property var paired: devices.filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || a.name.localeCompare(b.name))
    // Nameless finds are noise (beacons, phones not advertising a name)
    readonly property var found: discovering ? devices.filter(d => !d.paired && !d.connected && d.name !== "") : []
    readonly property int connectedCount: devices.filter(d => d.connected).length
    // Discovery this page started stops with it; one bluetoothctl left scanning does not
    property bool scanStarted: false

    title: "Bluetooth"
    subtitle: !Toggles.bluetooth ? "off"
        : discovering ? "looking for devices…"
        : connectedCount === 1 ? `connected to ${devices.find(d => d.connected).name}`
        : connectedCount > 1 ? `${connectedCount} devices connected`
        : "on"

    control: Switch {
        checked: Toggles.bluetooth
        disabled: !Toggles.bluetoothAvailable
        onToggled: on => Toggles.setBluetooth(on)
    }

    Component.onDestruction: {
        if (scanStarted && adapter)
            adapter.discovering = false;
    }

    function setDiscovering(on) {
        if (!adapter)
            return;
        adapter.discovering = on;
        scanStarted = on;
    }

    // bluez's icon names ("audio-headset", "input-mouse", "phone" …) as Material Symbols
    function iconFor(device) {
        const icon = device.icon;
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones"))
            return "headphones";
        if (icon.startsWith("audio-"))
            return "speaker";
        if (icon.startsWith("input-keyboard"))
            return "keyboard";
        if (icon.startsWith("input-mouse"))
            return "mouse";
        if (icon.startsWith("input-gaming"))
            return "sports_esports";
        if (icon.startsWith("input-tablet"))
            return "stylus";
        if (icon.startsWith("phone"))
            return "smartphone";
        if (icon.startsWith("computer"))
            return "computer";
        if (icon.startsWith("video-display"))
            return "tv";
        if (icon.startsWith("camera"))
            return "photo_camera";
        if (icon.startsWith("printer"))
            return "print";
        return "bluetooth";
    }

    function stateText(device) {
        if (device.state === BluetoothDeviceState.Connecting)
            return "connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "disconnecting…";
        if (device.pairing)
            return "pairing…";
        if (device.connected)
            return "connected" + (device.batteryAvailable ? ` · ${Math.round(device.battery * 100)}% battery` : "");
        return device.paired ? "paired" : "new";
    }

    function busy(device) {
        return device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
    }

    // ── Rows ─────────────────────────────────────────────────

    component DeviceRow: SettingRow {
        id: row

        required property var modelData
        // Set while this row started the pairing, so the device connects once it is paired
        property bool pairingHere: false

        Layout.fillWidth: true
        baseColor: modelData.connected ? Theme.secondaryContainer : Theme.container
        icon: root.iconFor(modelData)
        title: modelData.name !== "" ? modelData.name : modelData.address
        subtitle: root.stateText(modelData)
        interactive: !root.busy(modelData)
        onClicked: {
            if (modelData.connected)
                modelData.disconnect();
            else if (modelData.paired)
                modelData.connect();
            else {
                pairingHere = true;
                modelData.pair();
            }
        }

        Icon {
            visible: row.modelData.connected
            icon: "bluetooth_connected"
            size: Theme.icon.small
            color: Theme.primary
        }

        Connections {
            target: row.modelData

            function onPairedChanged() {
                if (!row.pairingHere || !row.modelData.paired)
                    return;
                row.pairingHere = false;
                // Trusted devices come back by themselves next time
                row.modelData.trusted = true;
                row.modelData.connect();
            }

            // Pairing that ended without a pair (refused, timed out) is over
            function onPairingChanged() {
                if (!row.modelData.pairing && !row.modelData.paired)
                    row.pairingHere = false;
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !Toggles.bluetooth || root.paired.length === 0
        text: !Toggles.bluetoothAvailable ? "no Bluetooth adapter here" : !Toggles.bluetooth ? "Bluetooth is off" : "no paired devices yet"
        dim: true
        font.pixelSize: Theme.size.small
    }

    Repeater {
        model: Toggles.bluetooth ? root.paired : []

        delegate: DeviceRow {}
    }

    SettingRow {
        Layout.fillWidth: true
        visible: Toggles.bluetooth
        icon: root.discovering ? "bluetooth_searching" : "add"
        title: "Pair a new device"
        subtitle: root.discovering ? "looking for devices · click to stop" : "starts a search"
        interactive: true
        onClicked: root.setDiscovering(!root.discovering)
    }

    Repeater {
        model: Toggles.bluetooth ? root.found : []

        delegate: DeviceRow {}
    }
}
