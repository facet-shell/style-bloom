import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config
import qs.media

// The media tab: the big cover, title, artist, progress (a click seeks) and the controls.
// With more than one player, chips on top pick which one it shows. The play button, the
// progress and the shuffle / repeat marks take the cover's accent (AlbumColor).
RowLayout {
    id: root

    property MprisPlayer player: null
    readonly property var players: Mpris.players.values
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0

    signal playerPicked(MprisPlayer player)

    spacing: Theme.spacing.large

    function format(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        const two = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${two(m)}:${two(s % 60)}` : `${m}:${two(s % 60)}`;
    }

    // Rounder while it plays, like the play button turning into a soft square
    ClippingRectangle {
        Layout.preferredWidth: 260
        Layout.preferredHeight: 260
        Layout.alignment: Qt.AlignVCenter
        radius: root.playing ? Theme.rounding.drawer * 1.4 : Theme.rounding.large
        color: Theme.container

        Behavior on radius {
            Anim {
                duration: Theme.anim.color
            }
        }

        Image {
            id: cover

            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(520, 520)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Icon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            icon: root.player ? "music_note" : "music_off"
            size: Theme.icon.huge
            dim: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 10

        // Which player, when there are several
        Flow {
            Layout.fillWidth: true
            visible: root.players.length > 1
            spacing: 6

            Repeater {
                model: root.players

                Chip {
                    required property MprisPlayer modelData

                    compact: true
                    icon: modelData.isPlaying ? "graphic_eq" : ""
                    text: modelData.identity
                    selected: modelData === root.player
                    onClicked: root.playerPicked(modelData)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            dim: true
            font.pixelSize: Theme.size.small
            text: root.player ? `${root.player.identity} · ${root.playing ? "playing" : "paused"}` : "Nothing plays right now"
        }
        StyledText {
            Layout.fillWidth: true
            text: root.player ? (root.player.trackTitle || root.player.identity) : "Media"
            font.pixelSize: Theme.size.title
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            lineHeight: 1.1
        }
        StyledText {
            Layout.fillWidth: true
            text: root.player ? root.player.trackArtist : "Spotify, a video in the browser or anything else that plays shows up here"
            dim: true
            font.pixelSize: Theme.size.medium
            wrapMode: root.player ? Text.NoWrap : Text.WordWrap
        }

        // Progress; a click seeks where the player allows it
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            visible: root.player !== null && root.length > 0
            spacing: Theme.spacing.small

            ProgressBar {
                Layout.fillWidth: true
                thickness: 6
                animated: false
                color: AlbumColor.accent
                value: root.length > 0 ? root.position / root.length : 0

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    enabled: root.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * root.length
                }
            }
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: root.format(root.position)
                    dim: true
                    tabular: true
                    font.pixelSize: Theme.size.tiny
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    text: root.format(root.length)
                    dim: true
                    tabular: true
                    font.pixelSize: Theme.size.tiny
                }
            }
        }

        RowLayout {
            visible: root.player !== null
            spacing: 10

            IconButton {
                visible: root.player?.shuffleSupported ?? false
                icon: "shuffle"
                active: root.player?.shuffle ?? false
                iconColor: active ? AlbumColor.accent : hovered ? Theme.text : Theme.dim
                onClicked: root.player.shuffle = !root.player.shuffle
            }
            IconButton {
                icon: "skip_previous"
                size: Theme.control.button
                restColor: Theme.high
                disabled: !(root.player?.canGoPrevious ?? false)
                onClicked: root.player.previous()
            }
            IconButton {
                icon: root.playing ? "pause" : "play_arrow"
                size: 56
                iconSize: 28
                filled: true
                fillColor: AlbumColor.accent
                iconColor: AlbumColor.textOnAccent
                active: root.playing
                onClicked: root.player.togglePlaying()
            }
            IconButton {
                icon: "skip_next"
                size: Theme.control.button
                restColor: Theme.high
                disabled: !(root.player?.canGoNext ?? false)
                onClicked: root.player.next()
            }
            IconButton {
                visible: root.player?.loopSupported ?? false
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                iconColor: active ? AlbumColor.accent : hovered ? Theme.text : Theme.dim
                onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.player?.trackAlbum ? `♪ ${root.player.trackAlbum}` : ""
            dim: true
            font.pixelSize: Theme.size.small
        }
    }
}
