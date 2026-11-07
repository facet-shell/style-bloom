import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Pill {
    id: root

    property real availableWidth: 300
    readonly property var members: DiscordBridge.voice.members
    readonly property int limit: {
        let used = 68;
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
    visible: Config.voiceOverlayInBar && !Bloom.gaming && DiscordBridge.overlayShown && limit > 0
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
}
