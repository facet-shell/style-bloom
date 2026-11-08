import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Pill {
    id: root

    property real availableWidth: 300
    property var bar: null
    property var screen: null
    readonly property var members: DiscordBridge.voice.members
    readonly property var me: members.find(m => m.you) ?? null
    readonly property int limit: {
        // The icon, the three buttons and the padding come first
        let used = 68 + 3 * 30 + 8;
        let count = 0;
        for (const person of members.slice(0, Config.voiceBarMaxUsers)) {
            used += 34;
            if (used > availableWidth)
                break;
            count++;
        }
        return count;
    }
    readonly property var shownMembers: members.slice(0, limit)
    // Also while Discord is on screen: the buttons are worth having there too
    visible: Config.voiceOverlayInBar && !Bloom.gaming && DiscordBridge.inVoice
    padding: 10
    spacing: 8

    Icon {
        icon: "headset_mic"
        size: 16
        color: Theme.primary
    }
    Repeater {
        model: root.shownMembers

        Item {
            id: member
            required property var modelData
            readonly property bool talking: DiscordBridge.speaking[modelData.userId] === true
            readonly property bool watching: DiscordBridge.streamLive && DiscordBridge.streamViewers.some(v => v.id === modelData.userId)
            implicitWidth: 26
            implicitHeight: 26

            Rectangle {
                x: -2
                y: -2
                width: 30
                height: 30
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: member.talking ? Theme.ok : "transparent"
            }
            AppIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                size: 26
                round: true
                source: member.modelData.avatar ?? ""
                letter: (member.modelData.name ?? "?").slice(0, 2).toUpperCase()
            }
            Rectangle {
                x: 15
                anchors.bottom: parent.bottom
                width: 13
                height: 13
                radius: 6
                color: Theme.surface
                visible: member.modelData.muted || member.modelData.deafened
                Icon {
                    anchors.centerIn: parent
                    size: 11
                    icon: member.modelData.deafened ? "headset_off" : member.modelData.muted ? "mic_off" : "visibility"
                    color: member.modelData.muted || member.modelData.deafened ? Theme.error : Theme.primary
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: 13
                height: 13
                radius: 6
                color: Theme.surface
                visible: member.watching
                Icon {
                    anchors.centerIn: parent
                    icon: "visibility"
                    size: 11
                    color: Theme.primary
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -1
                width: 9
                height: 9
                radius: width / 2
                visible: member.modelData.streaming === true
                color: Theme.error
                border.width: 2
                border.color: Theme.surface
            }
        }
    }
    StyledText {
        visible: root.members.length > root.shownMembers.length
        text: `+${root.members.length - root.shownMembers.length}`
        font.pixelSize: Theme.size.tiny
        dim: true
    }

    Rectangle {
        implicitWidth: 1
        implicitHeight: 18
        color: Theme.alpha(Theme.outline, 0.8)
    }

    // Your own mute, deafen and Go Live
    IconButton {
        size: 28
        iconSize: 17
        icon: root.me?.muted ? "mic_off" : "mic"
        iconColor: root.me?.muted ? Theme.error : Theme.dim
        onClicked: DiscordBridge.send({ cmd: "toggle_mute" })
    }
    IconButton {
        size: 28
        iconSize: 17
        icon: root.me?.deafened ? "headset_off" : "headphones"
        iconColor: root.me?.deafened ? Theme.error : Theme.dim
        onClicked: DiscordBridge.send({ cmd: "toggle_deafen" })
    }
    IconButton {
        id: streamButton

        size: 28
        iconSize: 17
        icon: DiscordBridge.streamLive ? "cast_connected" : "cast"
        iconColor: DiscordBridge.streamLive ? Theme.error : Theme.dim
        active: root.bar?.streamPanel.open ?? false
        onClicked: {
            const panel = root.bar?.streamPanel;
            if (!panel)
                return;
            if (panel.open && panel.anchorItem === streamButton)
                panel.open = false;
            else
                panel.popup(root.screen, streamButton);
        }
    }
}
