import QtQuick
import qs.config

// The springy one for small things: switches, buttons pressed, chips, badges popping in. A
// little overshoot with animations "full", none with "calm" (Theme.curve.spring).
//
//   Behavior on scale { SpringAnim {} }
NumberAnimation {
    duration: Theme.anim.spring
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve.spring
}
