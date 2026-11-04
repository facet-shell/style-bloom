import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// STUB (lockscreen part): the smallest bloom lockscreen that works, until the lockscreen
// part replaces this file. The blurred snapshot, the clock in Theme.primary, the date, and
// the password pill (round avatar, dots, a go button that turns into a soft square once
// something is typed; it shakes on a wrong password). Lock.qml and LockContext.qml (the
// session lock, PAM, idle and sleep) are tui's and stay as they are.
//
// Same API as tui's LockSurface: context, snapshot, showLogin. Everything animates from
// `progress` (0 → 1 on lock, back on unlock).
Item {
    id: root

    required property LockContext context
    required property string snapshot
    // false on the other monitors: only the blurred snapshot
    property bool showLogin: true

    property bool appeared: false
    property real progress: context.unlocking || !appeared ? 0 : 1
    Behavior on progress {
        Anim {
            duration: Theme.anim.slow
        }
    }

    // The field has to hold the focus before the first keystroke; on the real lock the
    // surface learns its screen only after it exists, so the focus follows showLogin and is
    // set once more a moment after the surface appeared (tui's LockSurface explains it)
    function focusInput() {
        if (showLogin)
            input.forceActiveFocus();
        else
            hiddenInput.forceActiveFocus();
    }

    onShowLoginChanged: focusInput()

    Timer {
        running: root.appeared
        interval: 150
        onTriggered: root.focusInput()
    }

    Component.onCompleted: {
        appeared = true;
        focusInput();
    }

    // Other monitors have no visible field, but typing there still fills the password
    TextInput {
        id: hiddenInput

        enabled: !root.showLogin && !root.context.unlockInProgress
        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.Password

        onTextChanged: root.context.currentText = text
        onAccepted: root.context.tryUnlock()
        Keys.onEscapePressed: root.context.currentText = ""

        Connections {
            target: root.context
            function onCurrentTextChanged() {
                if (hiddenInput.text !== root.context.currentText)
                    hiddenInput.text = root.context.currentText;
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Image {
        id: shot

        anchors.fill: parent
        source: root.snapshot !== "" ? `file://${root.snapshot}` : ""
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.page
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: Config.lockBlur * root.progress
        brightness: -0.45 * root.progress
        saturation: 0.2 * root.progress
    }

    ColumnLayout {
        visible: root.showLogin
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.17 + 30 * (1 - root.progress)
        opacity: root.progress
        spacing: 18

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.primary
            tabular: true
            font.pixelSize: Theme.size.clock
            font.weight: Font.Light
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            font.pixelSize: Theme.size.large
        }

        Item {
            Layout.preferredHeight: 70
        }

        // The password pill
        Rectangle {
            id: pill

            readonly property bool typed: root.context.currentText !== ""

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 400
            implicitHeight: 62
            radius: height / 2
            color: Theme.container

            transform: Translate {
                id: shake
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 7
                spacing: 12

                Rectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 24
                    color: root.context.showFailure ? Theme.errorContainer : Theme.primary

                    Behavior on color {
                        ColorAnim {}
                    }

                    Icon {
                        anchors.centerIn: parent
                        icon: "local_florist"
                        color: root.context.showFailure ? Theme.onErrorContainer : Theme.onPrimary
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: input

                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        enabled: !root.context.unlockInProgress
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 16
                        font.letterSpacing: 6
                        clip: true
                        cursorDelegate: Item {}

                        onTextChanged: root.context.currentText = text
                        onAccepted: root.context.tryUnlock()
                        Keys.onEscapePressed: root.context.currentText = ""

                        // Keeps every monitor's field in sync
                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                if (input.text !== root.context.currentText)
                                    input.text = root.context.currentText;
                            }
                        }
                    }

                    StyledText {
                        anchors.fill: parent
                        visible: !pill.typed
                        text: root.context.showFailure ? "wrong password, try again" : "password"
                        color: root.context.showFailure ? Theme.error : Theme.dim
                    }
                }

                Rectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: pill.typed ? Theme.rounding.medium : 24
                    color: pill.typed ? Theme.primary : Theme.high

                    Behavior on radius {
                        SpringAnim {}
                    }
                    Behavior on color {
                        ColorAnim {}
                    }

                    Icon {
                        anchors.centerIn: parent
                        icon: root.context.unlockInProgress ? "progress_activity" : "arrow_forward"
                        color: pill.typed ? Theme.onPrimary : Theme.dim
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.context.tryUnlock()
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation { target: shake; property: "x"; to: -12; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 10; duration: 80 }
        NumberAnimation { target: shake; property: "x"; to: -7; duration: 80 }
        NumberAnimation { target: shake; property: "x"; to: 4; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
    }

    Connections {
        target: root.context
        function onFailed() {
            shakeAnimation.restart();
        }
    }
}
