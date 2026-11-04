import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config

// Bottom left of the lockscreen: what plays, with play/pause and next, so a song can be
// skipped without unlocking. Hidden while no player is there.
Card {
    id: root

    // Whatever is playing, then Spotify, then any player
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        return list.find(p => p.isPlaying) ?? list.find(p => p.identity === "Spotify") ?? list[0] ?? null;
    }

    padding: Theme.padding.normal
    implicitWidth: 380

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing.medium

        ClippingRectangle {
            implicitWidth: 56
            implicitHeight: 56
            radius: Theme.rounding.normal
            color: Theme.high

            Icon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                icon: "music_note"
                dim: true
            }

            Image {
                id: cover

                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(112, 112)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Theme.spacing.tiny

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || root.player?.identity || ""
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                dim: true
                font.pixelSize: Theme.size.small
            }
        }

        IconButton {
            icon: root.player?.isPlaying ? "pause" : "play_arrow"
            size: Theme.control.button
            filled: true
            // Rounds into a soft square while it plays, like the media card everywhere else
            active: root.player?.isPlaying ?? false
            disabled: !(root.player?.canTogglePlaying ?? false)
            onClicked: root.player?.togglePlaying()
        }

        IconButton {
            icon: "skip_next"
            size: Theme.control.button
            restColor: Theme.high
            disabled: !(root.player?.canGoNext ?? false)
            onClicked: root.player?.next()
        }
    }
}
