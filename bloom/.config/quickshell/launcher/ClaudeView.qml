import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

// Claude in the launcher (c): before the first question a hint with suggestions; then the
// question as a bubble on the right and the answer under it, written in as it comes
// (paragraphs, headings, list items, code blocks with their own copy), and at the end copy,
// ask more and open in a terminal. The answer stays until the next question goes out.
// The Claude service answers in one piece (claude -p), so the writing-in is done here.
Item {
    id: root

    property real maxHeight: 420
    property string copied: ""

    readonly property bool asked: Claude.question !== ""
    readonly property bool failed: !Claude.busy && Claude.error !== ""
    readonly property bool answered: !Claude.busy && Claude.answer !== ""
    readonly property bool writing: reveal.running
    readonly property bool done: answered && !writing
    // [{ kind: "p" | "h" | "item" | "code", src, lang, start }], start counts the characters
    // of the blocks before, so `revealed` can show the answer block by block
    readonly property var blocks: parseAnswer(Claude.answer)
    readonly property int total: blocks.length > 0 ? blocks[blocks.length - 1].start + blocks[blocks.length - 1].src.length : 0
    property real revealed: 0
    property int thinkSeconds: 0

    signal suggested(string text)
    signal askMore()

    implicitHeight: Math.min(maxHeight, flick.contentHeight)

    Component.onCompleted: revealed = total

    // ── Markdown, the bits Claude answers with ───────────────

    // `code` and **bold** inside a line
    function inlineHtml(line) {
        const esc = line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return esc
            .replace(/\x60([^\x60]+)\x60/g, `<span style="color:${Theme.secondary};font-family:'${Theme.mono}'">$1</span>`)
            .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
    }

    function parseAnswer(md) {
        const out = [];
        const lines = md.split("\n");
        let i = 0, at = 0;
        const push = (kind, src, lang) => {
            out.push({ kind, src, lang: lang ?? "", start: at });
            at += src.length;
        };
        while (i < lines.length) {
            const line = lines[i];
            if (/^\s*\x60{3}/.test(line)) {
                const lang = line.trim().slice(3).trim();
                const code = [];
                i++;
                while (i < lines.length && !/^\s*\x60{3}/.test(lines[i]))
                    code.push(lines[i++]);
                i++;
                push("code", code.join("\n"), lang || "text");
            } else if (/^#{1,6}\s/.test(line)) {
                push("h", line.replace(/^#+\s*/, ""));
                i++;
            } else if (/^\s*([-*]|\d+\.)\s/.test(line)) {
                push("item", line.replace(/^\s*([-*]|\d+\.)\s+/, ""));
                i++;
            } else if (line.trim() === "") {
                i++;
            } else {
                const para = [];
                while (i < lines.length && lines[i].trim() !== "" && !/^\s*(\x60{3}|[-*]\s|\d+\.\s|#{1,6}\s)/.test(lines[i]))
                    para.push(lines[i++].trim());
                push("p", para.join(" "));
            }
        }
        return out;
    }

    // ── Copy and scroll ──────────────────────────────────────

    // The selected part of the answer (one block at a time), else all of it
    function copy(all) {
        let part = "";
        if (!all)
            for (let i = 0; i < blockRepeater.count && part === ""; i++)
                part = blockRepeater.itemAt(i)?.selection() ?? "";
        Quickshell.execDetached(["wl-copy", "--", part !== "" ? part : Claude.answer]);
        copied = part !== "" ? "copied the selection" : "copied";
        copiedTimer.restart();
    }

    function copyCode(text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
        copied = "copied the code";
        copiedTimer.restart();
    }

    // true when there was a selection to clear (Esc clears it before it closes)
    function deselect() {
        let had = false;
        for (let i = 0; i < blockRepeater.count; i++)
            had = (blockRepeater.itemAt(i)?.deselect() ?? false) || had;
        return had;
    }

    function scroll(by) {
        flick.contentY = Math.max(0, Math.min(flick.contentY + by, flick.contentHeight - flick.height));
    }

    // Goes on with this conversation in Claude Code: the CLI keeps -p sessions per folder
    // and the service asks from its own one
    function openTerminal() {
        const model = Config.claudeModel !== "" ? ["--model", Config.claudeModel] : [];
        Quickshell.execDetached(["ghostty", "-e", "sh", "-c",
            Claude.withPath + 'mkdir -p "$0" && cd "$0" && exec claude --continue "$@"', Claude.workDir].concat(model));
    }

    Timer {
        id: copiedTimer

        interval: 2200
        onTriggered: root.copied = ""
    }

    Timer {
        running: Claude.busy
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.thinkSeconds = Math.floor((Date.now() - Claude.askedAt) / 1000)
    }

    // The answer is written in from the first character, faster for short ones
    Anim {
        id: reveal

        target: root
        property: "revealed"
        from: 0
        to: root.total
        duration: Theme.anim.slow * Math.min(3, Math.max(0.6, root.total / 350))
        easing.bezierCurve: Theme.curve.standard
    }

    Connections {
        target: Claude

        function onAnswerChanged() {
            root.copied = "";
            if (Claude.answer === "") {
                reveal.stop();
                root.revealed = 0;
            } else {
                reveal.restart();
            }
        }
        function onQuestionChanged() {
            flick.contentY = 0;
        }
    }

    // ── Layout ───────────────────────────────────────────────

    // Wheel and keys scroll; a press and drag selects text instead of flicking
    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // Follows the end while the answer is written in
        onContentHeightChanged: {
            if (Claude.busy || root.writing)
                contentY = Math.max(0, contentHeight - height);
        }

        ColumnLayout {
            id: column

            width: flick.width
            spacing: 10

            // Before the first question
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.asked
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: "Ask anything · Enter sends · the answer stays until you ask the next one"
                    dim: true
                    font.pixelSize: Theme.size.small
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: ["how do I free disk space on CachyOS?", "why does my GoXLR mic crackle?",
                            "a fish function that opens the last screenshot"]

                        Chip {
                            required property string modelData

                            text: modelData
                            onClicked: root.suggested(modelData)
                        }
                    }
                }
            }

            // The question
            Item {
                id: questionRow

                Layout.fillWidth: true
                visible: root.asked
                implicitHeight: bubble.height

                Rectangle {
                    id: bubble

                    anchors.right: parent.right
                    width: Math.min(questionText.implicitWidth, questionRow.width * 0.8 - 28) + 28
                    height: questionText.height + 16
                    radius: Theme.rounding.large
                    bottomRightRadius: Theme.rounding.small / 2
                    color: Theme.primaryContainer

                    StyledText {
                        id: questionText

                        x: 14
                        y: 8
                        width: parent.width - 28
                        text: Claude.question
                        color: Theme.textOnPrimaryContainer
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }

            // The answer: who answers, and the bubble
            RowLayout {
                Layout.fillWidth: true
                visible: root.asked
                spacing: 12

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: Theme.rounding.normal
                    color: Theme.mix(Theme.container, Theme.tertiary, 0.25)

                    Icon {
                        id: who

                        anchors.centerIn: parent
                        icon: Claude.busy ? "progress_activity" : root.failed ? "error" : "auto_awesome"
                        size: Theme.icon.small + 1
                        color: root.failed ? Theme.error : Theme.tertiary

                        RotationAnimator on rotation {
                            running: Claude.busy && Theme.animated
                            from: 0
                            to: 360
                            duration: Theme.anim.slow * 1.6
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) who.rotation = 0
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: answerColumn.implicitHeight + 20
                    radius: Theme.rounding.large
                    bottomLeftRadius: Theme.rounding.small / 2
                    color: Theme.container

                    ColumnLayout {
                        id: answerColumn

                        x: 14
                        y: 10
                        width: parent.width - 28
                        spacing: 8

                        // While Claude thinks (the service answers in one piece)
                        RowLayout {
                            visible: Claude.busy
                            spacing: 8

                            StyledText {
                                text: `${Config.claudeModel || "claude"} is thinking · ${root.thinkSeconds} s`
                                dim: true
                                font.pixelSize: Theme.size.small
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.failed
                            text: Claude.error
                            color: Theme.error
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            font.pixelSize: Theme.size.small
                        }

                        Repeater {
                            id: blockRepeater

                            model: Claude.busy ? [] : root.blocks

                            delegate: Item {
                                id: block

                                required property var modelData
                                readonly property bool isCode: modelData.kind === "code"
                                // How much of this block is written in so far
                                readonly property int shown: Math.max(0, Math.min(modelData.src.length, Math.floor(root.revealed - modelData.start)))
                                readonly property string part: modelData.src.slice(0, shown)

                                function selection() {
                                    return isCode ? codeText.selectedText : prose.selectedText;
                                }

                                function deselect() {
                                    const had = selection() !== "";
                                    codeText.deselect();
                                    prose.deselect();
                                    return had;
                                }

                                Layout.fillWidth: true
                                visible: shown > 0
                                implicitHeight: isCode ? codeBox.height : prose.height

                                // List items get a dot in front
                                Rectangle {
                                    visible: block.modelData.kind === "item"
                                    x: 4
                                    y: 9
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.tertiary
                                }

                                TextEdit {
                                    id: prose

                                    visible: !block.isCode
                                    x: block.modelData.kind === "item" ? 18 : 0
                                    width: parent.width - x
                                    text: block.isCode ? "" : root.inlineHtml(block.part)
                                    textFormat: TextEdit.RichText
                                    readOnly: true
                                    selectByMouse: true
                                    // The field keeps the keyboard, so typing still edits the question
                                    activeFocusOnPress: false
                                    persistentSelection: true
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.text
                                    selectionColor: Theme.primaryContainer
                                    selectedTextColor: Theme.textOnPrimaryContainer
                                    font.family: Theme.font
                                    font.pixelSize: block.modelData.kind === "h" ? Theme.size.medium : Theme.size.normal
                                    font.weight: block.modelData.kind === "h" ? Font.Medium : Font.Normal

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.IBeamCursor
                                    }
                                }

                                // Code: its own box with the language and a copy of just this
                                Rectangle {
                                    id: codeBox

                                    visible: block.isCode
                                    width: parent.width
                                    height: block.isCode ? Math.max(codeText.height + 20, 40) : 0
                                    radius: Theme.rounding.normal
                                    color: Theme.high

                                    TextEdit {
                                        id: codeText

                                        x: 12
                                        y: 10
                                        width: parent.width - 24 - codeTools.width
                                        text: block.isCode ? block.part : ""
                                        textFormat: TextEdit.PlainText
                                        readOnly: true
                                        selectByMouse: true
                                        activeFocusOnPress: false
                                        persistentSelection: true
                                        wrapMode: TextEdit.WrapAnywhere
                                        color: Theme.secondary
                                        selectionColor: Theme.primaryContainer
                                        selectedTextColor: Theme.textOnPrimaryContainer
                                        font.family: Theme.mono
                                        font.pixelSize: Theme.size.small

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            cursorShape: Qt.IBeamCursor
                                        }
                                    }

                                    Row {
                                        id: codeTools

                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 4
                                        spacing: 2

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: block.modelData.lang
                                            dim: true
                                            font.pixelSize: Theme.size.tiny
                                        }
                                        IconButton {
                                            size: 30
                                            iconSize: Theme.icon.small - 2
                                            icon: "content_copy"
                                            onClicked: root.copyCode(block.modelData.src)
                                        }
                                    }
                                }
                            }
                        }

                        // The cursor while it is written (and while it thinks)
                        Rectangle {
                            id: cursor

                            visible: Claude.busy || root.writing
                            implicitWidth: 8
                            implicitHeight: 16
                            radius: 2
                            color: Theme.primary

                            SequentialAnimation on opacity {
                                running: cursor.visible && Theme.animated
                                loops: Animation.Infinite
                                Anim {
                                    to: 0.2
                                    duration: Theme.anim.medium
                                }
                                Anim {
                                    to: 1
                                    duration: Theme.anim.medium
                                }
                            }
                        }
                    }
                }
            }

            // When it is written in: copy, ask more, open in a terminal
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 46
                visible: root.asked && (root.done || root.failed)
                spacing: 6
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }

                Button {
                    visible: root.done
                    icon: root.copied !== "" ? "check" : "content_copy"
                    text: root.copied !== "" ? root.copied : "copy"
                    done: root.copied !== ""
                    onClicked: root.copy(false)
                }
                Button {
                    visible: root.failed
                    icon: "refresh"
                    text: "try again"
                    onClicked: Claude.ask(Claude.question)
                }
                Button {
                    icon: "reply"
                    text: "ask more"
                    onClicked: root.askMore()
                }
                Button {
                    visible: root.done
                    icon: "terminal"
                    text: "open in a terminal"
                    onClicked: root.openTerminal()
                }
            }
        }
    }

    WheelHandler {
        target: null
        onWheel: event => root.scroll(-event.angleDelta.y)
    }

    // Where it is, only when the answer is longer than the box
    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        x: parent.width - width + 6
        y: (parent.height - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
        width: 3
        height: Math.max(30, parent.height * flick.height / Math.max(1, flick.contentHeight))
        radius: width / 2
        color: Theme.outline
    }
}
