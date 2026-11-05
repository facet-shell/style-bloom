import QtQuick
import qs.components
import qs.config

// The lockscreen's big clock in the accent: four digits that rise in one after the other with
// a spring, a softly blinking colon, and a digit that changes rising in again by itself.
//
//   time   the date to show (SystemClock.date)
//   fly    0 … 1: the clock flies up, shrinks and fades (unlocking)
//   ambient  0 … 1: the clock shrinks to 0.6 (the lockscreen's ambient mode)
//   dimmed   the digits in Theme.dim instead of the accent (ambient as well)
//   driftX, driftY  where the clock sits, off its resting place (the ambient drift)
//   enter(delay)  plays the rise-in, the first digit after `delay` ms
Item {
    id: root

    property date time: new Date()
    property real fly: 0
    property real ambient: 0
    property bool dimmed: false
    property real driftX: 0
    property real driftY: 0
    // Off until enter() ran, so the first values do not count as changes
    property bool ready: false

    readonly property string hh: Qt.formatDateTime(time, "HH")
    readonly property string mm: Qt.formatDateTime(time, "mm")
    // Between two digits' starts
    readonly property int stagger: Math.round(Theme.anim.fast * 0.3)

    function enter(delay) {
        const digits = [d0, d1, d2, d3];
        for (let i = 0; i < digits.length; i++)
            digits[i].play(delay + i * stagger + (i > 1 ? stagger : 0));
        colon.rise = 0;
        colonIn.restart();
        ready = true;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: 1 - fly
    // Scaled about the middle, so the drift and the fly move the clock as one
    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: (1 - 0.1 * root.fly) * (1 - 0.4 * root.ambient)
            yScale: (1 - 0.1 * root.fly) * (1 - 0.4 * root.ambient)
        },
        Translate {
            x: root.driftX
            y: root.driftY - 120 * root.fly
        }
    ]

    component Digit: Item {
        id: digit

        property string value: "0"
        // 0 below and gone, 1 in place; the spring takes it a little past 1
        property real rise: 0
        // Inline components cannot see the file's ids, so the clock hands these in
        property bool live: false
        property bool dimmed: false

        function play(delay) {
            rise = 0;
            pause.duration = Math.max(0, delay);
            riseIn.restart();
        }

        // A new minute: only the digit that changed rises in again
        onValueChanged: if (live) play(0)

        implicitWidth: glyph.implicitWidth
        implicitHeight: glyph.implicitHeight

        Text {
            id: glyph

            y: 60 * (1 - digit.rise)
            opacity: Math.max(0, Math.min(1, digit.rise))
            text: digit.value
            color: digit.dimmed ? Theme.dim : Theme.primary
            font.family: Theme.font
            font.pixelSize: Theme.size.clock
            font.weight: Font.Light
            // Same width for every figure, so the clock never jiggles
            font.features: ({ "tnum": 1 })

            Behavior on color {
                ColorAnim {
                    duration: Theme.anim.color
                }
            }
        }

        SequentialAnimation {
            id: riseIn

            PauseAnimation {
                id: pause
            }
            SpringAnim {
                target: digit
                property: "rise"
                to: 1
                duration: Theme.anim.drawerIn + Theme.anim.fast
            }
        }
    }

    Row {
        id: row

        // The mockup's -4 px letter spacing, between the separate digits
        spacing: -4

        Digit {
            id: d0
            value: root.hh.charAt(0)
            live: root.ready
            dimmed: root.dimmed
        }
        Digit {
            id: d1
            value: root.hh.charAt(1)
            live: root.ready
            dimmed: root.dimmed
        }

        Item {
            id: colon

            property real rise: 0
            property real blink: 0.6

            implicitWidth: colonText.implicitWidth + 8
            implicitHeight: colonText.implicitHeight

            Text {
                id: colonText

                anchors.horizontalCenter: parent.horizontalCenter
                // Sits a little high in Rubik; pulled down to the digits' middle
                y: 60 * (1 - colon.rise) - Theme.size.clock * 0.04
                opacity: colon.blink * Math.max(0, Math.min(1, colon.rise))
                text: ":"
                color: root.dimmed ? Theme.dim : Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.size.clock
                font.weight: Font.Light

                Behavior on color {
                    ColorAnim {
                        duration: Theme.anim.color
                    }
                }
            }

            SequentialAnimation {
                id: colonIn

                PauseAnimation {
                    duration: root.stagger * 2
                }
                SpringAnim {
                    target: colon
                    property: "rise"
                    to: 1
                    duration: Theme.anim.drawerIn + Theme.anim.fast
                }
            }

            // Breathes between 0.6 and 0.2; never runs with motion off (zero-length loops spin)
            SequentialAnimation {
                running: Theme.animated && root.visible && root.ready
                loops: Animation.Infinite

                Anim {
                    target: colon
                    property: "blink"
                    to: 0.2
                    duration: Theme.anim.slow + Theme.anim.fast / 2
                    easing.bezierCurve: Theme.curve.standard
                }
                Anim {
                    target: colon
                    property: "blink"
                    to: 0.6
                    duration: Theme.anim.slow + Theme.anim.fast / 2
                    easing.bezierCurve: Theme.curve.standard
                }
            }
        }

        Digit {
            id: d2
            value: root.mm.charAt(0)
            live: root.ready
            dimmed: root.dimmed
        }
        Digit {
            id: d3
            value: root.mm.charAt(1)
            live: root.ready
            dimmed: root.dimmed
        }
    }
}
