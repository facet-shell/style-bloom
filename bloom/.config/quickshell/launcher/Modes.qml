import QtQuick
import Quickshell
import qs.config
import qs.services

// What the launcher does with a query: which mode a prefix picks, the result rows and what
// Enter does with them. tui's modes, the same prefixes, with bloom's icons; Launcher.qml
// draws them.
//
// Prefixes: none apps · = calc · > commands · : power · s spotify · d discord · t timer
//           a alarm · # emoji · / files · ssh hosts · ; clipboard · ? web · c claude (when
//           installed) · wall wallpapers ("wall" alone: the big menu, "wall word": a row)
// Letters need a space after them ("s " is spotify, "s" alone still searches apps).
//
// Every row has: kind, title, desc, category, symbol (Material Symbols name) or emoji, tint,
// image (a picture's path or URL), iconName (from the icon theme), letter, rows ([label,
// value] for the preview pane), optional markup (highlighted title), body, preview,
// textPreview, thumbSource, pdfSource and keys (the hint line).
Item {
    id: root

    visible: false

    readonly property var symbolModes: ["=", ">", ":", "#", "/", ";", "?"]
    // "ssh" before "s", otherwise "ssh foo" would be a Spotify search
    readonly property var wordModes: Claude.available ? ["wall", "ssh", "s", "d", "t", "a", "c"] : ["wall", "ssh", "s", "d", "t", "a"]
    readonly property var names: ({
        "": "apps", "=": "calculator", ">": "commands", ":": "power", s: "Spotify", d: "Discord", t: "timer",
        a: "alarm", "#": "emoji", "/": "files", ssh: "ssh", ";": "clipboard", "?": "web search", c: "Claude",
        wall: "wallpapers"
    })
    readonly property var icons: ({
        "": "search", "=": "calculate", ">": "terminal", ":": "power_settings_new", s: "music_note", d: "forum",
        t: "timer", a: "alarm", "#": "mood", "/": "folder", ssh: "dns", ";": "content_paste", "?": "travel_explore",
        c: "auto_awesome", wall: "wallpaper"
    })
    // Tab walks through them in this order
    readonly property var order: ["", "=", ">", ":", "s", "d", "t", "a", "#", "/", "ssh", ";", "?"]
        .concat(Claude.available ? ["c"] : []).concat(["wall"])

    readonly property var powerActions: [
        { name: "lock", desc: "Lock the screen", symbol: "lock", tint: Theme.primary,
          // Short delay so the snapshot does not catch the closing launcher
          command: ["sh", "-c", "sleep 0.3; qs ipc call lock lock"] },
        { name: "logout", desc: "End the Hyprland session", symbol: "logout", tint: Theme.dim, command: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { name: "suspend", desc: "Sleep, locks first", symbol: "bedtime", tint: Theme.tertiary, command: ["systemctl", "suspend"] },
        { name: "reboot", desc: "Restart the computer", symbol: "restart_alt", tint: Theme.warn, command: ["systemctl", "reboot"] },
        { name: "shutdown", desc: "Power off", symbol: "power_settings_new", tint: Theme.error, command: ["systemctl", "poweroff"] }
    ]

    // The other parts, reached through their IPC (a part never reaches into another's files).
    // query: what the field turns into instead of running something
    readonly property var commands: [
        { name: "wallpaper", desc: "the wallpaper menu", symbol: "wallpaper", query: "wall" },
        { name: "settings", desc: "everything bloom can change", symbol: "settings", command: ["qs", "ipc", "call", "settings", "open"] },
        { name: "theme", desc: "colors, corners and motion in the settings", symbol: "palette", command: ["qs", "ipc", "call", "settings", "section", "look"] },
        { name: "canvas", desc: "the infinite canvas overview", symbol: "grid_view", command: ["qs", "ipc", "call", "overview", "open"] },
        { name: "dashboard", desc: "weather, media, GitHub, performance", symbol: "dashboard", command: ["qs", "ipc", "call", "dashboard", "open"] },
        { name: "control center", desc: "quick tiles, sliders, the mixer", symbol: "tune", command: ["qs", "ipc", "call", "controlcenter", "open"] },
        { name: "notifications", desc: "the history under the bell", symbol: "notifications", command: ["qs", "ipc", "call", "notifications", "open"] },
        { name: "task manager", desc: "what runs and what it uses", symbol: "monitoring", command: ["qs", "ipc", "call", "controlcenter", "tasks"] },
        // The launcher must be gone before the screen is captured
        { name: "screenshot", desc: "a region of the screen", symbol: "screenshot_region", command: ["sh", "-c", "sleep 0.3; qs ipc call screenshot region"] },
        { name: "record", desc: "record the screen", symbol: "videocam", command: ["sh", "-c", "sleep 0.3; qs ipc call screenshot record"] },
        { name: "draw", desc: "draw on the screen", symbol: "draw", command: ["qs", "ipc", "call", "draw", "toggle"] },
        { name: "gallery", desc: "screenshots and recordings", symbol: "photo_library", command: ["qs", "ipc", "call", "media", "open"] },
        { name: "keyboard", desc: "the keyboard app", symbol: "keyboard", command: ["qs", "ipc", "call", "keyboard", "open"] },
        { name: "hotkeys", desc: "every shortcut on one page", symbol: "keyboard_command_key", command: ["qs", "ipc", "call", "hotkeys", "open"] },
        { name: "lock", desc: "lock the screen", symbol: "lock", command: ["sh", "-c", "sleep 0.3; qs ipc call lock lock"] }
    ]

    // { mode, rest, big }: big is "wall" on its own, the wide wallpaper menu
    function parse(query) {
        if (query.trim().toLowerCase() === "wall")
            return { mode: "wall", rest: "", big: true };
        const c = query.charAt(0);
        if (symbolModes.includes(c))
            return { mode: c, rest: query.slice(1).trim(), big: false };
        for (const w of wordModes)
            if (query.startsWith(`${w} `))
                return { mode: w, rest: query.slice(w.length + 1).trim(), big: false };
        return { mode: "", rest: query.trim(), big: false };
    }

    // The text that picks a mode; "wall" alone is the big menu, with words the quick row
    function prefix(mode, rest) {
        if (mode === "wall")
            return rest ? "wall " : "wall";
        return mode === "" || symbolModes.includes(mode) ? mode : `${mode} `;
    }

    // ── Helpers ──────────────────────────────────────────────

    function escapeHtml(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Name with the matched letters highlighted (Text.StyledText)
    function markup(text, idx) {
        let out = "";
        for (let i = 0; i < text.length; i++) {
            const c = escapeHtml(text[i]);
            out += idx.includes(i) ? `<font color="${Theme.primary}"><b>${c}</b></font>` : c;
        }
        return out;
    }

    // A path as a URL for Image; encoded per part, a "#" or "?" in a file name would end it early
    function fileUrl(path) {
        const p = String(path ?? "");
        if (p === "" || p.includes("://"))
            return p;
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    function calculate(expr) {
        const plain = expr.replace(/,/g, ".");
        if (plain === "" || !/^[\d\s+\-*\/().%^]+$/.test(plain))
            return null;
        try {
            const value = Function(`"use strict"; return (${plain.replace(/\^/g, "**")});`)();
            return typeof value === "number" && isFinite(value) ? Math.round(value * 1e10) / 1e10 : null;
        } catch (e) {
            return null;
        }
    }

    // "1m 10s", "1h30m", "90s", "1:10", "1:02:03"; a bare number counts in bareUnit seconds
    function parseDuration(text, bareUnit) {
        const t = text.trim().toLowerCase();
        if (t === "")
            return null;
        let m;
        if ((m = /^(\d+):(\d{1,2})(?::(\d{1,2}))?$/.exec(t)))
            return m[3] !== undefined ? +m[1] * 3600 + +m[2] * 60 + +m[3] : +m[1] * 60 + +m[2];
        if (/^\d+([.,]\d+)?$/.test(t))
            return Math.round(parseFloat(t.replace(",", ".")) * bareUnit);
        let total = 0, rest = t;
        while (rest !== "") {
            m = /^(\d+(?:[.,]\d+)?)\s*(hours?|hrs?|h|std|minutes?|mins?|m|seconds?|secs?|sek|s)\s*/.exec(rest);
            if (!m)
                return null;
            const n = parseFloat(m[1].replace(",", "."));
            const unit = m[2].charAt(0);
            total += n * (unit === "h" ? 3600 : unit === "m" ? 60 : 1);
            rest = rest.slice(m[0].length);
        }
        return total > 0 ? Math.round(total) : null;
    }

    function info(title, desc, symbol) {
        return { kind: "info", title, desc: desc ?? "", category: "", symbol: symbol ?? "info", tint: Theme.dim, rows: [] };
    }

    function run(command) {
        Quickshell.execDetached(command);
    }

    function copy(text) {
        run(["wl-copy", "--", String(text)]);
    }

    // ── Results ──────────────────────────────────────────────

    function compute(mode, rest) {
        switch (mode) {
        case "=": return calcRows(rest);
        case ">": return commandRows(rest);
        case ":": return powerRows(rest);
        case "s": return spotifyRows(rest);
        case "d": return discordRows(rest);
        case "t": return timerRows(rest);
        case "a": return alarmRows(rest);
        case "#": return emojiRows(rest);
        case "/": return fileRows(rest);
        case "ssh": return sshRows(rest);
        case ";": return clipRows(rest);
        case "?": return webRows(rest);
        // Claude and the wallpapers have their own views
        case "c":
        case "wall":
            return [];
        default: return appRows(rest);
        }
    }

    function appRows(rest) {
        const rows = Apps.search(rest).map(({ entry, idx }) => {
            const win = Apps.windowOf(entry);
            return {
                kind: "app", entry, running: win !== null,
                title: entry.name, markup: markup(entry.name, idx),
                desc: win ? `running · ${win.title}` : (entry.comment || entry.genericName || ""),
                category: win ? "running" : Apps.categoryOf(entry),
                iconName: entry.icon ?? "", letter: entry.name.charAt(0).toUpperCase(),
                rows: [["category", Apps.categoryOf(entry)], ["runs", entry.execString], ["used", `${Apps.uses(entry)} times`],
                    ["window", win ? win.title : "none open"]],
                keys: win ? "enter bring it here · shift+enter a new one" : "enter start"
            };
        });
        // Nothing typed: what already runs comes first, the rest by use
        return rest === "" ? rows.filter(r => r.running).concat(rows.filter(r => !r.running)) : rows;
    }

    function calcRows(rest) {
        const value = calculate(rest);
        return [{
            kind: "calc", value,
            title: rest === "" ? "type a calculation" : value === null ? "not a calculation" : `${rest} = ${value}`,
            desc: value === null ? "+ − × ÷ ( ) % ^" : "enter copies the result",
            category: "calc", symbol: "calculate", tint: Theme.primary,
            rows: [["input", rest || "–"], ["enter", "copies the result"]],
            keys: "enter copy the result"
        }];
    }

    // The other parts by name first, then the text as a shell command in Ghostty
    function commandRows(rest) {
        const found = commands
            .map(c => ({ c, match: rest === "" ? { score: 0, idx: [] } : Apps.fuzzy(c.name, rest) }))
            .filter(x => x.match)
            .sort((a, b) => b.match.score - a.match.score)
            .map(({ c, match }) => ({
                kind: "command", command: c.command ?? null, query: c.query ?? null,
                title: c.name, markup: markup(c.name, match.idx), desc: c.desc,
                category: "bloom", symbol: c.symbol, tint: Theme.primary, rows: [],
                keys: c.query ? "enter open" : "enter open · esc close"
            }));
        if (rest === "")
            return found;
        return found.concat([{
            kind: "run", command: rest,
            title: rest, desc: "run it in Ghostty, the window stays open",
            category: "run", symbol: "terminal", tint: Theme.secondary,
            rows: [["command", rest], ["shell", "fish"]],
            keys: "enter run in a terminal"
        }]);
    }

    function powerRows(rest) {
        return powerActions
            .map(p => ({ action: p, match: rest === "" ? { score: 0, idx: [] } : Apps.fuzzy(p.name, rest) }))
            .filter(x => x.match)
            .sort((a, b) => b.match.score - a.match.score)
            .map(({ action, match }) => ({
                kind: "power", name: action.name, command: action.command,
                title: action.name, markup: markup(action.name, match.idx),
                desc: action.desc, category: "power", symbol: action.symbol, tint: action.tint,
                rows: [["runs", action.command.join(" ")], ["confirm", action.name === "lock" ? "no" : "press enter twice"]],
                keys: action.name === "lock" ? "enter lock" : "enter twice"
            }));
    }

    // ── s: Spotify ───────────────────────────────────────────

    readonly property var spotifyWords: ({
        play: "play", resume: "play", pause: "pause", stop: "pause", toggle: "toggle",
        next: "next", n: "next", skip: "next", prev: "prev", previous: "prev", p: "prev",
        forward: "forward", fw: "forward", f: "forward", ff: "forward",
        back: "back", b: "back", rewind: "back", rw: "back",
        shuffle: "shuffle", repeat: "repeat", loop: "repeat", like: "like", heart: "like"
    })
    readonly property var spotifySymbols: ({
        play: "play_arrow", pause: "pause", toggle: "play_pause", next: "skip_next", prev: "skip_previous",
        forward: "fast_forward", back: "fast_rewind", jump: "schedule", shuffle: "shuffle", repeat: "repeat", like: "favorite"
    })
    readonly property var spotifyLabels: ({
        play: "play", pause: "pause", toggle: "play / pause", next: "next track", prev: "previous track",
        forward: "forward", back: "back", jump: "jump to", shuffle: "shuffle on / off", repeat: "repeat: off → all → track", like: "like / unlike"
    })

    // { action, seconds } when the query is a control word (with a time for forward/back) or a bare time
    function spotifyCommand(rest) {
        const words = rest.split(/\s+/);
        const action = spotifyWords[words[0].toLowerCase()];
        const args = words.slice(1).join(" ");
        if (action === "forward" || action === "back") {
            const seconds = args === "" ? 10 : parseDuration(args, 1);
            return seconds === null ? null : { action, seconds };
        }
        if (action && args === "")
            return { action, seconds: 0 };
        const at = /\d/.test(rest) ? parseDuration(rest, 1) : null;
        return at === null ? null : { action: "jump", seconds: at };
    }

    // "s play daft punk" searches "daft punk"; a seek with a time ("f 30", "1:10") searches
    // nothing; everything else searches the whole query, so "s next" also finds songs called next
    function spotifySearchText(rest) {
        const command = spotifyCommand(rest);
        if (command && (command.action === "jump" || ((command.action === "forward" || command.action === "back") && /\s/.test(rest))))
            return "";
        const m = /^(play|p)\s+(.+)$/i.exec(rest);
        return m && command === null ? m[2] : rest;
    }

    function nowPlaying() {
        const p = Spotify.spotifyPlayer ?? Spotify.otherPlayer;
        return p && p.trackTitle ? `${p.trackTitle} · ${p.trackArtist}` : "nothing";
    }

    function controlRow(action, seconds) {
        const time = seconds > 0 ? ` ${Timers.formatSeconds(seconds)}` : "";
        return {
            kind: "spotify-control", action, seconds,
            title: `${spotifyLabels[action]}${time}`,
            desc: `now: ${nowPlaying()}`,
            category: "control", symbol: spotifySymbols[action] ?? "play_arrow", tint: Theme.primary,
            rows: [["via", Spotify.via], ["playing", nowPlaying()]],
            keys: "enter do it"
        };
    }

    function spotifyRows(rest) {
        if (rest === "")
            return [["toggle", 0], ["next", 0], ["prev", 0], ["forward", 10], ["back", 10], ["shuffle", 0], ["repeat", 0], ["like", 0]]
                .map(([a, s]) => controlRow(a, s))
                .concat([info(`via ${Spotify.via}`, "type to search tracks, artists, albums and playlists", "music_note")]);

        const out = [];
        const command = spotifyCommand(rest);
        if (command)
            out.push(controlRow(command.action, command.seconds));

        const text = spotifySearchText(rest);
        if (text === "")
            return out;
        if (!Spotify.canSearch)
            return out.concat([info("search needs Spotify connected", "Spicetify extension or Web API, see docs/spotify.md", "link_off")]);
        if (Spotify.query !== text || Spotify.searching)
            return out.concat([info("searching …", "", "progress_activity")]);
        if (Spotify.error !== "")
            return out.concat([info("search failed", Spotify.error, "error")]);
        const symbols = { track: "music_note", artist: "person", album: "album", playlist: "queue_music" };
        return out.concat(Spotify.results.map(item => ({
            kind: "spotify-item", item,
            title: item.title, desc: item.subtitle,
            category: item.kind, symbol: symbols[item.kind] ?? "music_note", tint: Theme.tertiary, image: item.image ?? "",
            rows: [["type", item.kind], ["length", item.length > 0 ? Timers.formatSeconds(item.length) : "–"], ["found by", Spotify.source]],
            keys: item.kind === "track" ? "enter play · shift+enter queue" : "enter play"
        })));
    }

    // ── d: Discord ───────────────────────────────────────────

    // "now", "5m", "2h", "3d" for the DM list
    function when(ms) {
        if (!ms)
            return "";
        const minutes = Math.floor((Date.now() - ms) / 60000);
        return minutes < 1 ? "now" : minutes < 60 ? `${minutes}m` : minutes < 1440 ? `${Math.floor(minutes / 60)}h` : `${Math.floor(minutes / 1440)}d`;
    }

    function findContacts(name) {
        const list = DiscordBridge.contacts;
        // Plain "d": the chats that moved last (you wrote or someone wrote you), newest first
        if (name === "")
            return list.filter(c => c.channelId && (c.time ?? 0) > 0).slice(0, 20);
        return list
            .map(c => ({ c, match: Apps.fuzzy(c.name, name) ?? Apps.fuzzy(c.username, name) }))
            .filter(x => x.match)
            .sort((a, b) => b.match.score - a.match.score)
            .map(x => x.c);
    }

    function contactRow(c, kind, title, content) {
        const last = c.last ?? null;
        const who = last ? (last.mine ? "you" : c.group ? last.author : "") : "";
        const line = last ? `${who ? `${who}: ` : ""}${last.content}` : "";
        const pings = c.mentions ?? 0;
        const status = pings > 0 ? `${pings} ping${pings === 1 ? "" : "s"}` : c.unread ? "new" : "";
        const activity = c.time ? [["last", line || "–"], ["when", `${when(c.time)}${status ? ` · ${status}` : ""}`]] : [];
        return {
            kind, contact: c, content: content ?? "",
            title,
            desc: content ? `“${content}”` : line ? `${status ? `${status} · ` : ""}${line}` : c.username !== "" ? `@${c.username}` : "",
            body: content ? "" : line,
            // The label on the right tells a group DM from a person, both look alike otherwise
            category: c.group ? "group" : status || "dm", image: c.avatar ?? "", letter: c.name.charAt(0).toUpperCase(),
            round: true, tint: Theme.tertiary,
            rows: (c.group ? [["group", c.username], ["dm", "open"]]
                : [["user", c.username !== "" ? `@${c.username}` : c.name], ["dm", c.channelId ? "open" : "none yet"]]).concat(activity),
            keys: kind === "discord-open" ? (c.group ? "enter open group · shift+enter call" : "enter open dm · shift+enter call")
                : kind === "discord-call" ? "enter call" : "enter send"
        };
    }

    function discordRows(rest) {
        if (!DiscordBridge.connected)
            return [info("Discord is not connected", "start Vesktop with the ShellBridge plugin (facet install vencord)", "link_off")];
        const words = rest.split(/\s+/);
        const first = words[0].toLowerCase();

        if (first === "reply") {
            const content = rest.slice(5).trim();
            const to = DiscordBridge.lastDm;
            if (!to)
                return [info("no DM to reply to yet", "write someone a DM in Discord first", "forum")];
            return [{
                kind: "discord-reply", content,
                title: `reply to ${to.name}`,
                desc: content === "" ? "type the message" : `“${content}”`,
                category: "discord", symbol: "reply", tint: Theme.tertiary,
                rows: [["to", to.name], ["why", to.guessed ? "most recent DM (you have not written since Discord started)" : "the last DM you wrote"]],
                keys: "enter send"
            }];
        }
        if (first === "msg" && words.length >= 2) {
            const content = words.slice(2).join(" ");
            const found = findContacts(words[1]).slice(0, 9);
            return found.length === 0 ? [info(`nobody called ${words[1]}`, "", "person_off")]
                : found.map(c => contactRow(c, "discord-send", `message ${c.group ? "group " : ""}${c.name}`, content));
        }
        if (first === "call" && words.length >= 2) {
            const found = findContacts(words.slice(1).join(" ")).slice(0, 9);
            return found.length === 0 ? [info("nobody by that name", "", "person_off")]
                : found.map(c => contactRow(c, "discord-call", `call ${c.group ? "group " : ""}${c.name}`));
        }
        const found = findContacts(rest);
        if (found.length === 0)
            return [info(DiscordBridge.contacts.length === 0 ? "loading contacts …" : "nobody by that name",
                "d name · d call name · d msg name text · d reply text", "forum")];
        return found.map(c => contactRow(c, "discord-open", c.name));
    }

    // ── t: timers ────────────────────────────────────────────

    // "5m tea", "tea 5m", "1:30", "25" (minutes) → { seconds, label }
    function parseTimer(rest) {
        const words = rest.split(/\s+/);
        for (let k = words.length; k >= 1; k--) {
            const front = parseDuration(words.slice(0, k).join(" "), 60);
            if (front !== null)
                return { seconds: front, label: words.slice(k).join(" ") };
            const back = parseDuration(words.slice(words.length - k).join(" "), 60);
            if (back !== null)
                return { seconds: back, label: words.slice(0, words.length - k).join(" ") };
        }
        return null;
    }

    function runningTimers() {
        return Timers.timers.map(t => ({
            kind: "timer-running", timer: t,
            title: `${Timers.formatSeconds(Timers.left(t))} · ${t.label || "timer"}`,
            desc: `of ${Timers.formatSeconds(t.total)} · ends ${Timers.whenText(t.ends)}`,
            category: "running", symbol: "hourglass_top", tint: Theme.secondary,
            rows: [["ends", Timers.whenText(t.ends)], ["enter", "stops it"]],
            keys: "enter stop timer"
        }));
    }

    function timerRows(rest) {
        if (rest === "") {
            const running = runningTimers();
            return running.length > 0 ? running : [info("type a time", "t 5m tea · t 1:30 · t 25 (minutes) · t 1h 30m", "timer")];
        }
        const parsed = parseTimer(rest);
        if (!parsed)
            return [info("not a time", "t 5m tea · t 1:30 · t 25 (minutes)", "timer")].concat(runningTimers());
        return [{
            kind: "timer-start", seconds: parsed.seconds, label: parsed.label,
            title: `start ${Timers.formatSeconds(parsed.seconds)}${parsed.label !== "" ? ` · ${parsed.label}` : ""}`,
            desc: `rings at ${Timers.whenText(Date.now() + parsed.seconds * 1000)}, stays until snooze or done`,
            category: "timer", symbol: "timer", tint: Theme.primary,
            rows: [["length", Timers.formatSeconds(parsed.seconds)], ["label", parsed.label || "–"], ["snooze", `${Config.snoozeMinutes} min`]],
            keys: "enter start"
        }].concat(runningTimers());
    }

    // ── a: alarms ────────────────────────────────────────────

    readonly property var dayAliases: ({
        su: 0, sun: 0, sunday: 0, so: 0, sonntag: 0,
        m: 1, mo: 1, mon: 1, monday: 1, montag: 1,
        tu: 2, tue: 2, tues: 2, tuesday: 2, di: 2, dienstag: 2,
        w: 3, we: 3, wed: 3, wednesday: 3, mi: 3, mittwoch: 3,
        th: 4, thu: 4, thr: 4, thur: 4, thurs: 4, thursday: 4, do: 4, donnerstag: 4,
        f: 5, fr: 5, fri: 5, friday: 5, freitag: 5,
        sa: 6, sat: 6, saturday: 6, samstag: 6
    })
    readonly property var dayGroups: ({
        daily: [0, 1, 2, 3, 4, 5, 6], everyday: [0, 1, 2, 3, 4, 5, 6], täglich: [0, 1, 2, 3, 4, 5, 6],
        weekdays: [1, 2, 3, 4, 5], werktags: [1, 2, 3, 4, 5], weekend: [6, 0], wochenende: [6, 0]
    })

    // "m-f", "m,w,f", "tu,th", "sa-su", "daily" → day numbers, or { error }
    function parseDays(word) {
        const w = word.toLowerCase();
        if (dayGroups[w])
            return dayGroups[w];
        const out = [];
        for (const part of w.split(",").filter(p => p !== "")) {
            const ends = part.split("-");
            for (const e of ends) {
                if (e === "t")
                    return { error: "t could be tuesday or thursday: write tu or th" };
                if (e === "s")
                    return { error: "s could be saturday or sunday: write sa or su" };
                if (dayAliases[e] === undefined)
                    return null;
            }
            if (ends.length === 1)
                out.push(dayAliases[ends[0]]);
            else if (ends.length === 2)
                for (let d = dayAliases[ends[0]]; ; d = (d + 1) % 7) {
                    out.push(d);
                    if (d === dayAliases[ends[1]])
                        break;
                }
            else
                return null;
        }
        return out.length > 0 ? out.filter((d, i) => out.indexOf(d) === i) : null;
    }

    // "10:00", "7:30", "7.30", "7pm", "19" → { hour, minute }
    function parseClock(word) {
        const m = /^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$/i.exec(word);
        if (!m || (m[2] === undefined && m[3] === undefined && word.length > 2))
            return null;
        let hour = +m[1];
        const minute = m[2] !== undefined ? +m[2] : 0;
        if (m[3]) {
            if (hour < 1 || hour > 12)
                return null;
            hour = hour % 12 + (m[3].toLowerCase() === "pm" ? 12 : 0);
        }
        return hour < 24 && minute < 60 ? { hour, minute } : null;
    }

    // "laundry 10:00 m-f", "7:30 tu,th gym", "call mom 18:00" → { hour, minute, days, label } or { error }
    function parseAlarm(rest) {
        const words = rest.split(/\s+/);
        // A time with ":" wins over a bare number, so "gym 2 7:30" reads 7:30
        let at = words.findIndex(w => /[:.]|am$|pm$/i.test(w) && parseClock(w));
        if (at < 0)
            at = words.findIndex(w => parseClock(w));
        if (at < 0)
            return { error: "no time yet: a laundry 10:00 m-f" };
        const time = parseClock(words[at]);
        let days = [], i = at + 1;
        for (; i < words.length; i++) {
            const d = parseDays(words[i]);
            if (d === null)
                break;
            if (d.error)
                return d;
            days = days.concat(d.filter(x => !days.includes(x)));
        }
        const label = words.slice(0, at).concat(words.slice(i)).join(" ");
        return { hour: time.hour, minute: time.minute, days, label };
    }

    function alarmList() {
        return Timers.alarms.map(a => ({
            kind: "alarm", alarm: a,
            title: `${Timers.clock(a.hour, a.minute)}${a.label !== "" ? ` · ${a.label}` : ""}`,
            desc: a.enabled ? `${Timers.daysText(a.days)} · next ${Timers.whenText(a.next)}` : `${Timers.daysText(a.days)} · off`,
            category: a.enabled ? "on" : "off", symbol: a.enabled ? "alarm" : "alarm_off", tint: a.enabled ? Theme.primary : Theme.dim,
            rows: [["days", Timers.daysText(a.days)], ["next", a.enabled ? Timers.whenText(a.next) : "off"]],
            keys: "enter on / off · shift+enter delete"
        }));
    }

    function alarmRows(rest) {
        if (rest === "") {
            const list = alarmList();
            return list.length > 0 ? list : [info("no alarms yet", "a laundry 10:00 m-f · a gym 7:30 m,w,f · a call 18:00 tu,th", "alarm")];
        }
        const parsed = parseAlarm(rest);
        if (parsed.error)
            return [info(parsed.error, "days: m tu w th f sa su, ranges m-f, lists m,w,f, daily, weekdays, weekend", "alarm")].concat(alarmList());
        const next = Timers.nextOccurrence(parsed.hour, parsed.minute, parsed.days, Date.now());
        return [{
            kind: "alarm-new", parsed,
            title: `alarm ${Timers.clock(parsed.hour, parsed.minute)}${parsed.label !== "" ? ` · ${parsed.label}` : ""}`,
            desc: `${Timers.daysText(parsed.days)} · first ${Timers.whenText(next)}`,
            category: "alarm", symbol: "alarm_add", tint: Theme.primary,
            rows: [["time", Timers.clock(parsed.hour, parsed.minute)], ["days", Timers.daysText(parsed.days)], ["label", parsed.label || "–"],
                ["snooze", `${Config.snoozeMinutes} min`]],
            keys: "enter set the alarm"
        }].concat(alarmList());
    }

    // ── # emoji ──────────────────────────────────────────────

    function emojiRows(rest) {
        if (!Emoji.available)
            return [info("no emoji list", "data/emoji.tsv is missing from the shell folder (facet update quickshell)", "mood")];
        const list = Emoji.search(rest);
        if (list.length === 0)
            return [info(rest === "" ? "type to search emoji" : "no emoji found", "# heart · # thumbs up · # cat", "mood")];
        return list.map(e => ({
            kind: "emoji", char: e.char,
            title: e.name, desc: e.group.replace(/-/g, " "),
            category: "", emoji: e.char, tint: Theme.primary,
            rows: [["emoji", e.char], ["group", e.group]],
            keys: "enter copy · shift+enter type it"
        }));
    }

    // ── / files ──────────────────────────────────────────────

    function fileSymbol(name, isDir) {
        if (isDir)
            return "folder";
        const ext = name.includes(".") ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : "";
        const groups = [
            [["png", "jpg", "jpeg", "webp", "gif", "svg", "avif"], "image"],
            [["mp4", "mkv", "webm", "mov", "avi"], "movie"],
            [["mp3", "flac", "ogg", "opus", "wav", "m4a"], "audio_file"],
            [["pdf"], "picture_as_pdf"],
            [["zip", "tar", "gz", "xz", "zst", "7z", "rar"], "folder_zip"],
            [["sh", "fish", "py", "js", "ts", "qml", "lua", "rs", "go", "c", "cpp"], "code"]
        ];
        for (const [exts, symbol] of groups)
            if (exts.includes(ext))
                return symbol;
        return "description";
    }

    function fileRows(rest) {
        if (rest === "")
            return [info("type a file or folder name", "/ notes · / dev notes (only under a path with dev)", "folder")];
        if (Files.query !== rest || (Files.searching && Files.results.length === 0))
            return [info("searching …", "", "progress_activity")];
        if (Files.results.length === 0)
            return [info("nothing found", "hidden and git-ignored files are skipped", "search_off")];
        return Files.results.map(f => {
            const ext = f.isDir || !f.name.includes(".") ? "" : f.name.slice(f.name.lastIndexOf(".") + 1).toLowerCase();
            // Pictures show themselves, text files their first lines (in the preview pane)
            const picture = ["png", "jpg", "jpeg", "webp", "gif", "svg", "avif", "bmp"].includes(ext);
            const text = !f.isDir && (ext === "" || ["txt", "md", "json", "toml", "yaml", "yml", "conf", "ini", "cfg", "log", "csv",
                "sh", "fish", "py", "js", "ts", "qml", "lua", "rs", "go", "c", "h", "cpp", "css", "html", "xml", "nix", "env"].includes(ext));
            // Videos and PDFs get a thumbnail made when selected (ffmpegthumbnailer, pdftoppm)
            const video = ["mp4", "mkv", "webm", "mov", "avi", "m4v"].includes(ext);
            const pdf = ext === "pdf";
            return {
                kind: "file", file: f,
                title: f.name, desc: Files.pretty(f.dir),
                category: f.isDir ? "folder" : ext || "file", symbol: fileSymbol(f.name, f.isDir), tint: Theme.secondary,
                image: picture ? f.path : "",
                preview: picture ? f.path : "",
                textPreview: text ? f.path : "",
                thumbSource: video ? f.path : "", pdfSource: pdf ? f.path : "",
                rows: [["path", Files.pretty(f.path)]],
                keys: "enter open · shift+enter terminal here"
            };
        });
    }

    // ── ssh ──────────────────────────────────────────────────

    function sshRows(rest) {
        const found = SshHosts.hosts
            .map(h => ({ h, match: rest === "" ? { score: 0, idx: [] } : Apps.fuzzy(h.name, rest) }))
            .filter(x => x.match)
            .sort((a, b) => b.match.score - a.match.score)
            .map(({ h, match }) => ({
                kind: "ssh", host: h.name,
                title: h.name, markup: markup(h.name, match.idx),
                desc: [h.user !== "" ? `${h.user}@` : "", h.hostname || h.name, h.port !== "" ? `:${h.port}` : ""].join(""),
                category: "ssh", symbol: "dns", tint: Theme.ok,
                rows: [["host", h.hostname || h.name], ["user", h.user || "–"], ["port", h.port || "22"]],
                keys: "enter connect in ghostty · shift+enter copy command"
            }));
        if (rest !== "" && !SshHosts.hosts.some(h => h.name === rest))
            found.push({
                kind: "ssh", host: rest, title: `ssh ${rest}`, desc: "not in ~/.ssh/config",
                category: "ssh", symbol: "dns", tint: Theme.dim, rows: [["runs", `ssh ${rest}`]],
                keys: "enter connect in ghostty · shift+enter copy command"
            });
        return found.length > 0 ? found : [info("no hosts in ~/.ssh/config", "type user@host to connect anyway", "dns")];
    }

    // ── ; clipboard ──────────────────────────────────────────

    function clipRows(rest) {
        if (!Clipboard.loaded)
            return [info("reading clipboard history …", "from frame-clip", "content_paste")];
        const q = rest.toLowerCase();
        const list = Clipboard.entries.filter(e => q === "" || e.text.toLowerCase().includes(q)).slice(0, 60);
        if (list.length === 0)
            return [info(Clipboard.entries.length === 0 ? "clipboard history is empty" : "no match", "", "content_paste_off")];
        return list.map(e => {
            const lines = e.text.split("\n");
            return {
                kind: "clip", entry: e,
                title: e.image ? `image · ${e.text}` : lines[0].trim() || "(blank)",
                desc: e.image ? "picture" : lines.length > 1 ? `${lines.length} lines` : `${e.text.length} characters`,
                category: e.image ? "image" : "text", symbol: e.image ? "image" : "notes", tint: Theme.secondary,
                image: e.preview ?? "",
                body: e.image ? "" : e.text.slice(0, 700),
                preview: e.preview ?? "",
                rows: [],
                keys: "enter copy · shift+enter delete from history"
            };
        });
    }

    // ── ? web ────────────────────────────────────────────────

    function webRow(key, text) {
        const [name, template] = Config.searchEngines[key];
        const url = template.replace("%s", encodeURIComponent(text));
        return {
            kind: "web", url,
            title: `${name}: ${text}`, desc: url,
            category: key, symbol: "travel_explore", tint: key === Config.searchDefault ? Theme.primary : Theme.dim,
            rows: [["engine", name], ["shortcut", `? ${key} …`]],
            keys: "enter open in the browser"
        };
    }

    function webRows(rest) {
        const keys = Object.keys(Config.searchEngines);
        const words = rest.split(/\s+/);
        if (rest === "" || (words.length === 1 && keys.includes(words[0])))
            return keys.map(k => ({
                kind: "web-engine", key: k,
                title: Config.searchEngines[k][0], desc: k === Config.searchDefault ? `? ${k} · used without a shortcut` : `? ${k}`,
                category: k, symbol: "search", tint: k === Config.searchDefault ? Theme.primary : Theme.dim, rows: [],
                keys: "enter pick this engine"
            })).sort((a, b) => (b.key === words[0]) - (a.key === words[0]));
        if (keys.includes(words[0]))
            return [webRow(words[0], words.slice(1).join(" "))];
        const fallback = keys.includes(Config.searchDefault) ? Config.searchDefault : keys[0];
        return [webRow(fallback, rest)].concat(keys.filter(k => k !== fallback).map(k => webRow(k, rest)));
    }

    // ── wall: wallpapers ─────────────────────────────────────

    // still: pictures; moving: scenes, videos, web; folder: your own files
    function wallKind(w) {
        return w.kind === "image" ? "still" : "moving";
    }

    function wallFilter(items, tab, word) {
        const q = (word ?? "").trim().toLowerCase();
        return items.filter(w => {
            if (tab === "still" && w.kind !== "image")
                return false;
            if (tab === "moving" && w.kind === "image")
                return false;
            if (tab === "folder" && w.source !== "file")
                return false;
            return q === "" || `${w.title} ${(w.tags ?? []).join(" ")}`.toLowerCase().includes(q);
        });
    }

    // The picture a tile shows: the engine's preview, or the file itself for a still one
    function wallPicture(w) {
        if (!w)
            return "";
        return fileUrl(w.preview || (w.kind === "image" ? w.path : ""));
    }

    // ── Enter ────────────────────────────────────────────────

    // Returns what the launcher should do next: { close }, { arm: name } or { query: text }
    function activate(r, shift, armed) {
        const close = { close: true }, stay = { close: false };
        switch (r.kind) {
        case "app":
            // A running app comes to the current view; shift starts another
            Apps.launch(r.entry, shift);
            return close;
        case "calc":
            if (r.value === null)
                return stay;
            copy(r.value);
            return close;
        case "command":
            if (r.query !== null)
                return { close: false, query: r.query };
            run(r.command);
            return close;
        case "run":
            if (r.command === "")
                return stay;
            run(["ghostty", "-e", "fish", "-c", `${r.command}; exec fish`]);
            return close;
        case "power":
            if (r.name !== "lock" && armed !== r.name)
                return { close: false, arm: r.name };
            run(r.command);
            return close;
        case "spotify-control":
            Spotify.control(r.action, r.seconds);
            return close;
        case "spotify-item":
            Spotify.play(r.item.uri, shift && r.item.kind === "track");
            return close;
        case "discord-open":
            // Groups have no user, the channel is what gets opened or called
            DiscordBridge.send({ cmd: shift ? "call_user" : "open_dm", userId: r.contact.userId, channelId: r.contact.channelId });
            DiscordBridge.focusWindow();
            return close;
        case "discord-call":
            DiscordBridge.send({ cmd: "call_user", userId: r.contact.userId, channelId: r.contact.channelId });
            DiscordBridge.focusWindow();
            return close;
        case "discord-send":
            if (r.content === "")
                return stay;
            DiscordBridge.send({ cmd: "send_dm", userId: r.contact.userId, content: r.content, channelId: r.contact.channelId });
            return close;
        case "discord-reply":
            if (r.content === "")
                return stay;
            DiscordBridge.send({ cmd: "reply_last", content: r.content });
            return close;
        case "timer-start":
            Timers.addTimer(r.seconds, r.label);
            return close;
        case "timer-running":
            Timers.cancelTimer(r.timer.id);
            return stay;
        case "alarm-new":
            Timers.addAlarm(r.parsed.hour, r.parsed.minute, r.parsed.days, r.parsed.label);
            return close;
        case "alarm":
            if (shift)
                Timers.removeAlarm(r.alarm.id);
            else
                Timers.toggleAlarm(r.alarm.id);
            return stay;
        case "emoji":
            Emoji.used(r.char);
            if (shift)
                // Pasted into the window that gets focus back once the launcher is gone: into
                // the clipboard, then Hyprland presses Ctrl+V there (Ctrl+Shift+V in terminals)
                run(["sh", "-c", 'printf "%s" "$0" | wl-copy; sleep 0.25; '
                    + 'case "$(hyprctl activewindow | sed -n "s/^[[:space:]]*class: //p")" in '
                    + '*ghostty*|*kitty*|*foot*|*Alacritty*|*wezterm*|*konsole*) mods="CTRL SHIFT" ;; *) mods="CTRL" ;; esac; '
                    + 'hyprctl dispatch "hl.dsp.exec_raw(\\"sendshortcut\\", \\"$mods, V, activewindow\\")"', r.char]);
            else
                copy(r.char);
            return close;
        case "file":
            if (shift)
                run(["ghostty", `--working-directory=${r.file.isDir ? r.file.path : r.file.dir}`]);
            else
                run(["xdg-open", r.file.path]);
            return close;
        case "ssh":
            if (shift)
                copy(`ssh ${r.host}`);
            else
                run(["ghostty", "-e", "ssh", r.host]);
            return close;
        case "clip":
            if (shift) {
                Clipboard.remove(r.entry);
                return stay;
            }
            Clipboard.copy(r.entry);
            return close;
        case "web":
            run(["xdg-open", r.url]);
            return close;
        case "web-engine":
            return { close: false, query: `? ${r.key} ` };
        default:
            return stay;
        }
    }

    // ── Side effects of typing ───────────────────────────────

    // A new mode was picked: fetch what it lists
    function modeEntered(mode) {
        if (mode === "s")
            Spotify.refresh();
        else if (mode === "d")
            DiscordBridge.refreshContacts();
        else if (mode === ";")
            Clipboard.refresh();
        else if (mode === "wall")
            Wallpapers.refresh();
    }

    // The query changed inside a mode that searches in the background
    function queryChanged(mode, rest) {
        if (mode === "s")
            Spotify.search(spotifySearchText(rest));
        else if (mode === "/")
            Files.search(rest);
    }
}
