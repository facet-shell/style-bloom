import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// STUB (notifications part: the Spotify bloom): when Spotify starts another song, a disc
// drops out of the top border with a little bounce (SpringAnim), opens into a pill with
// title, artist, a thin progress line and prev / play / next, stays while the mouse is on it,
// then closes back into the disc and leaves (the mockup's .bloom). Not while the dashboard is
// out (Bloom.inset(screen, "top") > 0). In a game with Bloom.compact("spotify"): a 40 px
// ScrimPill with title and artist only. Size Bloom.scale("spotify"), how long it stays
// Config.spotifySeconds, the rule "sp.song" (Notifications.allows) like tui's
// media/SpotifyPopup.qml.
Scope {
    id: root

    property bool hidden: false
}
