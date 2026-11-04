import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The launcher: a drawer out of the bottom edge (Super+Space, the bar's search button).
// A round search field with the mode chip and the results as rounded rows under it; tab or
// a letter and a space switches the mode. tui's modes all work (Modes.qml has them); Claude (c)
// answers in its own view, "wall" widens the drawer into the big wallpaper menu and
// "wall <word>" shows a quick row. Files and the clipboard get a preview beside the list.
// In a game with "compact in a game" on it opens smaller (Bloom.compact("panels")).
//
// Keep: open, show(preset), hide(), toggle(screen), the IPC target "launcher" and the layer
// name "qs-launcher" (hypr/frame/shell.lua looks for it to send Ctrl+Alt+Q's @ here
// through `type`).
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null
    property int current: 0
    // Power action waiting for its second Enter
    property string armed: ""
    // The rows built while this is on come in staggered; generation rebuilds them
    property bool stagger: false
    property int generation: 0

    readonly property string query: field.text
    readonly property var parsed: modes.parse(query)
    readonly property string mode: parsed.mode
    readonly property string rest: parsed.rest
    readonly property bool claudeMode: mode === "c"
    readonly property bool wallBig: mode === "wall" && parsed.big
    readonly property bool wallQuick: mode === "wall" && !parsed.big
    readonly property bool listMode: !claudeMode && mode !== "wall"
    readonly property var results: listMode ? orNothing(modes.compute(mode, rest)) : []
    readonly property var selected: results.length > 0 ? results[Math.min(current, results.length - 1)] : null

    // In a game: smaller, fewer rows and no preview
    readonly property bool compact: Bloom.compact("panels")
    readonly property real factor: Bloom.scale("panels")
    readonly property real wallFactor: factor * (compact ? 0.85 : 1)
    readonly property int rows: compact ? 4 : 6
    // Files and the clipboard show the picked one beside the list
    readonly property bool previewing: listMode && (mode === "/" || mode === ";") && !compact
    // The drawer's content; the mockup's 720 and 1180 with the drawer's padding around it
    readonly property real panelWidth: wallBig ? 1144 * wallFactor : (previewing ? 1004 : compact ? 560 : 684) * factor

    readonly property string hint: armed !== "" ? `press enter again to ${armed}`
        : wallBig ? "←→↑↓ pick · enter apply · shift+enter only this screen · tab next tab"
        : wallQuick ? "←→ pick · enter apply · shift+enter only this screen"
        : claudeMode ? (claudeView.done && rest === Claude.question ? "enter copy & close · ctrl+c copy · ↑↓ scroll"
            : Claude.busy ? "esc close · the answer waits here" : "enter ask · ↑↓ scroll")
        : selected?.keys ?? "↑↓ select · enter open · tab mode · esc close"

    // preset: text to start with, e.g. "; " for the clipboard history
    function show(preset, screen) {
        if (!open) {
            root.screen = screen ?? Bloom.focusedScreen;
            // Fresh window list, so Enter on a running app finds its window (Apps.windowOf)
            Hyprland.refreshToplevels();
            field.text = "";
            current = 0;
            armed = "";
            open = true;
            restagger();
        }
        if (preset)
            setQuery(preset);
        field.focusField();
        // Again once the window has the keyboard
        Qt.callLater(field.focusField);
    }

    function hide() {
        open = false;
    }

    function toggle(screen) {
        if (open)
            hide();
        else
            show("", screen);
    }

    function setQuery(text) {
        field.text = text;
        field.input.cursorPosition = text.length;
    }

    // Types text at the cursor, over a selection (Ctrl+Alt+Q → @, frame/shell.lua)
    function type(text) {
        const input = field.input;
        if (input.selectedText !== "")
            input.remove(input.selectionStart, input.selectionEnd);
        input.insert(input.cursorPosition, text);
    }

    // An empty list still says something
    function orNothing(rows) {
        return rows.length > 0 ? rows : [modes.info("nothing found", "try another word · tab switches the mode", "search_off")];
    }

    function restagger() {
        stagger = true;
        generation += 1;
        Qt.callLater(() => root.stagger = false);
    }

    function move(step) {
        const count = results.length;
        if (count > 0)
            current = (current + step + count) % count;
        armed = "";
    }

    // Tab keeps the text, so a new mode also searches what is already typed
    function cycleMode(step) {
        const order = modes.order;
        const next = order[(order.indexOf(mode) + step + order.length) % order.length];
        setQuery(modes.prefix(next, rest) + rest);
    }

    function activate(shift) {
        if (!selected)
            return;
        const next = modes.activate(selected, shift, armed);
        armed = next.arm ?? "";
        if (next.query !== undefined)
            setQuery(next.query);
        if (next.close)
            hide();
    }

    // Enter in c: ask what is typed; on the question just answered, copy the answer and close
    function claudeEnter() {
        if (rest === "")
            return;
        if (rest === Claude.question && claudeView.done) {
            modes.copy(Claude.answer);
            hide();
            return;
        }
        Claude.ask(rest);
    }

    // Every key of the field comes here first; accepted ones never reach the text
    function key(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
        let handled = true;
        if (event.key === Qt.Key_Escape) {
            // A selection in Claude's answer goes first
            if (!(claudeMode && claudeView.deselect()))
                hide();
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const step = event.key === Qt.Key_Backtab ? -1 : 1;
            if (wallBig)
                wallMenu.nextTab(step);
            else
                cycleMode(step);
        } else if (wallBig) {
            if (event.key === Qt.Key_Left)
                wallMenu.move(-1);
            else if (event.key === Qt.Key_Right)
                wallMenu.move(1);
            else if (event.key === Qt.Key_Up)
                wallMenu.move(-wallMenu.columns);
            else if (event.key === Qt.Key_Down)
                wallMenu.move(wallMenu.columns);
            else if (enter)
                wallMenu.apply(shift);
            else
                handled = false;
        } else if (wallQuick) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                wallRow.move(-1);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                wallRow.move(1);
            else if (enter)
                wallRow.apply(shift);
            else
                handled = false;
        } else if (claudeMode) {
            // The field's own selection still wins, so editing the question stays normal
            if (ctrl && event.key === Qt.Key_C && field.input.selectedText === "" && Claude.answer !== "")
                claudeView.copy(false);
            else if (event.key === Qt.Key_Down)
                claudeView.scroll(60);
            else if (event.key === Qt.Key_Up)
                claudeView.scroll(-60);
            else if (event.key === Qt.Key_PageDown)
                claudeView.scroll(claudeView.height - 60);
            else if (event.key === Qt.Key_PageUp)
                claudeView.scroll(60 - claudeView.height);
            else if (enter)
                claudeEnter();
            else
                handled = false;
        } else {
            if (event.key === Qt.Key_Down)
                move(1);
            else if (event.key === Qt.Key_Up)
                move(-1);
            else if (enter)
                activate(shift);
            else
                handled = false;
        }
        if (handled)
            event.accepted = true;
    }

    onQueryChanged: {
        current = 0;
        armed = "";
    }
    onModeChanged: {
        modes.modeEntered(mode);
        modes.queryChanged(mode, rest);
        restagger();
    }
    onRestChanged: modes.queryChanged(mode, rest)
    onWallBigChanged: {
        if (wallBig)
            wallMenu.reset();
    }
    // A list that got shorter (a timer stopped, an entry deleted) keeps a valid selection
    onResultsChanged: {
        if (current >= results.length)
            current = Math.max(0, results.length - 1);
    }

    Modes {
        id: modes
    }

    Drawer {
        screen: root.screen
        edge: "bottom"
        open: root.open
        namespace: "qs-launcher"
        // Super+Space works over a fullscreen window too, like tui's launcher
        windowLayer: WlrLayer.Overlay
        keyboard: WlrKeyboardFocus.Exclusive
        onDismissed: root.hide()

        FocusScope {
            anchors.fill: parent
            focus: true
            implicitWidth: root.panelWidth
            implicitHeight: column.implicitHeight

            ColumnLayout {
                id: column

                width: parent.width
                spacing: Theme.spacing.medium

                QueryField {
                    id: field

                    Layout.fillWidth: true
                    placeholder: "Search apps · > for commands · wall for wallpapers"
                    icon: modes.icons[root.mode] ?? "search"
                    mode: root.claudeMode ? `Claude · ${Config.claudeModel || "default"}` : modes.names[root.mode] ?? "apps"
                    modeIcon: root.claudeMode ? "auto_awesome" : ""
                    onKeyPressed: event => root.key(event)
                }

                // ── wall: the big menu ───────────────────────

                WallMenu {
                    id: wallMenu

                    Layout.fillWidth: true
                    visible: root.wallBig
                    modes: modes
                    screenName: root.screen?.name ?? ""
                    factor: root.wallFactor
                }

                // ── wall <word>: the quick row ───────────────

                WallRow {
                    id: wallRow

                    Layout.fillWidth: true
                    visible: root.wallQuick
                    modes: modes
                    word: root.wallQuick ? root.rest : ""
                    screenName: root.screen?.name ?? ""
                    factor: root.factor
                }

                // ── c: Claude ────────────────────────────────

                ClaudeView {
                    id: claudeView

                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: root.claudeMode
                    maxHeight: (root.compact ? 300 : 420) * root.factor
                    onSuggested: text => {
                        root.setQuery(`c ${text}`);
                        Claude.ask(text);
                    }
                    onAskMore: {
                        root.setQuery("c ");
                        field.focusField();
                    }
                }

                // ── Everything else: the rows ────────────────

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.listMode
                    spacing: Theme.spacing.medium

                    ResultList {
                        id: list

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: implicitHeight
                        results: root.results
                        current: root.current
                        rows: root.rows
                        stagger: root.stagger
                        generation: root.generation
                        onHoveredRow: position => root.current = position
                        onClickedRow: (position, mouse) => {
                            root.current = position;
                            root.activate((mouse.modifiers & Qt.ShiftModifier) !== 0);
                        }
                    }

                    PreviewPane {
                        Layout.preferredWidth: 320 * root.factor
                        Layout.preferredHeight: Math.max(list.implicitHeight, 280 * root.factor)
                        Layout.alignment: Qt.AlignTop
                        visible: root.previewing
                        selected: root.selected
                    }
                }

                // ── Where you are and what the keys do ───────

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    visible: !root.compact
                    spacing: Theme.spacing.medium

                    StyledText {
                        text: root.listMode && root.results.length > root.rows ? `${root.current + 1} / ${root.results.length}`
                            : root.query === "" ? "tab switches the mode" : ""
                        dim: true
                        tabular: true
                        font.pixelSize: Theme.size.tiny
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    StyledText {
                        Layout.maximumWidth: root.panelWidth * 0.75
                        text: root.hint
                        color: root.armed !== "" ? Theme.warn : Theme.dim
                        font.pixelSize: Theme.size.tiny
                        elide: Text.ElideLeft
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show("");
        }

        // Super+V: the clipboard history (frame-clip), like Windows
        function clipboard(): void {
            root.show("; ");
        }

        // Opens with text already typed, e.g. `qs ipc call launcher search "/ notes"`
        function search(text: string): void {
            root.show(text);
        }

        // Opens with that text typed, e.g. `qs ipc call launcher mode "s daft punk"`
        function mode(text: string): void {
            root.show(text);
        }

        // Types into the open launcher; Ctrl+Alt+Q (frame/shell.lua) sends its @ here, the
        // launcher is no window that sendshortcut could reach
        function type(text: string): void {
            if (root.open)
                root.type(text);
        }

        function close(): void {
            root.hide();
        }
    }
}
