import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The Discord voice overlay while you are in a voice channel: round faces with a green ring
// for who talks, names, mic-off and deafen icons, LIVE for who streams, an eye with the count
// of who watches your own stream (their faces too in the list look), and a short feed of
// joins, leaves and your own mute as lines that fade. No frame and no background, only a soft
// shadow so it reads over any game; every click goes through it. Super+Shift+V moves it: then
// it takes the mouse, drag it anywhere, Esc or the key again keeps the spot (per screen).
// Config.voiceOverlay* says when it shows and how (list, compact: faces in a row, talking:
// only who talks); in a game with Bloom.compact("voice") the faces are smaller. The data
// comes from the Vencord plugin through DiscordBridge.
Scope {
    id: root

    property bool hidden: false
    property bool moving: false

    readonly property string look: Config.voiceOverlayLook
    readonly property var members: {
        const list = DiscordBridge.voice.members;
        return look === "talking" ? list.filter(m => m.you || DiscordBridge.speaking[m.userId]) : list;
    }
    // Faces in a row, the name under one only while it talks
    readonly property bool inRow: look === "compact"
    readonly property bool small: Bloom.compact("voice")
    readonly property real size: Bloom.scale("voice")
    readonly property real face: small ? 26 : 36

    // Who watches your stream, shaped like a member so Face can draw them
    readonly property var viewers: DiscordBridge.streamViewers.map(v => ({ userId: v.id, name: v.name, avatar: v.avatar }))
    readonly property bool eyeShown: DiscordBridge.streamLive && viewers.length > 0

    // Who was there already: only newcomers pop in (the list is replaced on every change)
    property var seen: ({})

    onMembersChanged: Qt.callLater(() => {
        const next = {};
        for (const m of root.members)
            next[m.userId] = true;
        root.seen = next;
    })

    // The feed: newest first, each line goes after a few seconds
    property var lines: []
    property int nextLine: 0

    Connections {
        target: DiscordBridge

        function onVoiceLine(text, kind) {
            root.lines = [{ id: root.nextLine++, text, kind, until: Date.now() + 4500 }].concat(root.lines).slice(0, 3);
        }
    }

    Timer {
        running: root.lines.length > 0
        interval: 250
        repeat: true
        onTriggered: root.lines = root.lines.filter(l => l.until > Date.now())
    }

    // Kept per screen: two screens of different sizes each have their own spot
    function savePos(screenName, x, y) {
        const next = Object.assign({}, Config.voiceOverlayPos);
        next[screenName] = [Math.round(x), Math.round(y)];
        Config.set("voiceOverlayPos", next);
    }

    onHiddenChanged: if (hidden)
        moving = false

    IpcHandler {
        target: "voice"

        // Super+Shift+V
        function move(): void {
            root.moving = !root.moving;
        }

        // Super+Shift+M and Super+Shift+D, from inside a game too
        function mute(): void {
            DiscordBridge.send({ cmd: "toggle_mute" });
        }

        function deafen(): void {
            DiscordBridge.send({ cmd: "toggle_deafen" });
        }

        function leave(): void {
            DiscordBridge.send({ cmd: "leave_voice" });
        }
    }

    // ── Pieces ───────────────────────────────────────────────

    // A round face with the green ring while its mic is open; pop springs it in
    component Face: Item {
        id: face

        required property var person
        property real size: 36
        property real pop: 1
        readonly property bool talking: DiscordBridge.speaking[person.userId] === true

        implicitWidth: size
        implicitHeight: size

        Rectangle {
            anchors.fill: parent
            anchors.margins: -face.size / 9
            radius: width / 2
            color: "transparent"
            border.width: face.size > 30 ? 2.5 : 2
            border.color: Theme.ok
            opacity: face.talking ? 1 : 0
            scale: face.talking ? 1 : 0.8

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.small
                }
            }
            Behavior on scale {
                SpringAnim {}
            }
        }

        AppIcon {
            anchors.fill: parent
            size: face.size
            round: true
            scale: face.pop
            source: face.person.avatar ?? ""
            letter: (face.person.name ?? "?").slice(0, 2).toUpperCase()
        }
    }

    // Muted or deafened, red
    component StateIcon: Icon {
        required property var person

        icon: person.deafened ? "headset_off" : person.muted ? "mic_off" : ""
        size: Theme.icon.small
        color: Theme.error
    }

    component Live: Rectangle {
        implicitWidth: liveText.implicitWidth + Theme.spacing.normal * 2
        implicitHeight: liveText.implicitHeight + Theme.spacing.tiny * 2
        radius: height / 2
        color: Theme.errorContainer

        StyledText {
            id: liveText

            anchors.centerIn: parent
            text: "LIVE"
            color: Theme.textOnErrorContainer
            font.pixelSize: Theme.size.tiny - 2
            font.weight: Font.Bold
        }
    }

    // An eye and how many watch your stream; only on your own entry while it runs, fades in and out
    component Eye: Row {
        id: eye

        required property var person
        property real iconSize: Theme.icon.small

        spacing: Theme.spacing.tiny
        opacity: person.you === true && root.eyeShown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                duration: Theme.anim.small
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "visibility"
            size: eye.iconSize
            color: Theme.primary
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.viewers.length)
            color: Theme.primary
            font.pixelSize: eye.iconSize - 5
            font.weight: Font.Bold
        }
    }

    // ── Window ───────────────────────────────────────────────

    PanelWindow {
        id: window

        screen: Bloom.focusedScreen
        readonly property string screenName: screen?.name ?? ""
        // Without a saved spot: on the left under the bar, or near the top with the frame away
        readonly property var pos: Config.voiceOverlayPos[screenName] ?? [28, Bloom.frameAway ? 60 : 120]

        visible: !root.hidden && (DiscordBridge.overlayShown || root.moving)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-voice-overlay"
        // Moving takes Esc; otherwise the game keeps the keyboard
        WlrLayershell.keyboardFocus: root.moving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Clicks go through everywhere, except while moving
        mask: root.moving ? null : passThrough

        Region {
            id: passThrough
        }

        function place() {
            card.x = Math.max(0, Math.min(width - card.width * root.size, pos[0]));
            card.y = Math.max(0, Math.min(height - card.height * root.size, pos[1]));
        }

        onPosChanged: place()
        onWidthChanged: place()
        onHeightChanged: place()

        Item {
            anchors.fill: parent
            focus: root.moving
            Keys.onEscapePressed: root.moving = false
        }

        Item {
            id: card

            width: content.width + Theme.spacing.medium * 2
            height: content.height + Theme.spacing.medium * 2
            scale: root.size
            transformOrigin: Item.TopLeft
            Component.onCompleted: window.place()

            // Only while moving: something to see what you drag
            Rectangle {
                anchors.fill: parent
                radius: Theme.rounding.large
                color: Theme.alpha(Theme.surface, 0.55)
                border.width: 2
                border.color: Theme.primary
                opacity: root.moving ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.small
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.moving
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: card
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: window.width - card.width * root.size
                drag.maximumY: window.height - card.height * root.size
                onReleased: root.savePos(window.screenName, card.x, card.y)
            }

            Column {
                id: content

                x: Theme.spacing.medium
                y: Theme.spacing.medium
                spacing: root.small ? Theme.spacing.small + Theme.spacing.tiny : Theme.spacing.medium - Theme.spacing.tiny

                // A soft shadow under faces and names instead of a background
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowColor
                    shadowBlur: 0.5
                    blurMax: 12
                    shadowVerticalOffset: 1
                    autoPaddingEnabled: true
                }

                // Moving without a call: something to grab
                StyledText {
                    visible: root.moving && root.members.length === 0
                    text: "voice overlay"
                    color: Theme.textOnScrim
                }

                // ── list and "only who talks": one row each ──

                Column {
                    visible: !root.inRow
                    spacing: root.small ? Theme.spacing.small + Theme.spacing.tiny : Theme.spacing.medium - Theme.spacing.tiny

                    Repeater {
                        model: ScriptModel {
                            values: root.inRow ? [] : root.members
                        }

                        delegate: Row {
                            id: row

                            required property var modelData
                            readonly property bool talking: DiscordBridge.speaking[modelData.userId] === true
                            property real enter: 1

                            spacing: root.small ? Theme.spacing.normal : Theme.spacing.medium - Theme.spacing.tiny
                            opacity: Config.voiceOverlayDim && !talking && root.look === "list" ? 0.6 : 1

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.anim.small
                                }
                            }

                            Component.onCompleted: if (!(root.seen[modelData.userId] ?? false))
                                arrive.start()

                            // Joined: the face springs in, the name follows
                            ParallelAnimation {
                                id: arrive

                                SpringAnim {
                                    target: rowFace
                                    property: "pop"
                                    from: 0
                                    to: 1
                                    duration: Theme.anim.drawerIn
                                }
                                Anim {
                                    target: row
                                    property: "enter"
                                    from: 0
                                    to: 1
                                }
                            }

                            Face {
                                id: rowFace

                                anchors.verticalCenter: parent.verticalCenter
                                person: row.modelData
                                size: root.face
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 200)
                                text: row.modelData.name ?? ""
                                color: row.talking ? Theme.textOnScrim : Theme.dim
                                font.pixelSize: root.small ? Theme.size.tiny : Theme.size.small + 1
                                opacity: row.enter
                                transform: Translate {
                                    x: -8 * (1 - row.enter)
                                }
                            }
                            Live {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.modelData.streaming === true
                            }
                            StateIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                person: row.modelData
                                size: root.small ? Theme.icon.small - 3 : Theme.icon.small
                            }
                            Eye {
                                anchors.verticalCenter: parent.verticalCenter
                                person: row.modelData
                                iconSize: root.small ? Theme.icon.small - 3 : Theme.icon.small
                            }
                            // The viewers' faces, smaller than the members'; the list look only
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacing.small
                                visible: row.modelData.you === true && root.eyeShown && root.look === "list"

                                Repeater {
                                    model: ScriptModel {
                                        values: row.modelData.you === true ? root.viewers : []
                                    }

                                    delegate: Face {
                                        required property var modelData

                                        person: modelData
                                        size: root.small ? 18 : 22
                                    }
                                }
                            }
                        }
                    }
                }

                // ── compact: faces in a row, the name under one while it talks ──

                Row {
                    visible: root.inRow
                    spacing: root.small ? Theme.spacing.small + Theme.spacing.tiny : Theme.spacing.medium - Theme.spacing.tiny

                    Repeater {
                        model: ScriptModel {
                            values: root.inRow ? root.members : []
                        }

                        delegate: Column {
                            id: cell

                            required property var modelData
                            readonly property bool talking: DiscordBridge.speaking[modelData.userId] === true
                            readonly property real cellWidth: root.face + 10

                            width: cellWidth
                            spacing: Theme.spacing.small

                            Component.onCompleted: if (!(root.seen[modelData.userId] ?? false))
                                cellArrive.start()

                            SpringAnim {
                                id: cellArrive

                                target: cellFace
                                property: "pop"
                                from: 0
                                to: 1
                                duration: Theme.anim.drawerIn
                            }

                            Item {
                                width: cell.cellWidth
                                height: root.face

                                Face {
                                    id: cellFace

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    person: cell.modelData
                                    size: root.face
                                }
                                StateIcon {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -Theme.spacing.small
                                    person: cell.modelData
                                    size: Theme.icon.small - 4
                                }
                                Live {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: -Theme.spacing.small
                                    visible: cell.modelData.streaming === true
                                    scale: 0.8
                                }
                                // Bottom left, the mute icon has the bottom right
                                Eye {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -Theme.spacing.small
                                    person: cell.modelData
                                    iconSize: Theme.icon.small - 4
                                }
                            }
                            StyledText {
                                width: cell.cellWidth
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.modelData.name ?? ""
                                color: Theme.textOnScrim
                                font.pixelSize: Theme.size.tiny - 1
                                opacity: cell.talking ? 1 : 0

                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.anim.small
                                    }
                                }
                            }
                        }
                    }
                }

                // ── the feed: joins, leaves, going live, your mute ──

                Column {
                    visible: root.lines.length > 0
                    spacing: Theme.spacing.tiny

                    Repeater {
                        model: ScriptModel {
                            values: root.lines
                        }

                        delegate: StyledText {
                            id: line

                            required property var modelData

                            width: Math.min(implicitWidth, 260)
                            text: modelData.text
                            font.pixelSize: root.small ? Theme.size.tiny : Theme.size.small
                            color: modelData.kind === "in" ? Theme.ok : modelData.kind === "self" ? Theme.error : Theme.dim
                            opacity: 0

                            Component.onCompleted: opacity = 1

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.anim.medium
                                }
                            }

                            // Fades before the feed drops it
                            Timer {
                                running: true
                                interval: Math.max(0, line.modelData.until - Date.now() - Theme.anim.medium)
                                onTriggered: line.opacity = 0
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.moving
                    text: "drag · Esc or Super+Shift+V to finish"
                    color: Theme.primary
                    font.pixelSize: Theme.size.tiny
                }
            }
        }
    }
}
