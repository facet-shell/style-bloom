import QtQuick
import qs.components
import qs.config

// One of a few values as segmented buttons. options: [[value, label], …] or Tabs entries
// ({ key, label, icon }).
ConfigRow {
    id: row

    property var options: []

    SegmentedButtons {
        model: row.options.map(o => Array.isArray(o) ? { key: o[0], label: o[1] } : o)
        current: Config[row.key]
        onSelected: key => Config.set(row.key, key)
    }
}
