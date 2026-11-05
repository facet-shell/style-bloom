import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Lock screen (tui's "shell" section): the lockscreen's blur, locking and screens off when
// idle, the ambient mode, the weather's city and how often it updates. One block per page
// of the category (view.page).
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page

    spacing: Theme.spacing.medium

    // ── Lock and screens ──

    ConfigRow {
        id: blur

        // Shown while dragging; written once on release, not on every move
        property real live: Config.lockBlur

        visible: page.sub === "lock"
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
        visible: page.sub === "lock"
        key: "idleLockMinutes"
        title: "Lock when idle"
        subtitle: "minutes without input before the lockscreen comes up"
        max: 120
        unit: " min"
        zero: "never"
    }
    ConfigNumber {
        visible: page.sub === "lock"
        key: "idleScreenOffMinutes"
        title: "Screens off when idle"
        subtitle: "minutes without input before the screens go dark"
        max: 240
        unit: " min"
        zero: "never"
    }

    // ── Ambient ──

    ConfigSwitch {
        visible: page.sub === "ambient"
        key: "lockAmbient"
        title: "Ambient after a while"
        subtitle: "the clock shrinks and drifts slowly, the blur goes up, the rest fades; weather and music stay. A key or the mouse brings it back"
    }
    ConfigNumber {
        visible: page.sub === "ambient"
        key: "lockAmbientMinutes"
        title: "After"
        subtitle: "minutes on the lockscreen without input"
        min: 1
        max: 30
        unit: " min"
    }

    // ── Weather ──

    ConfigText {
        visible: page.sub === "weather"
        key: "weatherLocation"
        title: "City"
        subtitle: "empty: guessed from your connection"
        placeholder: "e.g. Berlin"
    }
    ConfigNumber {
        visible: page.sub === "weather"
        key: "weatherInterval"
        title: "Update every"
        min: 5
        max: 120
        step: 5
        unit: " min"
    }
}
