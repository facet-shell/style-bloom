import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// Go Live from the bar: drops out under the voice pill's stream button. Resolution, frame
// rate, what the stream is for (smooth or sharp) and which sound goes with it: the whole
// system without some apps, only some apps, or none. Go Live hands that to the Discord
// plugin; the screen or window is then picked in the desktop portal (Wayland asks there),
// Vesktop's own picker is answered for you. The last choice is kept (Config streamSettings).
Drawer {
    id: root

    property Item anchorItem: null
    readonly property real panelWidth: 340
    readonly property var st: DiscordBridge.streamSettings
    // "App" needs a window picked, or the portal would ask after all
    // Hyprland's windows, read when the panel opens: [{ address, name, title }]
    property var windows: []
    readonly property bool windowPicked: windows.some(w => w.address === DiscordBridge.shareWindow)
    readonly property bool ready: DiscordBridge.streamLive || st.source !== "window" || windowPicked

    edge: "top"
    align: "start"
    padding: 14
    radius: Theme.rounding.large
    namespace: "qs-bar-menu"
    keyboard: WlrKeyboardFocus.OnDemand
    onDismissed: open = false
    onOpenChanged: {
        if (open) {
            DiscordBridge.listAudio();
            clients.running = true;
        }
        else
            anchorItem = null;
    }

    // Under `item` in the bar, like BarMenu
    function popup(screen, item) {
        anchorItem = item;
        root.screen = screen;
        const pos = item.mapToItem(null, 0, 0);
        const hole = (screen?.width ?? 1920) - Theme.frame.border * 2;
        const full = panelWidth + padding * 2 + joint * 2;
        align = "start";
        offset = Math.max(Theme.rounding.hole, Math.min(hole - full - Theme.rounding.hole, pos.x - Theme.frame.border - joint - padding));
        open = true;
    }

    function toggleName(key, name) {
        const list = (st[key] ?? []).slice();
        const at = list.indexOf(name);
        if (at >= 0)
            list.splice(at, 1);
        else
            list.push(name);
        DiscordBridge.setStreamSetting(key, list);
    }

    Process {
        id: clients

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                // Windows on a workspace, apps by name; the window class when there is no name
                const shown = list.filter(c => c.mapped && c.workspace?.id > 0 && c.address);
                const count = {};
                for (const c of shown)
                    count[c.class] = (count[c.class] ?? 0) + 1;
                root.windows = shown.map(c => {
                    const name = /^steam_app_/.test(c.class) && c.title ? c.title : (Tasks.entryFor(c.class)?.name ?? Tasks.prettyClass(c.class));
                    return { address: c.address, name: count[c.class] > 1 ? `${name} · ${c.title.slice(0, 24)}` : name, title: c.title };
                }).sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    // A dim label over a row of choices
    component Heading: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        dim: true
        font.pixelSize: Theme.size.small
    }

    ColumnLayout {
        width: parent.width
        implicitWidth: root.panelWidth
        spacing: Theme.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Icon {
                icon: DiscordBridge.streamLive ? "cast_connected" : "cast"
                color: DiscordBridge.streamLive ? Theme.error : Theme.primary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    font.weight: Font.DemiBold
                    text: DiscordBridge.streamLive ? "You are live" : "Go Live"
                }
                StyledText {
                    Layout.fillWidth: true
                    dim: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.size.small
                    text: DiscordBridge.streamLive
                        ? (DiscordBridge.streamViewers.length === 1 ? "1 person watches" : `${DiscordBridge.streamViewers.length} people watch`)
                        : `in ${DiscordBridge.voice.channel}${DiscordBridge.voice.guild ? ` · ${DiscordBridge.voice.guild}` : ""}`
                }
            }
        }

        // What is shown: a whole display, or one app's window (handed to the portal through
        // facet-share-picker, so its picker does not ask again)
        Heading {
            text: "Source"
        }
        SegmentedButtons {
            Layout.fillWidth: true
            model: Quickshell.screens.map(s => ({ key: `screen:${s.name}`, label: s.name, icon: "desktop_windows" }))
                .concat([{ key: "window", label: "App", icon: "web_asset" }])
            current: root.st.source.startsWith("screen:") && !Quickshell.screens.some(s => `screen:${s.name}` === root.st.source)
                ? "" : root.st.source
            onSelected: key => DiscordBridge.setStreamSetting("source", key)
        }
        Flow {
            Layout.fillWidth: true
            visible: root.st.source === "window"
            spacing: 6

            Repeater {
                model: root.windows

                Chip {
                    required property var modelData

                    compact: true
                    selected: DiscordBridge.shareWindow === modelData.address
                    text: modelData.name
                    onClicked: DiscordBridge.shareWindow = modelData.address
                }
            }
        }

        Heading {
            text: "Resolution"
        }
        SegmentedButtons {
            Layout.fillWidth: true
            model: ["480", "720", "1080", "1440", "2160"].map(r => ({ key: r, label: r }))
            current: root.st.resolution
            onSelected: key => DiscordBridge.setStreamSetting("resolution", key)
        }

        Heading {
            text: "Frame rate"
        }
        SegmentedButtons {
            Layout.fillWidth: true
            model: ["15", "30", "60"].map(f => ({ key: f, label: f }))
            current: root.st.fps
            onSelected: key => DiscordBridge.setStreamSetting("fps", key)
        }

        Heading {
            text: "Content type"
        }
        SegmentedButtons {
            Layout.fillWidth: true
            model: [{ key: "motion", label: "Prefer smoothness" }, { key: "detail", label: "Prefer clarity" }]
            current: root.st.hint
            onSelected: key => DiscordBridge.setStreamSetting("hint", key)
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.st.hint === "detail"
            dim: true
            opacity: 0.8
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.size.tiny
            text: "Much sharper, at a much lower frame rate"
        }

        Heading {
            text: "Audio sources"
        }
        SegmentedButtons {
            Layout.fillWidth: true
            model: [{ key: "none", label: "None" }, { key: "system", label: "Entire system" }, { key: "apps", label: "Only apps" }]
            current: root.st.audio
            onSelected: key => DiscordBridge.setStreamSetting("audio", key)
        }

        // The apps playing sound now: left out (everything) or the only ones heard (only apps)
        StyledText {
            Layout.fillWidth: true
            visible: root.st.audio !== "none" && text !== ""
            dim: true
            opacity: 0.8
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.size.tiny
            text: !DiscordBridge.audioSourcesOk ? "Vesktop cannot list the sound sources (venmic)"
                : DiscordBridge.audioSources.length === 0 ? "No app plays sound right now"
                : ""
        }
        Flow {
            Layout.fillWidth: true
            visible: root.st.audio !== "none" && DiscordBridge.audioSources.length > 0
            spacing: 6

            Repeater {
                model: DiscordBridge.audioSources

                Chip {
                    required property var modelData
                    readonly property string key: root.st.audio === "system" ? "exclude" : "include"
                    readonly property bool on: (root.st[key] ?? []).includes(modelData.name)

                    compact: true
                    selected: on
                    icon: root.st.audio === "system" ? (on ? "volume_off" : "volume_up") : (on ? "check" : "")
                    text: modelData.name
                    onClicked: root.toggleName(key, modelData.name)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            spacing: Theme.spacing.small

            StyledText {
                Layout.fillWidth: true
                visible: !DiscordBridge.streamLive
                dim: true
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.size.tiny
                text: root.ready ? "" : "Pick the app to show"
                color: root.ready ? Theme.dim : Theme.error
            }
            Item {
                Layout.fillWidth: true
                visible: DiscordBridge.streamLive
            }
            // Live and edited: Apply slides out of the stop button (it stays, smaller)
            Item {
                id: applySlot

                readonly property bool shown: DiscordBridge.streamEdited

                Layout.preferredWidth: shown ? applyButton.implicitWidth + Theme.spacing.small : 0
                implicitHeight: applyButton.implicitHeight
                clip: true
                opacity: shown ? 1 : 0

                Behavior on Layout.preferredWidth {
                    Anim {}
                }
                Behavior on opacity {
                    Anim {}
                }

                Button {
                    id: applyButton

                    anchors.left: parent.left
                    text: "Apply"
                    icon: "check"
                    variant: "filled"
                    disabled: !root.ready
                    onClicked: {
                        DiscordBridge.updateStream();
                        root.open = false;
                    }
                }
            }
            Button {
                text: !DiscordBridge.streamLive ? "Go Live" : applySlot.shown ? "Stop" : "Stop stream"
                icon: DiscordBridge.streamLive ? "cancel_presentation" : "cast"
                variant: applySlot.shown ? "tonal" : "filled"
                disabled: !DiscordBridge.streamLive && !root.ready
                onClicked: {
                    if (DiscordBridge.streamLive)
                        DiscordBridge.stopStream();
                    else
                        DiscordBridge.startStream();
                    root.open = false;
                }
            }
        }
    }
}
