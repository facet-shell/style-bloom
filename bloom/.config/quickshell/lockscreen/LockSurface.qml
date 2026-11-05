import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// One bloom lockscreen per monitor. The desktop snapshot blurs and darkens in, the clock
// rises in digit by digit in the accent, then the date, the password pill and the hint; the
// weather (top right), the music (bottom left) and what arrived meanwhile (bottom right)
// follow. A wrong password shakes the pill and turns it red. The right one turns it green,
// the clock flies up, the rest sinks and fades and the blur clears off the desktop, all
// inside Lock.qml's release delay (Theme.anim.slow).
//
// With Config.lockAmbient, Config.lockAmbientMinutes without input turn the screen ambient:
// the clock shrinks, goes dim and drifts a little every half minute (burn-in), the date, the
// pill and the hint fade, the blur and the darkening deepen, the corners dim. Any key or the
// mouse on any monitor brings it all back at once. The surfaces share the state through the
// LockAmbient singleton; only the one with the login keeps the time.
//
// Same API as tui's LockSurface: context, snapshot, showLogin. Lock.qml and LockContext.qml
// (session lock, PAM, idle, sleep, IPC) stay tui's.
Item {
    id: root

    required property LockContext context
    required property string snapshot
    // false on the other monitors: only the blurred snapshot
    property bool showLogin: true

    // 0 → 1: how far the blur, the darkening and the tint have come in
    property real backdrop: 0
    // Between one part's start and the next one's
    readonly property int step: Math.round(Theme.anim.fast / 3)
    // When this surface came up; the notes count from here
    readonly property date lockedAt: new Date()

    readonly property string pillMode: context.unlocking ? "good"
        : context.unlockInProgress ? "busy"
        : context.showFailure ? "bad"
        : "idle"

    // The field has to hold the focus before the first keystroke; on the real lock the
    // surface learns its screen only after it exists, so the focus is set again when
    // showLogin flips and once more a moment after the surface appeared, when the compositor
    // has handed the keyboard over (tui's LockSurface explains it at length)
    function focusInput() {
        input.forceActiveFocus();
    }

    onShowLoginChanged: {
        focusInput();
        restartIdle();
    }

    Timer {
        running: true
        interval: 150
        onTriggered: root.focusInput()
    }

    // The keyboard can come later than both: a lock taken while another VT is shown gets
    // it only when the user switches back. Take the focus again then, and on any click (the
    // field is invisible, so there is nothing else to click into). Lowest in the stack, so
    // the media buttons and the rest keep their own clicks.
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.Window.window.active)
                root.focusInput();
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            root.focusInput();
            LockAmbient.touched();
            mouse.accepted = false;
        }
    }

    // Every mouse move counts as input, also over the media buttons (a HoverHandler does not
    // take the hover away from them)
    HoverHandler {
        onPointChanged: LockAmbient.touched()
    }

    Component.onCompleted: {
        focusInput();
        restartIdle();
        clockView.enter(root.step);
        enter.start();
    }

    // A preview dropped early or an unlock: the next lock starts awake
    Component.onDestruction: {
        if (root.showLogin)
            LockAmbient.idle = false;
    }

    // ── The one password field ───────────────────────────────

    // Never seen: the pill draws the dots. Every monitor has one, so typing works on any of
    // them, and they keep each other in step through the context.
    TextInput {
        id: input

        width: 1
        height: 1
        opacity: 0
        focus: true
        // readOnly rather than disabled: a disabled field drops the focus and would not get
        // it back after a wrong password
        readOnly: root.context.unlockInProgress || root.context.unlocking
        echoMode: TextInput.Password

        onTextChanged: root.context.currentText = text
        onAccepted: {
            if (root.context.currentText === "")
                pill.shake();
            else
                root.context.tryUnlock();
        }
        // Not accepted, so the key still lands in the field: a keystroke wakes and types
        Keys.onPressed: LockAmbient.touched()
        Keys.onEscapePressed: root.context.currentText = ""

        Connections {
            target: root.context
            function onCurrentTextChanged() {
                if (input.text !== root.context.currentText)
                    input.text = root.context.currentText;
            }
        }
    }

    Connections {
        target: root.context

        function onFailed() {
            pill.shake();
        }

        function onUnlockingChanged() {
            if (root.context.unlocking) {
                enter.stop();
                // Ambient stays where it is: leave flies the clock from wherever it drifted
                // to, and the backdrop clears whatever `ambient` holds
                idleTimer.stop();
                settle.stop();
                wake.stop();
                glide.stop();
                leave.start();
            }
        }
    }

    // ── Ambient: after a while without input ─────────────────

    // 0 → 1: how far the surface has gone ambient
    property real ambient: 0

    // Input anywhere lands here (LockAmbient.touched). Only the surface with the login keeps
    // the time; the others just follow LockAmbient.idle
    function restartIdle() {
        idleTimer.stop();
        if (!root.showLogin || root.context.unlocking)
            return;
        LockAmbient.idle = false;
        if (Config.lockAmbient)
            idleTimer.restart();
    }

    Timer {
        id: idleTimer
        interval: Math.max(1, Config.lockAmbientMinutes) * 60 * 1000
        onTriggered: LockAmbient.idle = true
    }

    Connections {
        target: LockAmbient

        function onTouched() {
            root.restartIdle();
        }

        function onIdleChanged() {
            if (root.context.unlocking)
                return;
            if (LockAmbient.idle) {
                wake.stop();
                settle.restart();
            } else {
                settle.stop();
                glide.stop();
                wake.restart();
            }
        }
    }

    // ── Backdrop: the desktop, blurred and darkened ──────────

    Rectangle {
        anchors.fill: parent
        color: Theme.page
    }

    Image {
        id: shot

        anchors.fill: parent
        source: root.snapshot !== "" ? `file://${root.snapshot}` : ""
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        // Ambient takes the blur the rest of the way to full and darkens further; both
        // scale with backdrop, so the unlock clears them whatever ambient holds
        blur: (Config.lockBlur + (1 - Config.lockBlur) * root.ambient) * root.backdrop
        brightness: -(0.42 + 0.2 * root.ambient) * root.backdrop
        saturation: 0.2 * root.backdrop
        // A touch of zoom hides the blur's soft edges
        scale: 1 + 0.03 * root.backdrop
    }

    // The mockup's wash of the surface tone over the blur
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        opacity: (0.35 + 0.15 * root.ambient) * root.backdrop
    }

    // ── Center: clock, date, password, hint ──────────────────

    Item {
        id: center

        visible: root.showLogin
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // A little above the middle, like the mockup (clock at 150 of 900)
        anchors.verticalCenterOffset: -parent.height * 0.07
        width: Math.max(clockView.implicitWidth, pill.implicitWidth)
        // From the resting places, so the column does not move while its parts rise in
        height: dateTop + dateText.height + pillGap + pill.height + hintGap + hint.height

        // The mockup's spacing: clock, 24, date, 104, pill, 14, hint
        readonly property real dateTop: clockView.height + 24
        readonly property real pillGap: 104
        readonly property real hintGap: 14

        LockClock {
            id: clockView

            anchors.horizontalCenter: parent.horizontalCenter
            time: clock.date
            ambient: root.ambient
            dimmed: LockAmbient.idle
        }

        // Date, pill and hint fade out while ambient
        StyledText {
            id: dateText

            property real rise: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: center.dateTop + 16 * (1 - rise)
            opacity: rise * (1 - root.ambient)
            text: clock.date.toLocaleDateString(Qt.locale("en_GB"), "dddd d MMMM")
            font.pixelSize: Theme.size.large + 2
        }

        PasswordPill {
            id: pill

            property real rise: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: center.dateTop + dateText.height + center.pillGap + 16 * (1 - rise)
            opacity: rise * (1 - root.ambient)
            count: root.context.currentText.length
            mode: root.pillMode
            onSubmitted: input.accepted()
        }

        StyledText {
            id: hint

            property real rise: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: center.dateTop + dateText.height + center.pillGap + pill.height + center.hintGap + 16 * (1 - rise)
            opacity: rise * (1 - root.ambient)
            color: root.context.showFailure ? Theme.error : root.capsLock ? Theme.warn : Theme.dim
            font.pixelSize: Theme.size.small
            text: root.context.unlocking ? "welcome back"
                : root.context.unlockInProgress ? "checking …"
                : root.context.showFailure ? "wrong password, try again"
                : root.capsLock ? "caps lock is on"
                : "enter to unlock · esc to clear"
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Corners: weather, music, notes ───────────────────────

    // They stay while ambient, at 0.6
    LockWeather {
        id: weather

        property real rise: 0

        visible: root.showLogin && Weather.ready
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 44
        anchors.topMargin: 36 + 30 * (1 - rise)
        opacity: rise * (1 - 0.4 * root.ambient)
    }

    LockMedia {
        id: media

        property real rise: 0

        visible: root.showLogin && player !== null
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40 - 30 * (1 - rise)
        opacity: rise * (1 - 0.4 * root.ambient)
    }

    LockNotes {
        id: notes

        property real rise: 0

        visible: root.showLogin && groups.length > 0
        since: root.lockedAt
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 40 - 30 * (1 - rise)
        opacity: rise * (1 - 0.4 * root.ambient)
    }

    // ── Coming in, going out ─────────────────────────────────

    // Rises one thing in after `delay`
    component RiseIn: SequentialAnimation {
        id: riseIn

        property Item item
        property int delay: 0
        property int length: Theme.anim.drawerIn

        PauseAnimation {
            duration: riseIn.delay
        }
        Anim {
            target: riseIn.item
            property: "rise"
            to: 1
            duration: riseIn.length
        }
    }

    // Sinks one thing away, faster and accelerating, as things that leave for good do
    component SinkOut: Anim {
        property: "rise"
        to: 0
        duration: Theme.anim.small
        easing.bezierCurve: Theme.curve.emphasizedAccel
    }

    ParallelAnimation {
        id: enter

        Anim {
            target: root
            property: "backdrop"
            to: 1
            duration: Theme.anim.drawerIn
        }
        RiseIn {
            item: dateText
            delay: root.step * 4
        }
        RiseIn {
            item: pill
            delay: root.step * 5
        }
        RiseIn {
            item: hint
            delay: root.step * 6
        }
        RiseIn {
            item: weather
            delay: root.step * 4
        }
        RiseIn {
            item: media
            delay: root.step * 6
        }
        RiseIn {
            item: notes
            delay: root.step * 7
        }
    }

    // A moment of green, then everything leaves and the desktop clears up underneath
    SequentialAnimation {
        id: leave

        PauseAnimation {
            duration: root.step * 2
        }
        ParallelAnimation {
            Anim {
                target: clockView
                property: "fly"
                to: 1
                duration: Theme.anim.medium
                easing.bezierCurve: Theme.curve.emphasizedAccel
            }
            SinkOut {
                target: dateText
            }
            SinkOut {
                target: pill
            }
            SinkOut {
                target: hint
            }
            SinkOut {
                target: weather
            }
            SinkOut {
                target: media
            }
            SinkOut {
                target: notes
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: root.step * 2
                }
                Anim {
                    target: root
                    property: "backdrop"
                    to: 0
                    duration: Theme.anim.drawerOut
                }
            }
        }
    }

    // ── Ambient: settling in, waking, the clock's drift ──────

    // Settling in takes its time; coming back is quick, like a drawer
    Anim {
        id: settle

        target: root
        property: "ambient"
        to: 1
        duration: Theme.anim.slow * 2
    }

    ParallelAnimation {
        id: wake

        Anim {
            target: root
            property: "ambient"
            to: 0
            duration: Theme.anim.drawerIn
        }
        Anim {
            target: clockView
            property: "driftX"
            to: 0
            duration: Theme.anim.drawerIn
        }
        Anim {
            target: clockView
            property: "driftY"
            to: 0
            duration: Theme.anim.drawerIn
        }
    }

    // Every 30 to 60 s the clock glides to a new spot within ±8 % of the screen around its
    // resting place, so nothing burns in. Not with motion off: dimming is enough then.
    function glideWait() {
        return 30000 + Math.round(Math.random() * 30000);
    }

    function glideOn() {
        glideX.to = (Math.random() * 2 - 1) * root.width * 0.08;
        glideY.to = (Math.random() * 2 - 1) * root.height * 0.08;
        glide.restart();
    }

    Timer {
        id: glideTimer

        running: LockAmbient.idle && root.showLogin && Theme.motion !== "off" && !root.context.unlocking
        repeat: true
        interval: 30000
        // A fresh wait each time; setting it restarts the count
        onRunningChanged: if (running) interval = root.glideWait()
        onTriggered: {
            interval = root.glideWait();
            root.glideOn();
        }
    }

    // A long, even glide: the standard curve, not the decelerate one that would jump first
    ParallelAnimation {
        id: glide

        Anim {
            id: glideX

            target: clockView
            property: "driftX"
            duration: Theme.anim.slow * 4
            easing.bezierCurve: Theme.curve.standard
        }
        Anim {
            id: glideY

            target: clockView
            property: "driftY"
            duration: Theme.anim.slow * 4
            easing.bezierCurve: Theme.curve.standard
        }
    }

    // ── Caps lock, for the hint ──────────────────────────────

    property bool capsLock: false

    Process {
        id: devices

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(this.text).keyboards ?? [];
                    const kb = keyboards.find(k => k.main) ?? keyboards[0];
                    root.capsLock = !!kb?.capsLock;
                } catch (e) {
                    root.capsLock = false;
                }
            }
        }
    }

    // Only the screen with the field asks
    Timer {
        interval: 500
        running: root.showLogin && !root.context.unlocking
        repeat: true
        triggeredOnStart: true
        onTriggered: devices.running = true
    }
}
