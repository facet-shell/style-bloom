# bloom: the contract

Everything a part of the bloom style needs to know: who owns which folder, the building
blocks and their APIs, the Theme tokens, the settings bloom adds, the IPC each part must keep,
how a part behaves in a game, and the rules. Read this, the mockup
(`bloom-preview.html`) and the tui part you replace (`style-tui/tui/.config/quickshell/<folder>`).

## 1. How bloom is put together

- **core** (`facet-shell/shell`, repo `facet-shell/core`) holds what every style shares:
  `services/*` (singletons: Notifications, DiscordBridge, SteamBridge, Spotify, GoXLR, Audio, Channels,
  Toggles, Recorder, Clipboard, Timers, Weather, SystemStats, Tasks, Claude, Updates,
  Wallpapers, CanvasLayout, Binds, Editor, Keyboard, Network …), `services/Core.qml` (startup
  and the media keys), `config/Config.qml` (all settings, the user's changes in
  `~/.config/facet/shell.json`).
- **style-bloom** (this repo) is one Stow package, `bloom/.config/quickshell/`, linked with
  `stow --no-folding` into the same `~/.config/quickshell` as core. So imports are
  `qs.components`, `qs.config`, `qs.services`, `qs.bar` …, one module per folder.
- `config/Theme.qml` is generated: `templates/bloom/.config/quickshell/config/Theme.qml` is the
  source, `facet theme` fills in the theme's colors and writes it (git-ignored). Edit the
  template, never the generated file. Placeholders are `{{tones.primary}}`,
  `{{colors.warn}}`, `{{fonts.mono}}` (cli/facet, `render_template`).
- `facet style bloom` unlinks tui's package and links this one; `facet style tui` goes back.
  Login, boot splash and GRUB come from the style in use: bloom has its own (greeter/ with a
  file list in greeter/files, templates/grub and templates/plymouth with images.sh drawing the
  pictures); `screens_style` in cli/facet falls back to tui for a style without them.
- `shell.qml` starts with `Core {}`, then the bar and every part. It only wires parts together;
  a part never reaches into another part's files.

## 2. Who owns what

| Part | Folder(s) | Files now | Replaces (tui) |
|---|---|---|---|
| Foundation | `components/`, `bar/`, `shell.qml`, the Theme template | built | `components/`, `bar/` |
| Notifications | `notifications/` (Popups, History), `osd/`, `media/` (Spotify bloom), `voice/` | stubs | same folders |
| Launcher | `launcher/` | stub | `launcher/` |
| Dashboard + control center | `dashboard/` (new), `controlcenter/` | stubs | `controlcenter/` (task manager → dashboard) |
| Lockscreen | `lockscreen/` | working minimum: tui's Lock.qml + LockContext.qml, a small bloom LockSurface | `lockscreen/` |
| Settings | `settings/` | stub | `settings/` |
| Canvas | `canvas/` | stub overview; CanvasDesk and CanvasThumbs are tui's and work | `canvas/` |
| Screenshot | `screenshot/` | stub (stopping a recording works) | `screenshot/` |
| Draw | `draw/` | stub | `draw/` |
| Editor | `editor/` | stub (opens through the Editor service) | `editor/` |
| Gallery | `gallery/` | stub | `gallery/` |
| Hotkeys | `hotkeys/` | stub | `hotkeys/` |
| Keyboard | `keyboard/` | stub (`mods` works) | `keyboard/` |
| Wallpapers | `wallpapers/` | stub app; Backdrop.qml is tui's and works | `wallpapers/` |

A part may add files to its own folder only. Need a new shared component, a Theme token, a
Config key or a service? Add it in `components/`, the template, `config/Config.qml` or
`services/` (core) in the same style as the rest and list it here in this file. Keep the stub's
file name and public API (section 9), extend it freely.

## 3. Rules

From the owner, exactly:

- Commit with `git -c user.name=vxnsin -c user.email=vxnsin@icloud.com commit`. Never another
  name or email, never Co-Authored-By or any attribution line. Do not push.
- Code comments in English, short, saying **why**, in the style of the existing files (a plain
  sentence above the thing, no banners beyond the `// ── Section ──` lines already used).
  The chat with the owner is German; the code is not.
- LF line endings (`.gitattributes` has `* text=auto eol=lf`; check with `git ls-files --eol`).
- Build things yourself before adding a package. Few dependencies; a new one goes into `DEPS`
  in cli/facet with a comment why.
- Do not touch the website, the `facet` docs repo, `org-profile` or `site`.

For the code:

- **Theme tokens only**: no hex colors, font names, durations or radii in a part. The only
  exceptions are pictures' own colors (album art, app icons, avatars) and `#ffffff` on such
  pictures. Missing a token? Add it to the template.
- **Material names**: use `Theme.surface`, `container`, `high`, `primary`, `textOnPrimary` …; the
  tui names (`bg`, `surface2`, `textDim`, `accent`, `danger`, `frame`, `border`) exist only
  for core and copied tui code.
- **Motion**: everything that arrives or moves uses `Anim` (emphasized decelerate) or the
  Drawer's own slide; small things (switches, presses, chips, badges) `SpringAnim`; colors
  `ColorAnim`. Use the `Theme.anim.*` durations, they become 0 with animations off. Never a
  plain `NumberAnimation { duration: 300 }`.
- **Icons** are Material Symbols names in `Icon` (ligatures), not Nerd Font code points.
- **No workspace dots and no window list** anywhere: the canvas overview is where windows are.
- Layer namespaces keep the tui names where they exist (`qs-launcher` is checked by
  `hypr/facet/shell.lua`); new ones are `qs-<part>`.
- Settings are read from `Config.*` and written with `Config.set(key, value)` /
  `Config.reset(key)`; a new key gets a comment like its neighbours and a line in section 8.
- Long work goes in services (core), not in the UI. A part shows; a service knows.
- Check every QML file you touch:
  `node <scratchpad>/brackets.js <files>` (bracket balance); Quickshell cannot run here.

## 4. Geometry and layers

```
┌──────────────────────────────── bar 52 px (the frame's top edge) ───────────────────────────────┐
│ (logo) (tray)                      ( 14:32  Wed 4 Nov )         (search)(canvas)(bell)(status)(⏻) │
│  ╭─────────────────────────────────────────────────────────────────────────────────────────────╮  │
│  │                                  the hole (radius 26)                                        │  │
│ 10                                                                                              10 │
│  ╰─────────────────────────────────────────────────────────────────────────────────────────────╯  │
└───────────────────────────────────────────── 10 px ─────────────────────────────────────────────┘
```

- `ScreenFrame` (components) makes, per screen: four empty layer windows that only reserve the
  space (exclusive zones: top `Theme.frame.bar`, the rest `Theme.frame.border`), and one
  see-through window over the whole screen (`qs-frame`, layer Top) that draws the surface
  everywhere but the hole and holds the bar. Its input region is the bar only.
- A `Drawer` is its own layer window, placed **inside the hole** (it respects those exclusive
  zones) against one edge. Its content slides in from that edge clipped by the window, so it
  looks as if it came from under the frame whatever the stacking. Body and the two concave
  joints are one path in `Theme.surface`, the frame's color: frame and drawer are one piece.
- A `HolePopup` is a layer window inside the hole that does not join the frame (popups).
- Layers: Top for the frame, bar, drawers (fullscreen windows cover them, like the frame);
  Overlay for popups that must show over a game (notifications, OSD pill, Spotify bloom,
  voice) and for drawers that must open over fullscreen windows (set `windowLayer`).
- Keep drawers off the hole's corners: `offset` ≥ `Theme.rounding.hole` for align start/end.
- Positions used so far: dashboard top center, control center right (offset 70), history
  right (offset 70, its part may move it), launcher bottom center, OSD line bottom center
  (not while the launcher is out), tray and power menus top under their button, Spotify bloom
  top center in the hole (not while the dashboard is out), notifications top right in the
  hole.
- **Stepping aside**: every Drawer reports its target size to `Bloom.drawers`;
  `Bloom.inset(screen.name, edge)` tells how far drawers on that edge reach. Popups on that
  side add it to their margin (animate with `Behavior { Anim {} }`), e.g. notifications on the
  right while the control center is out. A popup that would collide with a drawer at the same
  spot (Spotify bloom and the dashboard, the OSD line and the launcher) stays away while
  `Bloom.inset(...) > 0`.
- **Focus**: an open Drawer with `closeOnOutside` holds a Hyprland focus grab (the bar's window
  counts as inside, so the bar's buttons still toggle it). Opening another drawer with a grab
  ends the first one's grab, so its `dismissed()` fires: one grabbing drawer at a time.
  Keyboard: `keyboard: WlrKeyboardFocus.OnDemand` for Esc and arrow keys, `Exclusive` for typing
  (launcher, lockscreen-like fields). Esc in a drawer emits `dismissed()`.

## 5. Theme tokens (`config/Theme.qml`)

All colors are Material You tones from the theme's `"tones"` (cli/themes/*.json; a theme
without them gets tones made from its colors by `palette_tones` in cli/facet).

| Token | Use |
|---|---|
| `page` | behind everything: lockscreen backdrop, app windows' outer page |
| `surface` | the frame, the bar, drawers, windows |
| `container` | cards, pills on the surface, the search field, notifications |
| `high` | controls on a card, hover on container, slider tracks |
| `highest` | hover on high, menu rows' hover |
| `primary` / `textOnPrimary` | the accent: filled buttons, switch on, slider fill, today, the clock on the lockscreen |
| `primaryContainer` / `textOnPrimaryContainer` | the picked tab or segment, the GoXLR icon circle, the question bubble |
| `secondary` | secondary accent text (weather hours, code) |
| `secondaryContainer` | the picked list row, chip, nav entry, launcher selection |
| `tertiary` | dots and badges, weather icon, Claude |
| `text` / `dim` | text and secondary text, icons at rest are `dim` |
| `outline` | lines, switch off, separators |
| `ok` / `okContainer` / `textOnOk` | answer, success, CI ok, talking ring |
| `error` / `errorContainer` / `textOnErrorContainer` | power, decline, muted, failed |
| `warn` | the theme's warn color |
| `hover` / `press` | state-layer washes (text at 8 % / 12 %) |
| `scrim` / `textOnScrim` | the see-through pill in a game, white text on it |
| `shadowColor` | drop shadows of floating things (popups, menus) |
| `mix(a, b, t)`, `alpha(c, a)` | color helpers for the odd derived shade |
| `dynamic` | true while colors come from the wallpaper (`Config.colorMode` "dynamic" and the file exists) |

Fonts: `Theme.font` (Rubik), `Theme.iconFont` (Material Symbols Rounded), `Theme.mono` (the
theme's mono font). Sizes `Theme.size.{tiny 12, small 13, normal 15, medium 17, large 22,
title 30, display 44, clock 210}`, icons `Theme.icon.{small 18, normal 21, large 24,
huge 54}`.

Shape (all scaled by `Config.corners`): `Theme.rounding.{small 10, normal 14, medium 18,
large 22 (cards), drawer 28, hole 26, fillet 26, full}`; fully round things use
`height / 2`. Spacing `Theme.spacing.{tiny 2, small 4, normal 8, medium 12, large 16,
huge 24}`, padding `Theme.padding.{small 8, normal 12, card 16, drawer 18}`. Frame
`Theme.frame.{bar 52, border 10}`. Controls `Theme.control.{pill 34, iconButton 36,
button 40, chip 32, field 54, slider 48, sliderThin 10, switchWidth 52, switchHeight 32,
appIcon 40}`.

Motion: `Theme.motion` ("full", "calm", "off"; off also when gsettings says
`enable-animations false`), `Theme.animated`. Durations `Theme.anim.{small 250, medium 400,
spring 450, drawerIn 550, drawerOut 450, color 600}` plus tui's `fast 200, normal 450,
slow 900`, all 0 with motion off. Curves for `Easing.BezierSpline`:
`Theme.curve.{emphasizedDecel, emphasizedAccel, standard, spring}` (spring has no overshoot
with "calm").

tui names kept for core: `name, bg, surface, surface2, shadow, primary, secondary, accent,
text, textDim, muted, frame, border, danger, warn, ok, font, iconFont, size.{small, normal,
large, clock}, anim.{fast, normal, slow}`.

## 6. Components (`qs.components`)

Every file documents its properties at the top; this is the overview.

| Component | What | Key API |
|---|---|---|
| `Bloom` (singleton) | shared state | `focusedScreen`, `gaming`, `compact(key)`, `scale(key)`, `frameAway`, `frameWindow(name)`, `inset(name, edge, exceptId)`, `anyOpen(name)`, `screenNamed(name)` |
| `Anim` / `SpringAnim` / `ColorAnim` | the three animations | NumberAnimation / NumberAnimation / ColorAnimation with Theme curves |
| `StyledText` | Text in Rubik | `dim`, `tabular` |
| `Icon` | Material Symbol | `icon`, `size`, `fill` (0..1, animates), `weight`, `dim`, `color` |
| `StateLayer` | hover/press wash + MouseArea | `color`, `radius`, `disabled`, all MouseArea signals |
| `Pill` | round row container (bar pills) | `interactive`, `active`, `padding`, `spacing`, `baseColor`, `activeColor`, `clicked(mouse)`, `scrolled(wheel)` |
| `ScrimPill` | the in-game see-through pill | as Pill |
| `IconButton` | round icon button | `icon`, `size`, `iconSize`, `active`, `filled`, `fillColor`, `tonal`, `restColor`, `iconColor`, `badge`, `disabled`, `clicked(mouse)` |
| `Button` | pill button | `text`, `icon`, `variant` (filled, tonal, plain, text, ok, danger), `compact`, `done`, `clicked(mouse)` |
| `Card` | rounded block on the surface | `padding`, `interactive`, `baseColor`, `clicked(mouse)`; one child that fills it |
| `Chip` | small pickable label | `text`, `icon`, `selected`, `closable`, `compact`, `clicked`, `closeClicked` |
| `Badge` | the "new" dot | `shown`, `size`, `ringColor` |
| `Switch` | Material switch | `checked`, `disabled`, `toggled(on)` (does not change `checked` itself) |
| `Slider` | thick (48) or thin (10) slider | `value` 0..1, `icon`, `thin`, `step`, `moved(value)`, `released()` |
| `Tabs` | choices with a sliding pill | `model` [{key, label, icon}], `current`, `variant`, `selected(key)` |
| `SegmentedButtons` | the settings' small choice rows | as Tabs |
| `SettingRow` | one settings row | `title`, `subtitle`, `icon`, `interactive`; the control is its child |
| `SearchField` | the search pill / text entry | `text`, `placeholder`, `icon`, `hint`, `password`, `input`, `focusField()`, `accepted()`, `escaped()`, `navigated(key)` |
| `AppIcon` | app icon or letter in a rounded square | `name`, `source`, `letter`, `size`, `round`, `tint` |
| `ProgressBar` | thin track | `value`, `thickness`, `color`, `trackColor`, `animated` |
| `Gauge` | 270° arc gauge | `value`, `size`, `thickness`; children in the middle |
| `Menu` | menu rows | `entries` [{text, icon, image, danger, separator, enabled, checked, more, back}], `title`, `activated(index, entry)` |
| `Drawer` | panel out of a frame edge | `screen`, `edge`, `align`, `offset`, `open`, `bodyWidth/Height`, `padding`, `bodyColor`, `radius`, `fillet`, `fillets`, `namespace`, `windowLayer`, `keyboard`, `closeOnOutside`, `grabWith`, `panelId`; reads `progress`, `extent`, `contentShown`; `dismissed()` |
| `BarMenu` | a Menu in a top Drawer under a bar button | `entries`, `title`, `menuWidth`, `popup(screen, item)`, `anchorItem`, `activated(index, entry)` |
| `HolePopup` | a window floating in the hole | `screen`, `position` (Config positions), `margin`, `insetTop/Bottom/Left/Right`, `contentScale`, `shown`, `clickThrough`, `windowLayer`, `namespace`, `keyboard` |
| `AlbumColor` (singleton, media/) | the cover's colors for the music parts | `ready`, `accent`, `container`, `textOnAccent` (the theme's while off or without a cover) |
| `ScreenFrame` | the frame on every screen | `bar` (Component), `hidden`, `color`; reads `away` |

Patterns:

```qml
// A part with a drawer (see launcher/Launcher.qml, dashboard/Dashboard.qml)
Scope {
    id: root
    property bool open: false
    property ShellScreen screen: null
    function show(screen) { root.screen = screen ?? Bloom.focusedScreen; open = true; }
    function hide() { open = false; }
    Drawer {
        screen: root.screen
        edge: "top"
        open: root.open
        namespace: "qs-dashboard"
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()
        ColumnLayout { anchors.fill: parent /* … */ }
    }
    IpcHandler { target: "dashboard" /* … */ }
}
```

```qml
// A popup in the hole that steps aside and goes compact in a game
HolePopup {
    screen: Bloom.focusedScreen
    position: Config.notificationPosition
    insetRight: Bloom.inset(screen?.name ?? "", "right")
    contentScale: Bloom.scale("notification")
    shown: Notifications.popups.length > 0
    namespace: "qs-notifications"
    Column { /* Bloom.compact("notification") ? ScrimPill rows : Card rows */ }
}
```

## 7. Game mode (`Toggles.gameMode`, `Bloom.gaming`)

- The frame and the bar step away (`Config.frameHidesInGame`, on by default): the bar flies up,
  the frame fades, the exclusive zones go and windows get the whole screen
  (`Bloom.frameAway`). Drawers and HolePopups then sit against the screen's edges by
  themselves.
- Every popup has a size (`Bloom.scale(key)`) and a "compact in a game" switch:
  `Bloom.compact(key)` is true while game mode is on **and** that switch is on. Keys:
  `notification`, `spotify`, `osd`, `voice`, `panels`.
- Compact means: a `ScrimPill` (see-through dark, white text, no frame, no shadow), one line,
  smaller (the mockup: notifications 320 wide with a 30 px round icon and the title only, calls
  and invites keep small buttons; Spotify 40 high with title and artist; the OSD a small pill
  gone after a second; voice faces 26 px), close to the screen edge (16 px from the top).
- What the notification rules hold back ("not in game") is the Notifications service's
  business, not the part's.
- Drawers: on entering game mode shell.qml does not close them; a part may (`panels`):
  `Bloom.compact("panels")` asks for a smaller panel, `Bloom.scale("panels")` is its size.
- Timings in a game are shorter (the mockup: Spotify stays 3 s instead of 4.8 s).

## 8. Config keys bloom adds (core `config/Config.qml`, "Look" section)

| Key | Default | Meaning |
|---|---|---|
| `corners` | `"round"` | `"small"`, `"round"`, `"veryRound"`: `Theme.cornerScale` 0.55 / 1 / 1.3 |
| `animations` | `"full"` | `"full"`, `"calm"` (no overshoot), `"off"` |
| `colorMode` | `"theme"` | `"theme"` or `"dynamic"`: tones from `~/.local/state/facet/bloom-dynamic.json` (`{ "tones": { … } }`, same keys as the template; nothing writes it yet) |
| `frameHidesInGame` | `true` | frame and bar step away in game mode |
| `notificationSize` | `1` | factor (0.85 small, 1 normal, 1.15 large) |
| `osdSize` | `1` | factor |
| `panelSize` | `1` | factor for dashboard, control center, launcher |
| `notificationCompactInGame` | `true` | see-through pill in a game |
| `spotifyCompactInGame` | `true` | 〃 |
| `osdCompactInGame` | `true` | 〃 |
| `voiceOverlayCompactInGame` | `true` | 〃 |
| `panelsCompactInGame` | `true` | panels open smaller in a game |
| `githubOrgs` | `["facet-shell"]` | the organisations in the dashboard's GitHub menu |
| `recordIndicator` | `true` | the recording pill (`qs-recording`) |
| `recordIndicatorPosition` | `"top-left"` | where it sits |

Existing keys bloom uses as they are: `notificationPosition`, `notificationStyle`,
`notificationWidth`, `notificationTimeout`, `notificationsMax`, `spotifyPosition`,
`spotifyFormat`, `spotifySize`, `spotifySeconds`, `voiceOverlay*` (`Size` is the voice
factor), `notifyRules`, `discordMessagesWhen`, `steamMessagesWhen`, `gameModeAuto`,
`gameClasses`, `gameModeSilent`, `goxlrGameProfile`, `lockBlur`, `idleLockMinutes`,
`idleScreenOffMinutes`, `weatherLocation`, `barOverFullscreen` (not used by the bloom bar
yet), the launcher's and GoXLR keys, and the sound channel keys `audioChannels`,
`audioRules`, `audioRulesOn` (Audio: `channelSource`, `goxlr`, `virtualActive`, `routed`,
`virtualChannels`, `masterOutput`, `masterOutputs`, `pickOutput()`; Channels: the app rules).

New service in core: `Network` (`type` "ethernet" / "wifi" / "", `name`, `strength`,
`online`, `available`), from nmcli.

## 9. What each part must keep (shell.qml and Hyprland call these)

`qs ipc call <target> <function>`: Hyprland binds them (`hypr/facet/*.lua`), so names and
signatures stay exactly as here.

| Part file | IPC target: functions | Public API used by shell.qml |
|---|---|---|
| `launcher/Launcher.qml` | `launcher`: `toggle()`, `open()`, `clipboard()`, `search(text: string)`, `mode(text: string)`, `type(text: string)`, `close()` | `open`, `show(preset)`, `hide()`, `toggle(screen)`; layer `qs-launcher` |
| `dashboard/Dashboard.qml` | `dashboard`: `toggle()`, `open()`, `close()`, `tab(name: string)` (home, media, github, performance) | `open`, `tab`, `show(screen, tab)`, `hide()`, `toggle(screen)` |
| `controlcenter/ControlCenter.qml` | `controlcenter`: `toggle()`, `open()`, `close()`, `tasks()` (→ `tasksRequested`) | `open`, `show(screen)`, `hide()`, `toggle(screen)`; signals `lockRequested`, `wallpapersRequested`, `keyboardRequested`, `settingsRequested`, `tasksRequested` |
| `notifications/History.qml` | `notifications`: `toggle()`, `open()`, `close()` | `open`, `show(screen)`, `hide()`, `toggle(screen)` |
| `notifications/Popups.qml` | – | `hidden` |
| `osd/Osd.qml` | – | `hidden` |
| `media/SpotifyPopup.qml` | – | `hidden` |
| `voice/VoiceOverlay.qml` | `voice`: `move()`, `mute()`, `deafen()`, `leave()` | `hidden`, `moving` |
| `lockscreen/Lock.qml` | `lock`: `lock()`, `isLocked(): bool`, `preview(seconds: int)` | `active`, `lock()`, signal `aboutToLock()`; idle lock, screens off, logind sleep/lock |
| `settings/SettingsApp.qml` | `settings`: `toggle()`, `open()`, `section(name: string)`, `close()` | `open`, `show(section)`, `hide()`; signals `wallpapersRequested`, `keyboardRequested` |
| `canvas/CanvasOverview.qml` | `overview`: `open()`, `close()`, `toggle()`, `zoomIn()`, `zoomOut()` | `hidden`, `open`, `show()`, `close()` |
| `canvas/CanvasDesk.qml`, `CanvasThumbs.qml` | – | – (tui's, working) |
| `screenshot/Screenshot.qml` | `screenshot`: `region()`, `record()`, `toggle()`, `screen()`, `close()` | `hidden`, `open`, `show()`, `close()` |
| `draw/DrawOverlay.qml` | `draw`: `toggle()`, `show()`, `hide()`, `clear()`, `through()` | `hidden`, `open` |
| `editor/EditorWindow.qml` | `editor`: `open(path: string)`, `paint()`, `paintOn(paper: string)`, `close()` | listens to `Editor.openRequested` |
| `gallery/MediaApp.qml` | `media`: `toggle()`, `open()`, `close()` | `open`, `show()`, `hide()` |
| `hotkeys/HotkeyOverlay.qml` | `hotkeys`: `open()`, `close()`, `toggle()` | `hidden`, `open`, `show()`, `hide()` |
| `keyboard/KeyboardApp.qml` | `keyboard`: `toggle()`, `open()`, `close()`, `mods(text: string)` | `open`, `show()`, `hide()` |
| `wallpapers/WallpaperApp.qml` | `wallpapers`: `toggle()`, `open()`, `close()` | `open`, `show()`, `hide()` |
| `wallpapers/Backdrop.qml` | – | – (tui's, working) |
| core `services/Core.qml` | `player`: `toggle()`, `next()`, `prev()` | – |

The bar (`bar/Bar.qml`) emits `dashboardRequested(screen)`, `controlCenterRequested(screen)`,
`launcherRequested(screen)`, `historyRequested(screen)`, `overviewRequested(screen)`,
`lockRequested()` and takes `hidden`, `dashboardOpen`, `controlCenterOpen`, `launcherOpen`,
`historyOpen`, `overviewOpen`. `screen` is the ShellScreen whose bar was clicked: open the
drawer there.

Before the lockscreen takes its snapshot, `Lock.aboutToLock` hides every drawer and app
(shell.qml); a new part with something on screen adds itself there.

## 10. The bar (built)

- Left: the logo (`local_florist` in primary) and the clock pill (middle of the screen) open
  the dashboard. The tray pill: only apps with a tray icon (Quickshell.Services.SystemTray),
  gone without any; click activates (an app with only a menu opens it), right click opens the
  app's menu out of the bar in bloom's look (`TrayMenu`, submenus in place), middle click the
  second action, wheel to the app, a tertiary dot while it needs attention.
- Right: launcher, canvas overview (only with the canvas layout), the bell (dot while
  `Notifications.missed > 0`), the status pill (network by type and Wi-Fi signal, volume,
  mic, a battery only when UPower reports one; click: control center, wheel: volume) and
  power (`PowerMenu`: lock, sleep, then log out, restart, shut down with a second click).
- Stay awake (`Toggles.stayAwake`) keeps an idle inhibitor on the first screen's frame.

## 11. Open points

- `colorMode: "dynamic"` has the hook (the file and the merge in Theme) but no generator yet.
- `barOverFullscreen` (the bar coming down over a fullscreen window) is not in the bloom bar.
- The login screen, boot splash and GRUB menu still come from style-tui.
- No IPC key for the dashboard is bound in Hyprland yet (`qs ipc call dashboard toggle`).
- Layer blur behind the in-game pills needs a Hyprland layer rule; not set.
