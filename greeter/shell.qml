import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.components
import qs.config
import qs.lockscreen

// The login screen in the bloom lockscreen's look: the clock rising in in the accent, the
// date, the password pill, a hint. greetd runs it (frame-greeter-session) and starts the
// session once the password is right; then the pill turns green and the clock flies up, like
// unlocking. greeter.json next to this file says who and what:
//   { "user": "name", "command": ["/usr/bin/start-hyprland"], "corners": "round", "animations": "full" }
// `facet login` installs it with the files listed in `files` (the lockscreen's LockClock and
// PasswordPill and the components they use, the rendered Theme.qml).
ShellRoot {
    id: root

    property string user: ""
    property var command: []
    property string hostname: ""

    // What the hint says
    property string status: ""
    property bool failed: false
    property bool busy: false
    property bool starting: false
    // greetd asked for the password and waits
    property bool asked: false
    property string pending: ""
    property string typed: ""

    FileView {
        // Next to this file, wherever it is installed
        path: Qt.resolvedUrl("greeter.json").toString().replace("file://", "")
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.user = data.user ?? "";
                root.command = data.command ?? [];
            } catch (e) {
                root.status = "greeter.json is not readable";
            }
            root.begin();
        }
        onLoadFailed: root.status = "no greeter.json · run: facet login"
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostname = text().trim()
    }

    function begin() {
        if (!Greetd.available) {
            status = "greetd is not running here";
            return;
        }
        if (user === "") {
            status = "greeter.json names no user";
            return;
        }
        asked = false;
        Greetd.createSession(user);
    }

    // Enter: send the password now, or as soon as greetd asks for it
    function submit(password) {
        if (busy || starting)
            return;
        if (password === "") {
            window.shake();
            return;
        }
        failed = false;
        busy = true;
        if (asked) {
            asked = false;
            Greetd.respond(password);
        } else {
            pending = password;
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (root.pending !== "") {
                    const p = root.pending;
                    root.pending = "";
                    Greetd.respond(p);
                } else {
                    // A further question after the password (expired password, second
                    // factor): the field takes an answer again, and the hint says what PAM wants
                    if (root.busy && message !== "") {
                        root.status = message.toLowerCase();
                        root.typed = "";
                    }
                    root.asked = true;
                    root.busy = false;
                }
            } else if (message !== "") {
                root.status = message.toLowerCase();
            }
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.pending = "";
            root.typed = "";
            root.failed = true;
            root.status = "wrong password, try again";
            window.shake();
            // A failed attempt ends the greetd session; a new one asks again
            Qt.callLater(root.begin);
        }

        function onReadyToLaunch() {
            root.busy = false;
            root.starting = true;
            root.status = "";
            // The green moment and the clock flying up, then the session
            launchDelay.restart();
        }

        function onError(error) {
            root.busy = false;
            root.pending = "";
            root.status = String(error).toLowerCase();
            // The session is gone after an error; start a new one so Enter works again
            retry.restart();
        }
    }

    Timer {
        id: launchDelay
        interval: Theme.anim.slow
        onTriggered: Greetd.launch(root.command.length > 0 ? root.command : ["/usr/bin/start-hyprland"], [], true)
    }

    // Not straight away: when greetd itself is the problem, this would spin
    Timer {
        id: retry
        interval: 2000
        onTriggered: root.begin()
    }

    // Restart and shut down: the first click arms, the second one does it
    property string armed: ""

    function power(action) {
        if (armed !== action) {
            armed = action;
            disarm.restart();
            return;
        }
        Quickshell.execDetached(["systemctl", action]);
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = ""
    }

    // One plain window: the greeter compositors (noctalia's, cage) show it full screen and
    // know no layer shell. Inside a desktop it is just a window.
    FloatingWindow {
        id: window

        // 0 → 1: the glow behind everything
        property real backdrop: 0
        readonly property int step: Math.round(Theme.anim.fast / 3)

        function shake() {
            pill.shake();
        }

        title: "frameshell login"
        color: Theme.page
        minimumSize: Qt.size(960, 540)
        implicitWidth: 1920
        implicitHeight: 1080

        Component.onCompleted: {
            clockView.enter(window.step);
            enter.start();
        }

        Connections {
            target: root
            function onStartingChanged() {
                if (root.starting) {
                    enter.stop();
                    leave.start();
                }
            }
        }

        Item {
            anchors.fill: parent

            // ── Backdrop: the page with two soft blooms of the theme's colors ──

            Shape {
                anchors.fill: parent
                opacity: window.backdrop

                component Glow: ShapePath {
                    id: glow

                    property real cx: 0
                    property real cy: 0
                    property real radius: 0
                    property color tint: Theme.primaryContainer
                    // The area to fill; inline components cannot see the window's id
                    property real w: 0
                    property real h: 0

                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: glow.cx
                        centerY: glow.cy
                        centerRadius: glow.radius
                        focalX: glow.cx
                        focalY: glow.cy

                        GradientStop {
                            position: 0
                            color: glow.tint
                        }
                        GradientStop {
                            position: 1
                            color: Theme.alpha(glow.tint, 0)
                        }
                    }

                    startX: 0
                    startY: 0
                    PathLine { x: glow.w; y: 0 }
                    PathLine { x: glow.w; y: glow.h }
                    PathLine { x: 0; y: glow.h }
                    PathLine { x: 0; y: 0 }
                }

                Glow {
                    w: window.width
                    h: window.height
                    cx: window.width * 0.22
                    cy: window.height * 0.18
                    radius: window.width * 0.55
                    tint: Theme.alpha(Theme.primaryContainer, 0.55)
                }
                Glow {
                    w: window.width
                    h: window.height
                    cx: window.width * 0.85
                    cy: window.height * 0.95
                    radius: window.width * 0.45
                    tint: Theme.alpha(Theme.tertiary, 0.16)
                }
            }

            // ── Center: clock, date, password, hint ──────────────

            // Never seen: the pill draws the dots
            TextInput {
                id: input

                width: 1
                height: 1
                opacity: 0
                focus: true
                readOnly: root.busy || root.starting
                echoMode: TextInput.Password

                onTextChanged: {
                    root.typed = text;
                    // Typing again after a wrong password clears the red
                    if (text !== "" && root.failed) {
                        root.failed = false;
                        root.status = "";
                    }
                }
                onAccepted: root.submit(text)
                Keys.onEscapePressed: root.typed = ""
                Component.onCompleted: forceActiveFocus()

                // root.typed is also cleared from outside (a wrong password, Esc)
                Connections {
                    target: root
                    function onTypedChanged() {
                        if (input.text !== root.typed)
                            input.text = root.typed;
                    }
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Item {
                id: center

                readonly property real dateTop: clockView.height + 24
                readonly property real pillGap: 104
                readonly property real hintGap: 14

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -parent.height * 0.07
                width: Math.max(clockView.implicitWidth, pill.implicitWidth)
                height: dateTop + dateText.height + pillGap + pill.height + hintGap + hint.height

                LockClock {
                    id: clockView

                    anchors.horizontalCenter: parent.horizontalCenter
                    time: clock.date
                }

                StyledText {
                    id: dateText

                    property real rise: 0

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: center.dateTop + 16 * (1 - rise)
                    opacity: rise
                    text: clock.date.toLocaleDateString(Qt.locale("en_GB"), "dddd d MMMM")
                    font.pixelSize: Theme.size.large + 2
                }

                PasswordPill {
                    id: pill

                    property real rise: 0

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: center.dateTop + dateText.height + center.pillGap + 16 * (1 - rise)
                    opacity: rise
                    count: root.typed.length
                    placeholder: root.user !== "" ? `password for ${root.user}` : "password"
                    mode: root.starting ? "good" : root.busy ? "busy" : root.failed ? "bad" : "idle"
                    onSubmitted: root.submit(root.typed)
                }

                StyledText {
                    id: hint

                    property real rise: 0

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: center.dateTop + dateText.height + center.pillGap + pill.height + center.hintGap + 16 * (1 - rise)
                    opacity: rise
                    color: root.failed ? Theme.error : Theme.dim
                    font.pixelSize: Theme.size.small
                    text: root.starting ? "welcome"
                        : root.busy ? "checking …"
                        : root.status !== "" ? root.status
                        : "enter to log in · esc to clear"
                }
            }

            // ── Corners: who and where, power ────────────────────

            Row {
                id: who

                property real rise: 0

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 44
                anchors.topMargin: 36 + 30 * (1 - rise)
                opacity: rise
                spacing: Theme.spacing.normal

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "person"
                    size: Theme.icon.large
                    color: Theme.tertiary
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hostname !== "" ? `${root.user || "login"} · ${root.hostname}` : root.user || "login"
                    font.pixelSize: Theme.size.medium - 1
                }
            }

            Rectangle {
                id: powerPill

                property real rise: 0

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 40
                anchors.bottomMargin: 40 - 30 * (1 - rise)
                opacity: rise
                implicitWidth: powerRow.implicitWidth + Theme.padding.small * 2
                implicitHeight: powerRow.implicitHeight + Theme.padding.small * 2
                radius: height / 2
                color: Theme.container

                Row {
                    id: powerRow

                    anchors.centerIn: parent
                    spacing: Theme.spacing.small

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.armed !== ""
                        leftPadding: Theme.padding.small
                        rightPadding: Theme.spacing.small
                        text: root.armed === "reboot" ? "again to restart" : "again to shut down"
                        color: Theme.error
                        font.pixelSize: Theme.size.small
                    }
                    IconButton {
                        icon: "restart_alt"
                        size: Theme.control.button
                        active: root.armed === "reboot"
                        onClicked: root.power("reboot")
                    }
                    IconButton {
                        icon: "power_settings_new"
                        size: Theme.control.button
                        active: root.armed === "poweroff"
                        iconColor: root.armed === "poweroff" ? Theme.error : hovered ? Theme.text : Theme.dim
                        onClicked: root.power("poweroff")
                    }
                }
            }
        }

        // ── Coming in, going out ─────────────────────────────

        component RiseIn: SequentialAnimation {
            id: riseIn

            property Item item
            property int delay: 0

            PauseAnimation {
                duration: riseIn.delay
            }
            Anim {
                target: riseIn.item
                property: "rise"
                to: 1
                duration: Theme.anim.drawerIn
            }
        }

        component SinkOut: Anim {
            property: "rise"
            to: 0
            duration: Theme.anim.small
            easing.bezierCurve: Theme.curve.emphasizedAccel
        }

        ParallelAnimation {
            id: enter

            Anim {
                target: window
                property: "backdrop"
                to: 1
                duration: Theme.anim.slow
            }
            RiseIn {
                item: dateText
                delay: window.step * 4
            }
            RiseIn {
                item: pill
                delay: window.step * 5
            }
            RiseIn {
                item: hint
                delay: window.step * 6
            }
            RiseIn {
                item: who
                delay: window.step * 4
            }
            RiseIn {
                item: powerPill
                delay: window.step * 7
            }
        }

        SequentialAnimation {
            id: leave

            PauseAnimation {
                duration: window.step * 2
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
                    target: who
                }
                SinkOut {
                    target: powerPill
                }
            }
        }
    }
}
