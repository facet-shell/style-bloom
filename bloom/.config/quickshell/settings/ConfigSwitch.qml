import QtQuick
import qs.components
import qs.config

// An on/off setting: the springy Switch; a click anywhere on the row flips it too.
ConfigRow {
    id: row

    readonly property bool on: Config[key] === true

    interactive: true
    onClicked: Config.set(row.key, !row.on)

    Switch {
        checked: row.on
        onToggled: on => Config.set(row.key, on)
    }
}
