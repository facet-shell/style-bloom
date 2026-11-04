import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// A SettingRow for one Config key: the controls on the right, then a small reset button
// that pops in while the key differs from the shell's default, so every change can be
// undone in one click (tui's "default"). Rows without a key are plain rows with controls.
//
//   ConfigRow { key: "lockBlur"; title: "…"; subtitle: "…"; Slider { … } }
//
//   key          the Config key; "" for no reset button
//   resettable   whether the reset button has a place (key !== "" by default)
//   changed      whether it shows (Config.isSet(key) by default)
//   signal resetClicked()  after Config.reset(key); rows with their own storage (the
//                notification rules) reset there
SettingRow {
    id: row

    property string key: ""
    property bool resettable: key !== ""
    property bool changed: key !== "" && Config.isSet(key)
    default property alias controls: box.data

    signal resetClicked()

    Layout.fillWidth: true

    RowLayout {
        spacing: Theme.spacing.small

        RowLayout {
            id: box

            spacing: Theme.spacing.normal
        }

        IconButton {
            // Keeps its place while hidden, so the controls do not jump when it shows up
            visible: row.resettable
            icon: "restart_alt"
            size: Theme.control.chip
            iconSize: Theme.icon.small
            disabled: !row.changed
            opacity: row.changed ? 1 : 0
            scale: row.changed ? 1 : 0.6

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.small
                }
            }
            Behavior on scale {
                SpringAnim {}
            }

            onClicked: {
                if (row.key !== "")
                    Config.reset(row.key);
                row.resetClicked();
            }
        }
    }
}
