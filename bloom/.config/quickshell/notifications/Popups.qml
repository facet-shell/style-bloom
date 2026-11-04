import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// STUB (notifications part): the notification popups. In bloom they float inside the hole
// (HolePopup) where Config.notificationPosition says, as cards (Theme.container, radius 24,
// the app icon in a rounded square, actions as pill buttons, a thin time-left line), at
// Bloom.scale("notification"); calls breathe green until answered. On the right they step
// aside while a drawer is out there (Bloom.inset(screen, "right")). In a game with
// Bloom.compact("notification"): ScrimPills, one line, only what must stay (calls, invites)
// keeps its buttons. The mockup's .notes / .note.
// Notifications.popups is the list to show; Notifications.dismiss(uid), invoke(uid, action).
Scope {
    id: root

    property bool hidden: false
}
