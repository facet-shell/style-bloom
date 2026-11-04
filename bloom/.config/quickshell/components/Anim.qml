import QtQuick
import qs.config

// The emphasized-decelerate number animation (fast start, soft end) for anything that arrives
// or moves: drawers, fades, widths. Use it in Behaviors and transitions; set `duration` for
// another length, `easing.bezierCurve: Theme.curve.emphasizedAccel` for what leaves.
//
//   Behavior on opacity { Anim {} }
NumberAnimation {
    duration: Theme.anim.medium
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve.emphasizedDecel
}
