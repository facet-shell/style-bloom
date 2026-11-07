import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The Spotify bloom: when Spotify starts another song the cover drops out of the top border
// under the clock as a spinning disc, opens into a pill (title, artist, a thin progress
// line, prev / play / next), stays a few seconds (longer while the mouse is on it), then
// folds back into the disc and leaves. A new song while it is open morphs in place. In a
// game with Bloom.compact("spotify"): a 40 px see-through pill with title and artist only,
// for a shorter time. Not while the dashboard is out (it shows the song there), not for the
// song that was playing when the shell started, and only as the rule "sp.song" allows.
// Size Bloom.scale("spotify"), how long Config.spotifySeconds; where: top center unless
// spotifyPosition was picked. No like button: Spotify does not offer liking over MPRIS.
// The pill, the progress line and the play button take the cover's colors (AlbumColor).
Scope {
    id: root

    property bool hidden: false

    readonly property MprisPlayer spotify: Mpris.players.values.find(p => p.identity === "Spotify") ?? null
    property string lastTrack: ""
    // A test from the settings is out (Bloom.preview("spotify")): shows without Spotify too
    property bool previewing: false

    // The bloom's own place is under the clock; tui's default (top-left) is not read
    readonly property string position: Config.user.spotifyPosition ?? "top"
    readonly property string side: Config.side(position)
    readonly property bool top: Config.atTop(position)
    readonly property bool compact: Bloom.compact("spotify")
    readonly property string screenName: popup.screen?.name ?? ""
    // The dashboard comes out of the same spot and shows the song itself
    readonly property bool blocked: top && side === "center" && Bloom.inset(screenName, "top") > 0

    // What is on screen: kept apart from the player, so a new song can morph in
    property string title: ""
    property string artist: ""
    property string art: ""

    // closed → opening → open → closing → closed
    property string phase: "closed"
    // 0 → 1: the disc drops in; the pill opens; title and controls fade in
    property real drop: 0
    property real spread: 0
    property real info: 0
    property real controls: 0
    // -1 … 1 while a new song swaps in (0 at rest)
    property real swap: 0
    // Set when opening, not bound: the drop's own overshoot must not cut it short
    property int dropTime: Theme.anim.drawerIn

    readonly property real discSize: compact ? 32 : 48
    readonly property real inner: compact ? Theme.spacing.small : Theme.spacing.small + Theme.spacing.tiny
    readonly property real closedWidth: discSize + inner * 2
    readonly property real openWidth: compact ? 280 : 400
    readonly property real pillHeight: compact ? 40 : 60
    // Room for the shadow inside the window; the window sits at the hole's edge
    readonly property real pad: Theme.spacing.large

    readonly property int holdTime: (compact ? Math.min(3, Config.spotifySeconds) : Math.max(2, Config.spotifySeconds)) * 1000

    function trackKey(player) {
        return player ? `${player.trackTitle}|${player.trackArtist}` : "";
    }

    function take() {
        title = spotify?.trackTitle ?? "";
        artist = spotify?.trackArtist ?? "";
        art = spotify?.trackArtUrl ?? "";
    }

    function trackChanged() {
        const key = trackKey(spotify);
        if (!spotify || spotify.trackTitle === "" || key === lastTrack)
            return;
        lastTrack = key;
        // Skipped from the dashboard's media card or in Spotify itself: you are looking at it already
        if (Spotify.cardOpen || Spotify.windowFocused || blocked || hidden)
            return;
        // Game mode and the bell, as the rules say
        if (!Notifications.allows("sp.song"))
            return;
        bloom();
    }

    function bloom() {
        switch (phase) {
        case "open":
            swapAnim.restart();
            break;
        case "opening":
            take();
            break;
        default:
            // Closed, or folding away: (re)open from wherever it is
            closeAnim.stop();
            take();
            // Still out (caught while folding): no second drop
            dropTime = drop > 0.99 ? 0 : Theme.anim.drawerIn;
            phase = "opening";
            openAnim.restart();
        }
    }

    // The song playing now, or a made-up one when Spotify is not running
    function preview() {
        previewing = true;
        bloom();
        if (!spotify || spotify.trackTitle === "") {
            title = "Test song";
            artist = "facet";
            art = "";
        }
    }

    Connections {
        target: Bloom

        function onPreviewRequested(what) {
            if (what === "spotify")
                root.preview();
        }
    }

    function fold() {
        if (phase !== "open" && phase !== "opening")
            return;
        openAnim.stop();
        swapAnim.stop();
        swap = 0;
        hold.stop();
        phase = "closing";
        closeAnim.restart();
    }

    // No bloom for the song that was already playing when the shell started
    onSpotifyChanged: lastTrack = trackKey(spotify)
    onBlockedChanged: if (blocked)
        fold()
    onHiddenChanged: if (hidden)
        fold()
    // Switching to Spotify while it is out: Spotify shows the song itself
    readonly property bool inSpotify: Spotify.windowFocused
    onInSpotifyChanged: if (inSpotify)
        fold()

    Connections {
        target: root.spotify

        function onTrackTitleChanged() {
            root.trackChanged();
        }

        function onTrackArtistChanged() {
            root.trackChanged();
        }

        // The cover often arrives after the title
        function onTrackArtUrlChanged() {
            if (root.phase !== "closed" && root.trackKey(root.spotify) === root.lastTrack)
                root.art = root.spotify.trackArtUrl;
        }
    }

    // Stays while the mouse is on it, then folds after the rest of its time
    Timer {
        id: hold

        interval: root.holdTime
        onTriggered: {
            if (hover.hovered)
                restart();
            else
                root.fold();
        }
    }

    // MPRIS does not push the position, so ask for it while the bloom is open
    Timer {
        running: root.phase === "open" && !root.compact && (root.spotify?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.spotify.positionChanged()
    }

    // ── Motion ───────────────────────────────────────────────

    SequentialAnimation {
        id: openAnim

        // Out of the top border as a disc, with a little bounce
        SpringAnim {
            target: root
            property: "drop"
            to: 1
            duration: root.dropTime
        }
        Anim {
            target: root
            property: "spread"
            to: 1
            duration: Theme.anim.drawerIn
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "info"
                to: 1
            }
            SpringAnim {
                target: root
                property: "controls"
                to: 1
            }
        }
        ScriptAction {
            script: {
                root.phase = "open";
                hold.restart();
            }
        }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            Anim {
                target: root
                property: "info"
                to: 0
                duration: Theme.anim.fast
            }
            Anim {
                target: root
                property: "controls"
                to: 0
                duration: Theme.anim.fast
            }
        }
        Anim {
            target: root
            property: "spread"
            to: 0
            duration: Theme.anim.drawerOut
        }
        // Back up into the border
        Anim {
            target: root
            property: "drop"
            to: 0
            duration: Theme.anim.medium
            easing.bezierCurve: Theme.curve.emphasizedAccel
        }
        ScriptAction {
            script: {
                root.phase = "closed";
                root.previewing = false;
            }
        }
    }

    // A new song while open: the old cover turns away, the new one turns in
    SequentialAnimation {
        id: swapAnim

        Anim {
            target: root
            property: "swap"
            to: 1
            duration: Theme.anim.fast
            easing.bezierCurve: Theme.curve.emphasizedAccel
        }
        ScriptAction {
            script: {
                root.take();
                root.swap = -1;
            }
        }
        SpringAnim {
            target: root
            property: "swap"
            to: 0
            duration: Theme.anim.drawerIn
        }
        ScriptAction {
            script: hold.restart()
        }
    }

    // ── Window ───────────────────────────────────────────────

    HolePopup {
        id: popup

        screen: Bloom.focusedScreen
        position: root.position
        margin: 0
        insetLeft: root.side === "left" ? Bloom.inset(root.screenName, "left") : 0
        insetRight: root.side === "right" ? Bloom.inset(root.screenName, "right") : 0
        contentScale: Bloom.scale("spotify")
        shown: root.phase !== "closed" && (root.spotify !== null || root.previewing)
        namespace: "qs-media-popup"
        // Only the pill takes the mouse, not the room kept for its full width
        mask: Region {
            item: pill
        }

        Behavior on insetLeft {
            Anim {
                duration: Theme.anim.drawerIn
            }
        }
        Behavior on insetRight {
            Anim {
                duration: Theme.anim.drawerIn
            }
        }

        // The window keeps the open size the whole time: resizing it every frame would jitter
        Item {
            id: room

            implicitWidth: root.openWidth + root.pad * 2
            implicitHeight: root.pillHeight + root.pad * 2

            Item {
                id: pill

                readonly property real fromEdge: root.top ? -1 : 1

                width: root.closedWidth + (root.openWidth - root.closedWidth) * root.spread
                height: root.pillHeight
                x: root.side === "left" ? root.pad : root.side === "right" ? room.width - root.pad - width : (room.width - width) / 2
                y: root.pad
                opacity: Math.min(1, root.drop * 1.5)
                scale: 0.3 + 0.7 * root.drop
                transformOrigin: root.top ? Item.Top : Item.Bottom
                // Comes out of the frame's edge it sits at
                transform: Translate {
                    y: pill.fromEdge * (root.pillHeight + root.pad) * (1 - root.drop)
                }

                HoverHandler {
                    id: hover

                    onHoveredChanged: if (!hovered && root.phase === "open")
                        hold.restart()
                }

                Rectangle {
                    id: bg

                    anchors.fill: parent
                    visible: false
                    radius: height / 2
                    color: root.compact ? Theme.scrim : AlbumColor.container
                }

                MultiEffect {
                    source: bg
                    anchors.fill: bg
                    autoPaddingEnabled: true
                    shadowEnabled: !root.compact
                    shadowColor: Theme.shadowColor
                    shadowOpacity: 0.8
                    shadowBlur: 1
                    blurMax: 40
                    shadowVerticalOffset: 10
                }

                // ── The disc ──

                Item {
                    id: disc

                    property url shownArt: ""
                    property real reveal: 1

                    x: root.inner
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.discSize
                    height: root.discSize

                    // Spins while the song plays
                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: Theme.anim.slow * 7
                        loops: Animation.Infinite
                        running: Theme.animated && root.phase !== "closed"
                        paused: running && !(root.spotify?.isPlaying ?? false)
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.high

                        Icon {
                            anchors.centerIn: parent
                            visible: cover.status !== Image.Ready && previousCover.status !== Image.Ready
                            icon: "music_note"
                            size: root.discSize * 0.45
                            dim: true
                        }

                        Image {
                            id: cover

                            anchors.fill: parent
                            source: root.art
                            sourceSize: Qt.size(root.discSize * 2, root.discSize * 2)
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
                            sourceSize: Qt.size(root.discSize * 2, root.discSize * 2)
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
                    }

                    // The spindle hole
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.compact ? 7 : 10
                        height: width
                        radius: width / 2
                        color: root.compact ? Theme.scrim : AlbumColor.container
                        border.width: 2
                        border.color: Theme.alpha(Theme.textOnScrim, 0.2)
                    }
                }

                // ── Title, artist, progress ──

                ColumnLayout {
                    id: songInfo

                    anchors.left: disc.right
                    anchors.leftMargin: Theme.spacing.medium - (root.compact ? Theme.spacing.tiny : 0)
                    anchors.right: buttons.visible ? buttons.left : parent.right
                    anchors.rightMargin: root.compact ? Theme.spacing.large : Theme.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.compact ? 0 : Theme.spacing.tiny
                    visible: root.info > 0.01
                    opacity: root.info * (1 - Math.abs(root.swap))
                    transform: Translate {
                        x: -10 * (1 - root.info)
                        y: -8 * root.swap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        color: root.compact ? Theme.textOnScrim : Theme.text
                        font.pixelSize: root.compact ? Theme.size.small : Theme.size.normal
                        font.weight: root.compact ? Font.Medium : Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.artist
                        color: root.compact ? Theme.alpha(Theme.textOnScrim, 0.7) : Theme.dim
                        font.pixelSize: root.compact ? Theme.size.tiny - 1 : Theme.size.tiny
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.small
                        visible: !root.compact
                        thickness: 3
                        color: AlbumColor.accent
                        value: (root.spotify?.length ?? 0) > 0 ? root.spotify.position / root.spotify.length : 0
                    }
                }

                // ── prev / play / next ──

                Row {
                    id: buttons

                    visible: !root.compact && root.controls > 0.01
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.small
                    opacity: Math.min(1, root.controls)
                    scale: 0.8 + 0.2 * root.controls

                    IconButton {
                        icon: "skip_previous"
                        size: Theme.control.pill
                        disabled: !(root.spotify?.canGoPrevious ?? false)
                        onClicked: root.spotify?.previous()
                    }
                    IconButton {
                        icon: root.spotify?.isPlaying ? "pause" : "play_arrow"
                        size: Theme.control.pill
                        filled: true
                        fillColor: AlbumColor.accent
                        iconColor: AlbumColor.textOnAccent
                        // Square while playing, round while paused
                        active: root.spotify?.isPlaying ?? false
                        onClicked: root.spotify?.togglePlaying()
                    }
                    IconButton {
                        icon: "skip_next"
                        size: Theme.control.pill
                        disabled: !(root.spotify?.canGoNext ?? false)
                        onClicked: root.spotify?.next()
                    }
                }
            }
        }
    }
}
