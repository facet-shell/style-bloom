import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// One notification popup in the look Config.notificationStyle picks: card (picture, app and
// time, title, text, actions as pills, the time left as a thin line), line (one round row)
// or minimal (who and what, a click puts it away). In a game with "compact in a game" on it
// is a see-through pill with the title only; what waits for an answer (calls, invites) keeps
// small buttons there. It springs in from the side it sits on and folds away; the time line
// pauses while the mouse is on it. A ringing call breathes green (ring, glow, ripples on the
// picture, the answer button pulses) until it is answered.
//
// In a stack (Popups groups the popups by app) the front card shows the older ones peeking
// out under it, two at most, with a "+2" count; the count or the stack opens the group, the
// count folds it again. A hidden card takes no room and its countdown waits. A Discord
// message with a channel (Config.notificationInlineReply) gets a reply field in the card:
// Enter sends through the bridge, Esc closes it, the countdown waits while it is open, and
// "sent" shows for a moment before the card goes. Only the card look has the field; a line,
// a minimal one and the in-game pill open Discord instead.
Item {
    id: root

    required property var entry
    // "left", "right" or "center", and whether the popups are at the top (Popups)
    property string side: "right"
    property bool atTop: true
    property bool compact: false
    property real cardWidth: Config.notificationWidth
    property real compactWidth: 320
    // Its place in the app's stack: 0 is the front card, size how many the stack holds,
    // groupOpen whether the stack is unfolded (Popups keeps that)
    property int stackIndex: 0
    property int stackSize: 1
    property bool groupOpen: false

    signal groupToggled()
    // The reply field opened or closed; Popups gives the window the keyboard meanwhile
    signal replyToggled(bool opened)

    readonly property bool isCall: entry.kind === "call"
    readonly property bool mini: entry.kind === "mini"
    // Waits for an answer (a call, a Steam invite): keeps its buttons in every look
    readonly property bool waits: entry.timeout === 0 && entry.actions.length > 0
    readonly property string style: ["card", "line", "minimal"].includes(Config.notificationStyle) ? Config.notificationStyle : "card"
    // Minimal has no buttons, so what waits for an answer shows as a line there
    readonly property string look: compact ? "pill" : style === "minimal" && waits ? "line" : style
    readonly property bool centered: side === "center"
    readonly property int textAlign: centered ? Text.AlignHCenter : Text.AlignLeft
    // With no ok / no styles the first action is the main one (filled)
    readonly property bool styled: entry.actions.some(a => a.style !== "")
    readonly property real pad: Theme.padding.card

    // Hidden under the front card of its stack
    readonly property bool stacked: stackIndex > 0 && !groupOpen
    // How many hide under this card, and how many of them peek out
    readonly property int behind: stackIndex === 0 && !groupOpen ? stackSize - 1 : 0
    readonly property int peeks: Math.min(behind, 2)
    readonly property real peekStep: Theme.spacing.small + Theme.spacing.tiny
    readonly property bool countShown: stackIndex === 0 && stackSize > 1

    // The field fits the card look only; elsewhere "reply" opens Discord like "open"
    readonly property bool canReply: Config.notificationInlineReply && look === "card"
        && (entry.replyChannel ?? "") !== "" && DiscordBridge.connected
    property bool replying: false
    property bool sent: false

    // 1 → 0 over the timeout
    property real remaining: 1
    // 0 → 1 springing in; gone 0 → 1 sliding out, then fold 1 → 0 so the others close up
    property real appear: 0
    property real gone: 0
    property real fold: 1
    // 0 ↔ 1 while a call rings
    property real breath: 0
    property bool leaving: false
    property int tick: 0

    readonly property string ago: {
        root.tick;
        return Notifications.ago(root.entry.time);
    }

    visible: !stacked
    implicitWidth: body.width
    implicitHeight: (body.height + peeks * peekStep) * fold

    // A card born under a stack springs in once it comes to the front or the stack opens
    Component.onCompleted: {
        if (!stacked)
            appear = 1;
    }
    onStackedChanged: {
        if (!stacked)
            appear = 1;
    }
    onReplyingChanged: replyToggled(replying)
    Component.onDestruction: {
        if (replying)
            replyToggled(false);
    }

    Behavior on appear {
        SpringAnim {
            duration: Theme.anim.drawerIn
        }
    }

    // "5m" has to move on while it is on screen
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.tick++
    }

    // The countdown is a timer, not motion: it keeps the entry's own length with animations
    // off. It waits while the mouse is on the card, while the card hides under a stack and
    // while a reply is being typed, so nothing runs out unseen.
    NumberAnimation on remaining {
        from: 1
        to: 0
        duration: Math.max(1, root.entry.timeout)
        running: root.entry.timeout > 0
        paused: running && (hover.hovered || root.stacked || root.replying || root.sent)
        onFinished: root.close(true)
    }

    SequentialAnimation on breath {
        running: root.isCall && Theme.animated
        loops: Animation.Infinite

        Anim {
            to: 1
            duration: Theme.anim.slow
            easing.bezierCurve: Theme.curve.standard
        }
        Anim {
            to: 0
            duration: Theme.anim.slow
            easing.bezierCurve: Theme.curve.standard
        }
    }

    // expired: the timer ran out (the app hears "expired" instead of "dismissed")
    function close(expired) {
        if (leaving)
            return;
        leaving = true;
        leave.expired = expired;
        leave.start();
    }

    // The action runs at once (accepting a call must not wait for the animation); the
    // service's invoke() is this plus the dismiss, split so the card can still fold away.
    // "reply" with a field stays in the card: the field takes over from here.
    function act(id) {
        if (leaving)
            return;
        if (id === "reply" && canReply) {
            openReply();
            return;
        }
        if (root.entry.onAction)
            root.entry.onAction(id);
        close(false);
    }

    function openReply() {
        replyField.text = "";
        replying = true;
        replyField.focusField();
        // Again once the window has the keyboard
        Qt.callLater(replyField.focusField);
    }

    function sendReply() {
        const text = replyField.text.trim();
        if (text === "")
            return;
        DiscordBridge.reply(root.entry.replyChannel, text);
        replying = false;
        sent = true;
        sentHold.start();
    }

    // "sent" stays readable for a moment (a hold, not motion), then the card goes
    Timer {
        id: sentHold

        interval: 1200
        onTriggered: root.close(false)
    }

    function actionIcon(id) {
        const icons = {
            accept: isCall ? "call" : "check",
            decline: "call_end",
            call: "call",
            open: "open_in_new",
            reply: "reply",
            join: "login",
            chat: "chat",
            show: "group",
            play: "play_arrow",
            downloads: "download",
            done: "check",
            edit: "edit",
            folder: "folder_open",
            copy: "content_copy",
            delete: "delete",
            unmute: "mic",
            undeafen: "headphones"
        };
        return icons[id] ?? "";
    }

    SequentialAnimation {
        id: leave

        property bool expired: false

        Anim {
            target: root
            property: "gone"
            to: 1
            duration: Theme.anim.small
            easing.bezierCurve: Theme.curve.emphasizedAccel
        }
        Anim {
            target: root
            property: "fold"
            to: 0
            duration: Theme.anim.small
        }
        ScriptAction {
            script: Notifications.dismiss(root.entry.uid, leave.expired)
        }
    }

    // ── Pieces ───────────────────────────────────────────────

    // One of the notification's actions as a pill; small in lines and in-game pills. An
    // inline component does not see this file's ids, so the card comes in as `card`.
    component Action: Item {
        id: action

        required property var modelData
        required property int index
        property var card: null
        property bool small: false
        // A ringing call's answer pulses with the ring
        readonly property bool pulses: (card?.isCall ?? false) && modelData.style === "ok"

        implicitWidth: button.implicitWidth
        implicitHeight: button.implicitHeight
        scale: pulses ? 1 + 0.07 * card.breath : 1

        Button {
            id: button

            anchors.centerIn: parent
            text: action.modelData.label
            icon: action.small || !action.card ? "" : action.card.actionIcon(action.modelData.id)
            compact: action.small
            variant: action.modelData.style === "ok" ? "ok"
                : action.modelData.style === "no" ? "danger"
                : action.index === 0 && !(action.card?.styled ?? false) ? "filled"
                : "plain"
            onClicked: action.card.act(action.modelData.id)
        }
    }

    // The stack's "+2": a click unfolds the group, another folds it; filled while open
    component Count: Rectangle {
        id: count

        property var card: null
        readonly property bool open: card?.groupOpen ?? false

        implicitWidth: countText.implicitWidth + Theme.spacing.normal * 2
        implicitHeight: 18
        radius: height / 2
        color: open ? Theme.primary : Theme.primaryContainer

        Behavior on color {
            ColorAnim {}
        }

        StyledText {
            id: countText

            anchors.centerIn: parent
            text: `+${(count.card?.stackSize ?? 1) - 1}`
            color: count.open ? Theme.textOnPrimary : Theme.textOnPrimaryContainer
            font.pixelSize: Theme.size.tiny
            font.weight: Font.Medium
        }

        StateLayer {
            color: countText.color
            onClicked: count.card.groupToggled()
        }
    }

    // ── The card itself ──────────────────────────────────────

    Item {
        id: body

        width: root.look === "pill" ? root.compactWidth
            : root.look === "minimal" ? Math.min(root.cardWidth, minimalRow.implicitWidth + root.pad * 2)
            : root.cardWidth
        height: root.look === "card" ? cardRow.implicitHeight + root.pad * 2
            : root.look === "line" ? 52
            : root.look === "pill" ? 42
            : 36
        opacity: Math.min(1, root.appear) * (1 - root.gone)
        scale: 0.92 + 0.08 * root.appear - 0.05 * root.gone
        transformOrigin: root.side === "left" ? Item.Left : root.side === "right" ? Item.Right : root.atTop ? Item.Top : Item.Bottom
        // In from the side it sits on and out the same way; in the middle from the edge
        transform: Translate {
            x: root.side === "right" ? 70 * (1 - root.appear) + 50 * root.gone
                : root.side === "left" ? -70 * (1 - root.appear) - 50 * root.gone
                : 0
            y: root.centered ? (root.atTop ? -24 : 24) * (1 - root.appear + root.gone) : 0
        }

        HoverHandler {
            id: hover
        }

        // The stack under the front card: the older ones peek out below it, each one
        // narrower and fainter than the one above
        Repeater {
            model: root.peeks

            delegate: Rectangle {
                required property int index

                z: -1
                anchors.horizontalCenter: parent.horizontalCenter
                y: (index + 1) * root.peekStep
                width: parent.width - (index + 1) * Theme.spacing.large
                height: parent.height
                radius: bg.radius
                color: Theme.high
                opacity: 0.85 - index * 0.35
            }
        }

        // Drawn by the effect below, which adds the shadow (or a ringing call's green glow)
        Rectangle {
            id: bg

            anchors.fill: parent
            visible: false
            radius: root.look === "card" ? Theme.rounding.large : height / 2
            color: root.look === "pill" ? Theme.scrim : Theme.container

            Behavior on color {
                ColorAnim {
                    duration: Theme.anim.color
                }
            }
        }

        MultiEffect {
            source: bg
            anchors.fill: bg
            autoPaddingEnabled: true
            // The in-game pill has none: no frame, no shadow over the picture
            shadowEnabled: root.look !== "pill"
            shadowColor: root.isCall ? Theme.ok : Theme.shadowColor
            shadowOpacity: root.isCall ? 0.2 + 0.45 * root.breath : 0.8
            shadowBlur: 1
            blurMax: root.isCall ? 28 : 40
            shadowVerticalOffset: root.isCall ? 0 : 10
        }

        // A ringing call: a green ring that breathes
        Rectangle {
            visible: root.isCall
            anchors.fill: parent
            anchors.margins: -2
            radius: bg.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.ok
            opacity: 0.7 + 0.3 * root.breath
        }

        // ── card ──

        RowLayout {
            id: cardRow

            visible: root.look === "card"
            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: Theme.spacing.medium

            NoteIcon {
                visible: !root.centered
                Layout.alignment: Qt.AlignTop
                entry: root.entry
                size: root.mini ? 36 : 46
                ripple: root.isCall
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.tiny

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: root.textAlign
                        text: root.entry.app
                        dim: true
                        font.pixelSize: Theme.size.tiny
                    }
                    Count {
                        visible: root.countShown
                        card: root
                    }
                    // Makes room for the close button while the mouse is on the card
                    StyledText {
                        text: root.ago
                        dim: true
                        tabular: true
                        font.pixelSize: Theme.size.tiny
                        opacity: 1 - closer.opacity
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: root.textAlign
                    text: root.entry.title
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    horizontalAlignment: root.textAlign
                    text: root.entry.body
                    dim: true
                    font.pixelSize: Theme.size.small
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.mini ? 2 : 3
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.normal
                    visible: root.entry.actions.length > 0 && !root.replying && !root.sent
                    spacing: Theme.spacing.normal

                    Repeater {
                        model: root.entry.actions

                        delegate: Action {
                            card: root
                        }
                    }
                }

                // The reply field in place of the actions: Enter sends, Esc closes it
                SearchField {
                    id: replyField

                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.normal
                    Layout.preferredHeight: 40
                    visible: root.replying
                    icon: "reply"
                    placeholder: `reply to ${root.entry.replyTo || root.entry.app}`
                    hint: "enter"
                    baseColor: Theme.high
                    onAccepted: root.sendReply()
                    onEscaped: root.replying = false
                }

                // What the field leaves behind until the card goes
                RowLayout {
                    Layout.topMargin: Theme.spacing.normal
                    visible: root.sent
                    spacing: Theme.spacing.small

                    Icon {
                        icon: "check"
                        size: Theme.icon.small
                        color: Theme.ok
                    }
                    StyledText {
                        text: "sent"
                        color: Theme.ok
                        font.pixelSize: Theme.size.small
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // Close, in the corner while the mouse is on it; a call has to be answered instead
        IconButton {
            id: closer

            visible: root.look === "card" && !root.isCall && opacity > 0.01
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacing.normal
            size: 28
            iconSize: Theme.icon.small - 2
            icon: "close"
            opacity: hover.hovered ? 1 : 0
            onClicked: root.close(false)

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.small
                }
            }
        }

        // ── line ──

        RowLayout {
            visible: root.look === "line"
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.normal
            anchors.rightMargin: Theme.spacing.normal
            spacing: Theme.spacing.medium

            NoteIcon {
                visible: !root.centered
                entry: root.entry
                size: 36
                round: true
                ripple: root.isCall
            }
            StyledText {
                text: root.entry.app
                dim: true
                font.pixelSize: Theme.size.tiny
            }
            Count {
                visible: root.countShown
                card: root
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: root.textAlign
                text: root.entry.body !== "" ? `${root.entry.title}  ·  ${root.entry.body}` : root.entry.title
                font.pixelSize: Theme.size.small
            }
            Repeater {
                model: root.entry.actions

                delegate: Action {
                    card: root
                    small: true
                }
            }
            IconButton {
                visible: !root.isCall
                size: 28
                iconSize: Theme.icon.small - 2
                icon: "close"
                onClicked: root.close(false)
            }
        }

        // ── minimal ──

        Row {
            id: minimalRow

            visible: root.look === "minimal"
            anchors.centerIn: parent
            spacing: Theme.spacing.normal

            StyledText {
                text: root.entry.app
                color: root.entry.critical ? Theme.error : Theme.primary
                font.pixelSize: Theme.size.small
                font.weight: Font.Medium
            }
            StyledText {
                width: Math.min(implicitWidth, root.cardWidth - 120)
                text: root.entry.title
                font.pixelSize: Theme.size.small
            }
            Count {
                visible: root.countShown
                anchors.verticalCenter: parent.verticalCenter
                card: root
            }
        }

        // A click on a minimal one puts it away (its count sits above this and opens the stack)
        MouseArea {
            anchors.fill: parent
            enabled: root.look === "minimal"
            visible: enabled
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close(false)
        }

        // ── in a game: the see-through pill ──

        RowLayout {
            visible: root.look === "pill"
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.small + Theme.spacing.tiny
            anchors.rightMargin: Theme.spacing.medium
            spacing: Theme.spacing.normal

            NoteIcon {
                entry: root.entry
                size: 30
                round: true
            }
            StyledText {
                Layout.fillWidth: true
                text: root.entry.title
                color: Theme.textOnScrim
                font.pixelSize: Theme.size.small
                font.weight: Font.Medium
            }
            // Just the count here; a pill does not unfold
            StyledText {
                visible: root.countShown
                text: `+${root.stackSize - 1}`
                color: Theme.textOnScrim
                opacity: 0.8
                font.pixelSize: Theme.size.tiny
                font.weight: Font.Medium
            }
            Repeater {
                model: root.waits ? root.entry.actions : []

                delegate: Action {
                    card: root
                    small: true
                }
            }
        }

        // Time left, shrinking toward the start
        Rectangle {
            readonly property real inset: bg.radius * 0.8

            visible: root.entry.timeout > 0 && (root.look === "card" || root.look === "line")
            anchors.bottom: parent.bottom
            x: root.centered ? (parent.width - width) / 2 : inset
            width: (parent.width - inset * 2) * root.remaining
            height: 3
            radius: height / 2
            color: root.entry.critical ? Theme.error : Theme.primary
            opacity: 0.7
        }
    }

    // A click on the peeking stack opens the group too
    MouseArea {
        visible: root.peeks > 0 && root.look !== "pill"
        x: body.x
        y: body.height
        width: body.width
        height: root.peeks * root.peekStep
        cursorShape: Qt.PointingHandCursor
        onClicked: root.groupToggled()
    }
}
