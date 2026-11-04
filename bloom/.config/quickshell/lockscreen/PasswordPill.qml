import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.components
import qs.config

// The password as a round pill: the flower in a circle on the left, one dot per typed
// character that pops in with a spring, and the go button that turns into a soft square once
// something is typed. It only shows; the TextInput lives in the surface (every screen types
// into the same password).
//
//   count        characters typed
//   mode         "idle", "busy" (PAM checks), "bad" (red, and shake() it), "good" (green)
//   placeholder  shown while nothing is typed
//   signal submitted()  the go button
Rectangle {
    id: root

    property int count: 0
    property string mode: "idle"
    property string placeholder: "password"
    readonly property bool typed: count > 0

    signal submitted()

    function shake() {
        shakeAnimation.restart();
    }

    implicitWidth: 400
    implicitHeight: 62
    radius: height / 2
    color: Theme.container

    Behavior on color {
        ColorAnim {}
    }

    transform: Translate {
        id: shakeOffset
    }

    // The mockup's soft shadow under the pill
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowBlur: 1
        blurMax: 48
        shadowVerticalOffset: 18
        shadowOpacity: 0.7
    }

    // One ListModel entry per dot: an int model would rebuild every dot on each keystroke,
    // and all of them would pop again
    ListModel {
        id: dots
    }

    onCountChanged: {
        while (dots.count < count)
            dots.append({});
        while (dots.count > count)
            dots.remove(dots.count - 1);
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 7
        spacing: Theme.spacing.medium

        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: height / 2
            color: root.mode === "good" ? Theme.ok : root.mode === "bad" ? Theme.errorContainer : Theme.primary

            Behavior on color {
                ColorAnim {}
            }

            Icon {
                anchors.centerIn: parent
                icon: "local_florist"
                color: root.mode === "good" ? Theme.onOk : root.mode === "bad" ? Theme.onErrorContainer : Theme.onPrimary
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledText {
                anchors.fill: parent
                visible: !root.typed
                text: root.placeholder
                dim: true
            }

            // Grows to the right; once it is wider than the pill, the newest dots stay in view
            Row {
                id: dotRow

                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(0, parent.width - width)
                spacing: 7

                Repeater {
                    model: dots

                    Rectangle {
                        id: dot

                        width: 10
                        height: 10
                        radius: 5
                        color: root.mode === "good" ? Theme.ok : Theme.text
                        scale: 0

                        Behavior on color {
                            ColorAnim {}
                        }

                        Component.onCompleted: popIn.start()

                        SpringAnim {
                            id: popIn

                            target: dot
                            property: "scale"
                            from: 0
                            to: 1
                        }
                    }
                }
            }
        }

        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: root.typed || root.mode === "good" ? Theme.rounding.normal : height / 2
            color: root.mode === "good" ? Theme.ok : root.typed ? Theme.primary : Theme.high

            Behavior on radius {
                SpringAnim {}
            }
            Behavior on color {
                ColorAnim {}
            }

            Icon {
                anchors.centerIn: parent
                visible: root.mode !== "busy"
                icon: root.mode === "good" ? "check" : "arrow_forward"
                color: root.mode === "good" ? Theme.onOk : root.typed ? Theme.onPrimary : Theme.dim
            }

            // Its own icon, so the arrow never comes back turned
            Icon {
                anchors.centerIn: parent
                visible: root.mode === "busy"
                icon: "progress_activity"
                color: Theme.onPrimary

                RotationAnimation on rotation {
                    running: root.mode === "busy" && Theme.animated
                    from: 0
                    to: 360
                    loops: Animation.Infinite
                    duration: Theme.anim.slow
                }
            }

            StateLayer {
                color: root.typed ? Theme.onPrimary : Theme.text
                onClicked: root.submitted()
            }
        }
    }

    // Left, right, smaller each time: a head shaking no
    SequentialAnimation {
        id: shakeAnimation

        readonly property int step: Math.round(Theme.anim.fast * 0.4)

        Anim {
            target: shakeOffset
            property: "x"
            to: -12
            duration: shakeAnimation.step
        }
        Anim {
            target: shakeOffset
            property: "x"
            to: 10
            duration: shakeAnimation.step
        }
        Anim {
            target: shakeOffset
            property: "x"
            to: -7
            duration: shakeAnimation.step
        }
        Anim {
            target: shakeOffset
            property: "x"
            to: 4
            duration: shakeAnimation.step
        }
        Anim {
            target: shakeOffset
            property: "x"
            to: 0
            duration: shakeAnimation.step
        }
    }
}
