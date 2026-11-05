import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The Network tile's page: the Wi-Fi networks around, from the Network service (nmcli). A
// click connects; a secured network the machine does not know yet asks for its password
// in the row and Enter connects. The connected row has a disconnect, the header a rescan
// and the Wi-Fi switch. Without NetworkManager there is only a line saying so.
DevicePage {
    id: root

    // The SSID whose password field is open
    property string asking: ""

    title: "Wi-Fi"
    subtitle: !Network.available ? "no NetworkManager here"
        : !Toggles.wifi ? "off"
        : Network.connecting !== "" ? `connecting to ${Network.connecting}…`
        : Network.type === "wifi" ? Network.name
        : Network.scanning ? "looking for networks…"
        : "not connected"

    control: RowLayout {
        spacing: Theme.spacing.small

        IconButton {
            icon: "refresh"
            disabled: !Network.available || !Toggles.wifi || Network.scanning
            onClicked: Network.scan("yes")
        }
        Switch {
            checked: Toggles.wifi
            disabled: !Network.available
            onToggled: on => Toggles.setWifi(on)
        }
    }

    function signalIcon(strength) {
        return strength >= 67 ? "wifi" : strength >= 34 ? "wifi_2_bar" : "wifi_1_bar";
    }

    // A saved network connects at once; a new secured one needs the password first
    function pick(network) {
        if (network.inUse || Network.connecting !== "")
            return;
        if (network.secured && !Network.isKnown(network.ssid))
            asking = asking === network.ssid ? "" : network.ssid;
        else
            Network.connectWifi(network.ssid);
    }

    // While the page is open NetworkManager's events keep the list fresh; the radio coming
    // on reads it too
    Component.onCompleted: {
        Network.wifiWatched = true;
        if (Toggles.wifi)
            Network.scan("auto");
    }
    Component.onDestruction: Network.wifiWatched = false

    Connections {
        target: Toggles

        function onWifiChanged() {
            if (Toggles.wifi)
                scanLater.restart();
        }
    }

    // The radio needs a moment before it sees anything
    Timer {
        id: scanLater
        interval: 1500
        onTriggered: Network.scan("auto")
    }

    // A connect that failed for want of a password (a saved profile with the wrong one, or
    // a network nmcli knew after all) opens the field
    Connections {
        target: Network

        function onConnectErrorChanged() {
            if (Network.connectError !== "" && /secret|password|psk/i.test(Network.connectError))
                root.asking = Network.connectErrorSsid;
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !Network.available || !Toggles.wifi || (Network.networks.length === 0 && !Network.scanning)
        text: !Network.available ? "no NetworkManager here" : !Toggles.wifi ? "Wi-Fi is off" : "no networks found"
        dim: true
        font.pixelSize: Theme.size.small
    }

    Repeater {
        model: Network.available && Toggles.wifi ? Network.networks : []

        // The row, and the password field under it inside the same block while it asks
        delegate: Rectangle {
            id: entry

            required property var modelData
            readonly property bool asking: root.asking === modelData.ssid
            readonly property bool busy: Network.connecting === modelData.ssid
            readonly property bool failed: !asking && Network.connectError !== "" && Network.connectErrorSsid === modelData.ssid

            Layout.fillWidth: true
            implicitHeight: block.implicitHeight
            radius: Theme.rounding.medium
            color: modelData.inUse ? Theme.secondaryContainer : Theme.container

            Behavior on color {
                ColorAnim {}
            }

            ColumnLayout {
                id: block

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                SettingRow {
                    Layout.fillWidth: true
                    baseColor: "transparent"
                    icon: root.signalIcon(entry.modelData.strength)
                    title: entry.modelData.ssid
                    subtitle: entry.busy ? "connecting…"
                        : entry.modelData.inUse ? "connected"
                        : entry.failed ? Network.connectError
                        : entry.asking ? "password, then Enter"
                        : Network.isKnown(entry.modelData.ssid) ? "saved"
                        : entry.modelData.secured ? entry.modelData.security : "open"
                    interactive: !entry.modelData.inUse && !entry.busy
                    onClicked: root.pick(entry.modelData)

                    RowLayout {
                        spacing: Theme.spacing.small

                        Icon {
                            visible: entry.modelData.secured
                            icon: "lock"
                            size: Theme.icon.small
                            dim: true
                        }
                        StyledText {
                            text: `${entry.modelData.strength}%`
                            dim: true
                            tabular: true
                            font.pixelSize: Theme.size.tiny
                        }
                        IconButton {
                            visible: entry.modelData.inUse
                            icon: "link_off"
                            size: 30
                            iconSize: 18
                            onClicked: Network.disconnectWifi()
                        }
                    }
                }

                // Made only while asked, so the focus comes and goes with it
                Loader {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.bottomMargin: 12
                    active: entry.asking
                    onLoaded: item.focusField()
                    // The page takes the keys back, so Esc goes on to close the page
                    onActiveChanged: {
                        if (!active)
                            root.forceActiveFocus();
                    }

                    sourceComponent: SearchField {
                        implicitHeight: Theme.control.button
                        icon: "key"
                        password: true
                        placeholder: "password"
                        baseColor: Theme.high
                        onAccepted: {
                            if (text === "")
                                return;
                            Network.connectWifi(entry.modelData.ssid, text);
                            root.asking = "";
                        }
                        onEscaped: root.asking = ""
                    }
                }
            }
        }
    }
}
