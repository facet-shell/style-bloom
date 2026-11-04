import QtQuick
import qs.config

// Colors of controls (hover, selected) fade with this; `duration: Theme.anim.color` for a
// palette change (a new theme or wallpaper).
//
//   Behavior on color { ColorAnim {} }
ColorAnimation {
    duration: Theme.anim.small
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve.standard
}
