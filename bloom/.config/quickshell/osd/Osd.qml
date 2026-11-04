import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// STUB (notifications part: OSD): what changed outside the shell, only the fader that moved.
// On the desktop one line out of the bottom edge (a Drawer: icon in primaryContainer, name,
// a ProgressBar, the value; muted turns errorContainer), gone after ~1.8 s and never while
// the launcher is out there (Bloom.inset(screen, "bottom")). In a game with
// Bloom.compact("osd"): a small ScrimPill near the bottom, gone after a second. Size:
// Bloom.scale("osd"). Same sources as tui's osd/Osd.qml: GoXLR faders and mutes, the GoXLR
// mic button, the default output's volume, the keyboard layout. Display only.
Scope {
    id: root

    property bool hidden: false
}
