import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// A short notice when something changed outside the shell, only the thing that moved:
//   a GoXLR fader moved or got muted, the GoXLR mic button was pressed,
//   the default output's volume changed (media keys, pactl, an app), the keyboard layout switched.
// On the desktop one line slides out of the bottom edge (icon, name, bar, value), never while
// the launcher is out there. In a game with Bloom.compact("osd") a small see-through pill near
// the bottom instead, gone after a second. Display only: nothing in here changes a volume.
Scope {
    id: root

    property bool hidden: false
    property bool open: false
    property ShellScreen screen: Bloom.focusedScreen

    // What it shows right now
    property string label: ""
    property string icon: ""
    property real level: 0      // 0..1, below 0 = no bar
    property string valueText: ""
    property bool muted: false
    readonly property bool micStatus: level < 0 && (icon === "mic" || icon === "mic_off")

    readonly property bool compact: Bloom.compact("osd")
    readonly property real s: Bloom.scale("osd")
    // The launcher comes out of the same spot
    readonly property bool launcherOut: Bloom.inset(screen?.name ?? "", "bottom", "qs-osd") > 0

    // Values right after start are not news
    property bool armed: false
    property var lastFaders: ({})
    property bool lastMicButton: false
    property string lastSinkKey: ""

    readonly property var faderIcons: ({
        mic: "mic",
        chat: "forum",
        music: "music_note",
        game: "sports_esports",
        system: "volume_up"
    })

    function show(label, icon, level, valueText, muted) {
        if (!armed || hidden)
            return;
        // On the desktop the launcher has the bottom edge; in a game it is not out anyway
        if (!compact && launcherOut)
            return;
        root.screen = Bloom.focusedScreen;
        root.label = label;
        root.icon = icon;
        root.level = level;
        root.valueText = valueText;
        root.muted = muted;
        open = true;
        hideTimer.restart();
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    // How long it stays: about a second in a game, a little longer on the desktop
    Timer {
        id: hideTimer

        interval: root.compact ? 1000 : 1800
        onTriggered: root.open = false
    }

    onHiddenChanged: if (hidden)
        open = false
    onLauncherOutChanged: if (launcherOut && !compact)
        open = false

    // ── GoXLR faders and the mic button ──────────────────────

    function capitalized(text) {
        return text ? text.charAt(0).toUpperCase() + text.slice(1) : "";
    }

    function checkFaders() {
        const seen = Object.keys(lastFaders).length > 0;
        const now = {};
        let changed = null;
        for (const f of GoXLR.faders.map(s => GoXLR.fader(s.key))) {
            if (!f)
                continue;
            now[f.key] = f;
            const before = lastFaders[f.key];
            if (!changed && seen && before && (before.level !== f.level || before.muted !== f.muted))
                changed = f;
        }
        lastFaders = now;
        if (changed)
            show(capitalized(changed.label),
                changed.key === "mic" ? Audio.micIcon(changed.muted)
                    : changed.key === "system" || !faderIcons[changed.key] ? Audio.volumeIcon(changed.level / 100, changed.muted)
                    : changed.muted ? "volume_off" : faderIcons[changed.key],
                changed.muted ? 0 : changed.level / 100, changed.muted ? "muted" : `${changed.level} %`, changed.muted);
    }

    // The System channel has no fader on a Mini; the bar and the control center set it
    property int lastSystem: -1

    function checkSystem() {
        const level = GoXLR.volumes.system;
        if (level === undefined)
            return;
        if (lastSystem >= 0 && level !== lastSystem && !GoXLR.systemOnFader)
            show("System", Audio.volumeIcon(level / 100, false), level / 100, `${level} %`, false);
        lastSystem = level;
    }

    Connections {
        target: GoXLR

        function onVolumesChanged() {
            root.checkSystem();
        }

        // The fader list only changes with the channel assignment; levels and mutes live in GoXLR.live
        function onFadersChanged() {
            root.checkFaders();
        }

        function onLiveChanged() {
            root.checkFaders();
        }

        function onMicButtonMutedChanged() {
            if (GoXLR.micButtonMuted === root.lastMicButton)
                return;
            root.lastMicButton = GoXLR.micButtonMuted;
            root.show("Mic", Audio.micIcon(GoXLR.micButtonMuted), -1,
                GoXLR.micButtonMuted ? "muted" : "live", GoXLR.micButtonMuted);
        }
    }

    // ── Virtual channels (facet audio channels on) ───────────

    // A channel's level or mute changed (the control center, pavucontrol, an app), like a
    // GoXLR fader; System is the default output and shows below as the volume. The real
    // output the channels play into shows as "Output".
    function checkChannel(node) {
        const audio = node?.audio;
        if (!audio)
            return;
        const key = Audio.virtualChannels.find(c => c.node === node)?.key ?? "";
        show(key === "" ? "Output" : capitalized(Audio.routeLabel(key)),
            key === "" || key === "system" || !faderIcons[key] ? Audio.volumeIcon(audio.volume, audio.muted)
                : audio.muted ? "volume_off" : faderIcons[key],
            audio.muted ? 0 : Math.min(1, audio.volume),
            audio.muted ? "muted" : `${Math.round(audio.volume * 100)} %`, audio.muted);
    }

    Variants {
        model: Audio.virtualActive
            ? Audio.virtualNodes.concat(Audio.masterOutput ? [Audio.masterOutput] : []).filter(n => n !== root.sink)
            : []

        Connections {
            required property var modelData
            target: modelData?.audio ?? null

            function onVolumesChanged() {
                root.checkChannel(modelData);
            }

            function onMutedChanged() {
                root.checkChannel(modelData);
            }
        }
    }

    // ── Default output in PipeWire ───────────────────────────

    readonly property PwNode sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    // Switching to another output is not a volume change, so remember which one we watch
    onSinkChanged: lastSinkKey = sink ? `${sink.id}` : ""

    function checkSink() {
        const audio = sink?.audio;
        if (!audio || `${sink.id}` !== lastSinkKey)
            return;
        show(sink.description || sink.name || "Output",
            Audio.volumeIcon(audio.volume, audio.muted),
            audio.muted ? 0 : Math.min(1, audio.volume),
            audio.muted ? "muted" : `${Math.round(audio.volume * 100)} %`, audio.muted);
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumesChanged() {
            root.checkSink();
        }

        function onMutedChanged() {
            root.checkSink();
        }
    }

    // ── Keyboard layout ──────────────────────────────────────

    Connections {
        target: Hyprland

        // "activelayout>>keyboard-name,German"
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const name = event.data.split(",").pop().trim();
            if (name === "" || name === "error")
                return;
            root.show("Keyboard layout", "keyboard", -1, name, false);
        }
    }

    // ── Desktop: one line out of the bottom edge ─────────────

    Drawer {
        screen: root.screen
        edge: "bottom"
        open: root.open && !root.compact && !root.hidden
        namespace: "qs-osd"
        // Over fullscreen windows too (a video), like the notifications
        windowLayer: WlrLayer.Overlay
        // Display only: no focus grab, no keyboard
        closeOnOutside: false
        padding: Theme.padding.normal * root.s

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.small * root.s
            anchors.rightMargin: Theme.spacing.small * root.s
            implicitWidth: (root.micStatus ? 130 : 376) * root.s
            spacing: Theme.spacing.medium * root.s

            // The icon in its circle; muted turns it red
            Rectangle {
                implicitWidth: 38 * root.s
                implicitHeight: implicitWidth
                radius: height / 2
                color: root.muted ? Theme.errorContainer : Theme.primaryContainer

                Behavior on color {
                    ColorAnim {}
                }

                Icon {
                    anchors.centerIn: parent
                    icon: root.icon
                    size: (Theme.icon.normal - 1) * root.s
                    color: root.muted ? Theme.textOnErrorContainer : Theme.textOnPrimaryContainer
                }
            }

            ColumnLayout {
                visible: !root.micStatus
                Layout.fillWidth: true
                spacing: Theme.spacing.small + Theme.spacing.tiny

                StyledText {
                    Layout.fillWidth: true
                    text: root.label
                    font.pixelSize: (Theme.size.small + 1) * root.s
                    font.weight: Font.Medium
                }
                ProgressBar {
                    Layout.fillWidth: true
                    visible: root.level >= 0
                    value: Math.max(0, root.level)
                    thickness: 6 * root.s
                    color: root.muted ? Theme.outline : Theme.primary
                }
            }

            StyledText {
                Layout.minimumWidth: 52 * root.s
                horizontalAlignment: Text.AlignRight
                text: root.valueText
                color: root.muted ? Theme.error : Theme.dim
                tabular: true
                font.pixelSize: Theme.size.small * root.s
            }
        }
    }

    // ── In a game: a small see-through pill ──────────────────

    property real pillShown: root.open && root.compact && !root.hidden ? 1 : 0

    Behavior on pillShown {
        Anim {
            duration: root.open ? Theme.anim.medium : Theme.anim.small
        }
    }

    HolePopup {
        screen: root.screen
        position: "bottom"
        margin: Theme.spacing.huge + Theme.spacing.normal
        contentScale: root.s
        shown: root.pillShown > 0.01
        clickThrough: true
        namespace: "qs-osd"

        ScrimPill {
            implicitHeight: 32
            padding: Theme.spacing.large - Theme.spacing.tiny
            spacing: Theme.spacing.normal + Theme.spacing.tiny
            opacity: root.pillShown
            transform: Translate {
                y: 6 * (1 - root.pillShown)
            }

            Icon {
                icon: root.icon
                size: Theme.icon.small - 1
                color: root.muted ? Theme.error : Theme.textOnScrim
            }
            ProgressBar {
                visible: root.level >= 0
                Layout.preferredWidth: 110
                value: Math.max(0, root.level)
                thickness: 4
                color: root.muted ? Theme.error : Theme.primary
                trackColor: Theme.alpha(Theme.textOnScrim, 0.18)
            }
            StyledText {
                text: root.valueText
                color: root.muted ? Theme.error : Theme.textOnScrim
                tabular: true
                font.pixelSize: Theme.size.tiny
            }
        }
    }
}
