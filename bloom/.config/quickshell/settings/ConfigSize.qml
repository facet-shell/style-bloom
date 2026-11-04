import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// A popup's size factor: small, normal, large (0.85, 1, 1.15) as segments, and − / + for
// anything in between (0.6 to 1.6, the range Bloom.scale clamps to; tui's steps). A value
// between the presets shows in the subtitle instead of a picked segment.
ConfigRow {
    id: sizeRow

    property string hint: ""
    readonly property real value: Number(Config[key] ?? 1)
    readonly property var presets: [
        { key: 0.85, label: "small" },
        { key: 1, label: "normal" },
        { key: 1.15, label: "large" }
    ]
    readonly property var picked: presets.find(p => Math.abs(p.key - value) < 0.001)

    function nudge(d) {
        const v = Math.max(0.6, Math.min(1.6, Math.round((value + d) * 20) / 20));
        if (Math.abs(v - 1) < 0.001)
            Config.reset(key);
        else
            Config.set(key, Number(v.toFixed(2)));
    }

    title: "Size"
    subtitle: picked ? hint : [hint, `now ${Number(value.toFixed(2))}×`].filter(s => s !== "").join(" · ")

    IconButton {
        icon: "remove"
        size: Theme.control.chip
        iconSize: Theme.icon.small
        disabled: sizeRow.value <= 0.6
        onClicked: sizeRow.nudge(-0.05)
    }
    SegmentedButtons {
        model: sizeRow.presets
        current: sizeRow.picked ? sizeRow.picked.key : ""
        onSelected: key => {
            // normal is the default, so shell.json stays clean
            if (key === 1)
                Config.reset(sizeRow.key);
            else
                Config.set(sizeRow.key, key);
        }
    }
    IconButton {
        icon: "add"
        size: Theme.control.chip
        iconSize: Theme.icon.small
        disabled: sizeRow.value >= 1.6
        onClicked: sizeRow.nudge(0.05)
    }
}
