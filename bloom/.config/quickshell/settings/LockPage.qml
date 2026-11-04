import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Lock and weather (tui's "shell" section): the lockscreen's blur, locking and screens off
// when idle, the weather's city and how often it updates.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    PageHeading {
        text: "Lock and screens"
    }

    ConfigRow {
        id: blur

        // Shown while dragging; written once on release, not on every move
        property real live: Config.lockBlur

        key: "lockBlur"
        title: "Lockscreen blur"
        subtitle: "how blurred the desktop is behind the lockscreen"

        Slider {
            id: blurSlider

            implicitWidth: 200
            thin: true
            step: 0.1
            value: dragging ? blur.live : Config.lockBlur
            onMoved: v => {
                blur.live = Math.round(v * 20) / 20;
                // The wheel and the arrow keys have no release
                if (!dragging)
                    Config.set("lockBlur", blur.live);
            }
            onReleased: Config.set("lockBlur", blur.live)
        }
        StyledText {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            tabular: true
            text: `${Math.round((blurSlider.dragging ? blur.live : Config.lockBlur) * 100)} %`
            dim: true
            font.pixelSize: Theme.size.small
        }
    }
    ConfigNumber {
        key: "idleLockMinutes"
        title: "Lock when idle"
        subtitle: "minutes without input before the lockscreen comes up"
        max: 120
        unit: " min"
        zero: "never"
    }
    ConfigNumber {
        key: "idleScreenOffMinutes"
        title: "Screens off when idle"
        subtitle: "minutes without input before the screens go dark"
        max: 240
        unit: " min"
        zero: "never"
    }

    PageHeading {
        text: "Weather"
    }
    ConfigText {
        key: "weatherLocation"
        title: "City"
        subtitle: "empty: guessed from your connection"
        placeholder: "e.g. Berlin"
    }
    ConfigNumber {
        key: "weatherInterval"
        title: "Update every"
        min: 5
        max: 120
        step: 5
        unit: " min"
    }
}
