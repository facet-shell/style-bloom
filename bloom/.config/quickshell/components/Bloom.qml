pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

// State every bloom part shares: the focused screen, game mode and what it means for each
// popup, the frame on each screen, and which drawers are out (so others can step aside).
//
//   Bloom.focusedScreen           ShellScreen with the keyboard focus (Hyprland's monitor)
//   Bloom.gaming                  game mode is on (Toggles.gameMode)
//   Bloom.compact(key)            this popup shows as a see-through pill now (in a game and
//                                 its "compact in a game" switch is on); key: notification,
//                                 spotify, osd, voice or panels
//   Bloom.scale(key)              its size factor from the settings (same keys)
//   Bloom.frameAway               the frame and the bar have stepped away (game mode)
//   Bloom.frameWindow(name)       the frame window of screen `name` (the bar lives in it),
//                                 for focus grabs and popups that come out of the bar
//   Bloom.inset(name, edge, id)   how far drawers on that edge of that screen reach into the
//                                 hole right now (target size, not the animated one), the
//                                 drawer `id` left out; 0 when none is out
//   Bloom.preview(what)           shows a test of a popup now, past the rules and the bell:
//                                 notification, call or spotify (the settings' "show a test",
//                                 `qs ipc call preview popup <what>`)
Singleton {
    id: root

    readonly property bool gaming: Toggles.gameMode

    // SpotifyPopup listens; the notification ones go straight to Notifications
    signal previewRequested(string what)

    function preview(what) {
        if (what === "notification")
            Notifications.push({
                app: "facet",
                title: "A test notification",
                body: "This is how a notification looks with your settings. The buttons do nothing.",
                icon: "notifications",
                preview: true,
                actions: [
                    { id: "ok", label: "nice", style: "ok" },
                    { id: "no", label: "dismiss", style: "" }
                ]
            });
        else if (what === "call")
            Notifications.push({
                app: "Discord",
                kind: "call",
                title: "Test call",
                body: "is calling you (a test, no one is)",
                icon: "call",
                preview: true,
                timeout: 8000,
                actions: [
                    { id: "accept", label: "accept", style: "ok" },
                    { id: "decline", label: "decline", style: "no" }
                ]
            });
        else
            previewRequested(what);
    }
    readonly property ShellScreen focusedScreen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function screenNamed(name) {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    // ── Popups in a game ─────────────────────────────────────

    readonly property var compactKeys: ({
        notification: "notificationCompactInGame",
        spotify: "spotifyCompactInGame",
        osd: "osdCompactInGame",
        voice: "voiceOverlayCompactInGame",
        panels: "panelsCompactInGame"
    })
    readonly property var sizeKeys: ({
        notification: "notificationSize",
        spotify: "spotifySize",
        osd: "osdSize",
        voice: "voiceOverlaySize",
        panels: "panelSize"
    })

    function compact(key) {
        return gaming && Config[compactKeys[key]] === true;
    }

    // Clamped, so a typo in shell.json cannot blow a popup up
    function scale(key) {
        const value = Number(Config[sizeKeys[key]]);
        return isNaN(value) ? 1 : Math.max(0.6, Math.min(1.6, value));
    }

    // ── The frame ────────────────────────────────────────────

    readonly property bool frameAway: gaming && Config.frameHidesInGame
    property var frames: ({})

    function registerFrame(name, window) {
        const next = Object.assign({}, frames);
        if (window)
            next[name] = window;
        else
            delete next[name];
        frames = next;
    }

    function frameWindow(name) {
        return frames[name] ?? null;
    }

    // ── Drawers that are out ─────────────────────────────────

    // id → { screen, edge, extent }
    property var drawers: ({})

    function report(id, screen, edge, extent) {
        const old = drawers[id];
        if (extent > 0 && old && old.screen === screen && old.edge === edge && old.extent === extent)
            return;
        if (extent <= 0 && !old)
            return;
        const next = Object.assign({}, drawers);
        if (extent > 0)
            next[id] = { screen: screen, edge: edge, extent: extent };
        else
            delete next[id];
        drawers = next;
    }

    function inset(screen, edge, except) {
        let most = 0;
        for (const id in drawers) {
            const d = drawers[id];
            if (id !== except && d.screen === screen && d.edge === edge)
                most = Math.max(most, d.extent);
        }
        return most;
    }

    function anyOpen(screen) {
        for (const id in drawers)
            if (drawers[id].screen === screen)
                return true;
        return false;
    }
}
