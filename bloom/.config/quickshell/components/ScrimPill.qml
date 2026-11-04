import QtQuick
import qs.config

// The in-game look of a popup: a see-through dark pill (Theme.scrim), one line, white text
// (Theme.onScrim), no frame and no shadow. Same API as Pill; use it when Bloom.compact(key)
// is true for your popup.
//
//   ScrimPill { AppIcon { size: 30; round: true; … } StyledText { color: Theme.onScrim; … } }
Pill {
    baseColor: Theme.scrim
    activeColor: Theme.scrim
    padding: 12
    implicitHeight: 40
}
