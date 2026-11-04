import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// A number with − and + (the wheel on it works too); factor turns the stored value into the
// shown one (ms → s), zero is the word shown for 0 ("never").
ConfigRow {
    id: num

    property real min: 0
    property real max: 100
    property real step: 1
    property real factor: 1
    property string unit: ""
    property string zero: ""
    readonly property real shown: Number(Config[key] ?? 0) / factor

    function change(d) {
        const v = Math.max(min, Math.min(max, Math.round((shown + d) / step) * step));
        Config.set(key, Number((v * factor).toFixed(3)));
    }

    Rectangle {
        implicitWidth: stepper.implicitWidth + Theme.spacing.small * 2
        implicitHeight: Theme.control.button
        radius: height / 2
        color: Theme.high

        RowLayout {
            id: stepper

            anchors.centerIn: parent
            spacing: 0

            IconButton {
                icon: "remove"
                size: Theme.control.chip
                iconSize: Theme.icon.small
                disabled: num.shown <= num.min
                onClicked: num.change(-num.step)
            }
            StyledText {
                Layout.preferredWidth: Math.max(implicitWidth, 72)
                horizontalAlignment: Text.AlignHCenter
                tabular: true
                text: num.shown === 0 && num.zero !== "" ? num.zero : `${Number(num.shown.toFixed(2))}${num.unit}`

                MouseArea {
                    anchors.fill: parent
                    onWheel: wheel => num.change(wheel.angleDelta.y > 0 ? num.step : -num.step)
                }
            }
            IconButton {
                icon: "add"
                size: Theme.control.chip
                iconSize: Theme.icon.small
                disabled: num.shown >= num.max
                onClicked: num.change(num.step)
            }
        }
    }
}
