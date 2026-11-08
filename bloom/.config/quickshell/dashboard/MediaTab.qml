import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
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

    // Like the popup's record: pause holds the current angle, resume continues.
    ClippingRectangle {
        id: disc

        property url shownArt: ""
        property real reveal: 1

        Layout.preferredWidth: 260
        Layout.preferredHeight: 260
        Layout.alignment: Qt.AlignVCenter
        radius: width / 2
        color: Theme.container

        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: Theme.anim.slow * 7
            loops: Animation.Infinite
            running: Theme.animated && root.visible && root.player !== null
            paused: running && !root.playing
        }

        Image {
            id: cover

            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(520, 520)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            opacity: disc.reveal
            scale: 0.96 + 0.04 * disc.reveal
            onSourceChanged: previousCover.source = disc.shownArt
            onStatusChanged: {
                if (status === Image.Ready) {
                    dissolve.stop();
                    previousCover.source = disc.shownArt;
                    disc.shownArt = source;
                    if (Theme.animated && previousCover.source.toString() !== ""
                            && previousCover.source.toString() !== source.toString())
                        dissolve.restart();
                    else
                        disc.reveal = 1;
                } else if (source.toString() === "") {
                    dissolve.stop();
                    disc.shownArt = "";
                    previousCover.source = "";
                    disc.reveal = 1;
                }
            }
        }
        Image {
            id: previousCover

            anchors.fill: parent
            sourceSize: Qt.size(520, 520)
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready && (cover.status !== Image.Ready || disc.reveal < 1)
            opacity: cover.status === Image.Ready ? 1 - disc.reveal : 1
            scale: 1 + 0.08 * (1 - opacity)
        }
        NumberAnimation {
            id: dissolve

            target: disc
            property: "reveal"
            from: 0
            to: 1
            duration: 650
            easing.type: Easing.InOutQuad
        }
        Icon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready && previousCover.status !== Image.Ready
            icon: root.player ? "music_note" : "music_off"
            size: Theme.icon.huge
            dim: true
        }
        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: width
            radius: width / 2
            color: AlbumColor.container
            border.width: 2
            border.color: Theme.alpha(Theme.textOnScrim, 0.2)
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
            visible: text !== ""
            text: root.player?.trackAlbum ?? ""
            dim: true
            font.pixelSize: Theme.size.small
            elide: Text.ElideRight
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
            Layout.fillWidth: true
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
            Icon {
                Layout.leftMargin: Theme.spacing.small
                icon: Audio.volumeIcon(root.player?.volume ?? 0, false)
                size: Theme.icon.normal
                dim: true
            }
            Slider {
                Layout.fillWidth: true
                Layout.minimumWidth: 60
                thin: true
                disabled: !(root.player?.volumeSupported ?? false)
                value: root.player?.volume ?? 0
                onMoved: value => {
                    if (root.player?.volumeSupported)
                        root.player.volume = value;
                }
            }
            StyledText {
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                text: (root.player?.volumeSupported ?? false)
                    ? `${Math.round((root.player?.volume ?? 0) * 100)}%` : "—"
                dim: true
                tabular: true
                font.pixelSize: Theme.size.small
            }
        }

    }
}
