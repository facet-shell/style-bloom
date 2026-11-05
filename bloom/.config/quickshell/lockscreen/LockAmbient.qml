pragma Singleton

import QtQuick
import Quickshell

// What the lock surfaces of all monitors share about the ambient mode (Config.lockAmbient):
// whether the lockscreen has gone ambient, and that a key or the mouse was touched somewhere.
// Only the surface that shows the login keeps the idle time; it sets `idle`, every surface
// follows it. Lock.qml does not know about this.
//
//   LockAmbient.idle       true while the lockscreen is ambient
//   LockAmbient.touched()  emitted by any surface on input; the login surface restarts its timer
Singleton {
    property bool idle: false

    signal touched()
}
