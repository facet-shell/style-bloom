pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.components
import qs.config

// Material-You colors from the album cover for the music parts (Config.albumColors): the
// Spotify bloom, the dashboard's media cards and the lockscreen's music read these instead
// of Theme.primary / Theme.container. The cover is drawn 16x16 on a Canvas (which needs a
// window to paint, so it sits in a 1x1 see-through window on the background layer), the
// pixels go into hue buckets and the most vibrant bucket wins, its tone pushed until it
// reads on the surface and the container. When the Canvas never paints, `magick` on PATH
// reads file:// covers instead; without that, or with the switch off, a grey cover or no
// cover, the three colors are the theme's exactly: everything falls back on its own.
//
//   AlbumColor.ready         a cover color is in use (otherwise the theme's colors below)
//   AlbumColor.accent        a vibrant tone of the cover, else Theme.primary
//   AlbumColor.container     a soft wash of it for card backgrounds, else Theme.container
//   AlbumColor.textOnAccent  text on `accent` (dark or light by luminance), else textOnPrimary
//
// The colors crossfade with ColorAnim (Theme.anim.color) when the song changes.
Singleton {
    id: root

    // The player whose cover the cards show (the dashboard's rule): Spotify while it plays,
    // then whatever plays, then Spotify, then any player
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        const spotify = list.find(p => p.identity === "Spotify");
        return (spotify?.isPlaying ? spotify : null) ?? list.find(p => p.isPlaying) ?? spotify ?? list[0] ?? null;
    }
    readonly property string art: Config.albumColors ? (player?.trackArtUrl ?? "") : ""

    property bool ready: false
    // The bucket's color as it came off the cover; the tone is made from it against the
    // theme, so a theme change retones without sampling again
    property color sampled
    readonly property color toned: tone(sampled)

    property color accent: ready ? toned : Theme.primary
    property color container: ready ? Theme.mix(toned, Theme.container, 0.8) : Theme.container
    // Whichever of the theme's two text tones is dark goes on a light accent, the other on a
    // dark one (the W3C crossover for black vs white)
    readonly property color darkText: lum(Theme.text) < lum(Theme.textOnPrimary) ? Theme.text : Theme.textOnPrimary
    readonly property color lightText: lum(Theme.text) < lum(Theme.textOnPrimary) ? Theme.textOnPrimary : Theme.text
    property color textOnAccent: ready ? (lum(toned) > 0.18 ? darkText : lightText) : Theme.textOnPrimary

    Behavior on accent {
        ColorAnim {
            duration: Theme.anim.color
        }
    }
    Behavior on container {
        ColorAnim {
            duration: Theme.anim.color
        }
    }
    Behavior on textOnAccent {
        ColorAnim {
            duration: Theme.anim.color
        }
    }

    // The last cover sampled, so pause / resume and a player coming back cost nothing
    property string doneUrl: ""
    property color doneColor
    // What the Canvas is asked to paint right now
    property string pending: ""
    // Set once a requested paint never came: the Canvas has no working window here
    property bool canvasDead: false

    onArtChanged: follow()
    Component.onCompleted: follow()

    function follow() {
        stall.stop();
        const url = art;
        if (url === "") {
            ready = false;
            return;
        }
        if (url === doneUrl) {
            sampled = doneColor;
            ready = true;
            return;
        }
        // The old color stays up while the new cover loads, so the change is one crossfade
        if (canvasDead) {
            viaMagick(url);
            return;
        }
        sampler.loadImage(url);
        if (sampler.isImageLoaded(url))
            sample(url);
    }

    function sample(url) {
        if (canvasDead) {
            viaMagick(url);
            return;
        }
        pending = url;
        // The window is still coming: the Canvas asks again once it can paint
        if (!sampler.available)
            return;
        sampler.requestPaint();
        stall.restart();
    }

    // col is null when the cover gave nothing usable (grey, broken): no tint then
    function finish(url, col) {
        if (col !== null) {
            doneUrl = url;
            doneColor = col;
        }
        if (url !== art)
            return;
        if (col === null) {
            ready = false;
        } else {
            sampled = col;
            ready = true;
        }
    }

    function viaMagick(url) {
        if (!url.startsWith("file://")) {
            ready = false;
            return;
        }
        magickProcess.createObject(root, { url, path: decodeURIComponent(url.slice(7)) });
    }

    // ── Picking the color ────────────────────────────────────

    // rgba bytes of the 16x16 cover → the most vibrant hue bucket's average, or null. Twelve
    // 30° buckets; a pixel counts by its saturation, mid lightness counts more, greys, near
    // black and near white not at all. The average is only over the winning bucket, so it
    // does not go muddy like an average over the whole cover would.
    function pick(data) {
        const bins = [];
        for (let i = 0; i < 12; i++)
            bins.push({ w: 0, r: 0, g: 0, b: 0 });
        for (let i = 0; i + 3 < data.length; i += 4) {
            if (data[i + 3] < 128)
                continue;
            const r = data[i] / 255, g = data[i + 1] / 255, b = data[i + 2] / 255;
            const max = Math.max(r, g, b), min = Math.min(r, g, b);
            const l = (max + min) / 2, c = max - min;
            if (c < 0.1 || l < 0.12 || l > 0.9)
                continue;
            const s = c / (1 - Math.abs(2 * l - 1));
            let h = max === r ? (g - b) / c : max === g ? (b - r) / c + 2 : (r - g) / c + 4;
            h = (h * 60 + 360) % 360;
            const w = s * (1 - Math.abs(2 * l - 1) * 0.5);
            const bin = bins[Math.floor(h / 30) % 12];
            bin.w += w;
            bin.r += r * w;
            bin.g += g * w;
            bin.b += b * w;
        }
        let best = null;
        for (const bin of bins)
            if (bin.w > 0 && (best === null || bin.w > best.w))
                best = bin;
        // Less than a handful of weak pixels is noise, not a color
        if (best === null || best.w < 1.5)
            return null;
        return Qt.rgba(best.r / best.w, best.g / best.w, best.b / best.w, 1);
    }

    // sRGB relative luminance, 0..1
    function lum(c) {
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    function contrast(a, b) {
        const la = lum(a), lb = lum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // The cover's hue at a tone that reads on the surface and the container: light on a dark
    // theme, dark on a light one, pushed further away until the contrast is at least 3
    function tone(c) {
        const h = c.hslHue < 0 ? 0 : c.hslHue;
        const s = Math.max(0.4, Math.min(0.85, c.hslSaturation));
        const dark = lum(Theme.surface) < 0.5;
        let l = dark ? 0.72 : 0.42;
        let col = Qt.hsla(h, s, l, 1);
        for (let i = 0; i < 8 && (contrast(col, Theme.surface) < 3 || contrast(col, Theme.container) < 3); i++) {
            l += dark ? 0.04 : -0.04;
            col = Qt.hsla(h, s, l, 1);
        }
        return col;
    }

    // ── The sampler ──────────────────────────────────────────

    // A Canvas paints only inside a window, so a 1x1 see-through one on the background layer
    // holds it; it takes no clicks and reserves nothing
    PanelWindow {
        id: host

        visible: Config.albumColors
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "qs-album-color"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            bottom: true
            left: true
        }
        mask: Region {}

        Canvas {
            id: sampler

            width: 16
            height: 16
            // Not drawn, only painted into: the pixels are read right back
            opacity: 0
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            // The window came late: paint what is waiting
            onAvailableChanged: if (available && root.pending !== "")
                root.sample(root.pending)

            onImageLoaded: {
                const url = root.art;
                if (url === "" || url === root.doneUrl)
                    return;
                if (isImageLoaded(url))
                    root.sample(url);
                else if (isImageError(url))
                    root.finish(url, null);
            }

            onPaint: {
                stall.stop();
                const url = root.pending;
                if (url === "")
                    return;
                root.pending = "";
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.drawImage(url, 0, 0, width, height);
                const data = ctx.getImageData(0, 0, width, height).data;
                root.finish(url, root.pick(data));
                unloadImage(url);
            }
        }
    }

    // No paint within three seconds of asking: the Canvas path is dead on this machine
    Timer {
        id: stall

        interval: 3000
        onTriggered: {
            root.canvasDead = true;
            const url = root.pending;
            root.pending = "";
            root.viaMagick(url);
        }
    }

    // The fallback: ImageMagick writes the 16x16 pixels as text, one "x,y: (r,g,b)" a line.
    // Missing magick means an empty output, which reads as "no color".
    Component {
        id: magickProcess

        Process {
            id: proc

            property string url: ""
            property string path: ""

            command: ["sh", "-c", 'command -v magick >/dev/null 2>&1 || exit 3; exec magick "$0" -resize "16x16!" -depth 8 txt:-', path]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const data = [];
                    const line = /^\d+,\d+:\s*\((\d+),(\d+),(\d+)/gm;
                    let m;
                    while ((m = line.exec(text)) !== null)
                        data.push(Number(m[1]), Number(m[2]), Number(m[3]), 255);
                    root.finish(proc.url, data.length > 0 ? root.pick(data) : null);
                    proc.destroy();
                }
            }
        }
    }
}
