import QtQuick
import QtQuick.Shapes
import qs.config

// A round gauge, open at the bottom (270°): the dashboard's CPU, GPU, RAM and temperature.
// The number and the label in the middle are the gauge's children (centered).
//
//   Gauge { value: SystemStats.cpu / 100; StyledText { text: "12 %" } }
//
//   value      0..1, glides to new values
//   size       110; thickness 10
//   color      Theme.primary; trackColor Theme.high
Item {
    id: root

    property real value: 0
    property real size: 110
    property real thickness: 10
    property color color: Theme.primary
    property color trackColor: Theme.high
    property real shown: Math.max(0, Math.min(1, value))
    default property alias content: middle.data

    implicitWidth: size
    implicitHeight: size

    Behavior on shown {
        Anim {
            duration: Theme.anim.slow
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: 270
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.shown > 0 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: 270 * root.shown
            }
        }
    }

    Item {
        id: middle

        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
