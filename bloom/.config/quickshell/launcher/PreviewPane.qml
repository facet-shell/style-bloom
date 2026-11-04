import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config

// Beside the results in the file search (/) and the clipboard (;): the selected row's
// picture, a video's or PDF's thumbnail, a text file's first lines, a clipboard text, and
// its details. tui's info pane in a card.
Rectangle {
    id: root

    property var selected: null

    readonly property string picture: (selected?.preview ?? "") !== "" ? selected.preview : thumbPeek.ready

    function fileUrl(path) {
        const p = String(path ?? "");
        if (p === "" || p.includes("://"))
            return p;
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    radius: Theme.rounding.large
    color: Theme.container
    clip: true

    Behavior on color {
        ColorAnim {}
    }

    // The first lines of a text file, read when it is selected. A process that is still
    // running ignores running = true, so a quick ↓ would leave the next file without a preview
    // and show the last one's text: each run remembers its file, late output is dropped and
    // the current one follows
    Process {
        id: textPeek

        property string path: root.selected?.textPreview ?? ""
        property string startedFor: ""
        property string snippet: ""

        function start() {
            if (path === "" || running)
                return;
            startedFor = path;
            command = ["head", "-c", "3000", path];
            running = true;
        }

        onPathChanged: {
            snippet = "";
            start();
        }
        onExited: Qt.callLater(() => {
            if (textPeek.startedFor !== textPeek.path)
                textPeek.start();
        })
        stdout: StdioCollector {
            onStreamFinished: {
                if (textPeek.startedFor === textPeek.path)
                    textPeek.snippet = this.text.split("\n").slice(0, 28).join("\n");
            }
        }
    }

    // A thumbnail for a video or PDF, made when it is selected and kept in
    // $XDG_RUNTIME_DIR/qs-thumbs; same pattern as textPeek
    Process {
        id: thumbPeek

        property string source: (root.selected?.thumbSource || root.selected?.pdfSource) ?? ""
        property string startedFor: ""
        property string startedFile: ""
        property string ready: ""

        function start() {
            if (source === "" || running)
                return;
            // Read here, not from a binding that may still hold the last file's value
            const pdf = (root.selected?.pdfSource ?? "") === source;
            startedFor = source;
            startedFile = `${Quickshell.env("XDG_RUNTIME_DIR")}/qs-thumbs/${Qt.md5(source)}.png`;
            command = ["sh", "-c", pdf
                ? 'mkdir -p "$(dirname "$2")" && { [ -s "$2" ] || { pdftoppm -png -r 40 -f 1 -l 1 -singlefile "$1" "${2%.png}"; }; }'
                : 'mkdir -p "$(dirname "$2")" && { [ -s "$2" ] || ffmpegthumbnailer -i "$1" -o "$2" -s 640 -q 8; }',
                "thumb", source, startedFile];
            running = true;
        }

        onSourceChanged: {
            ready = "";
            start();
        }
        onExited: code => {
            if (code === 0 && startedFor === source && source !== "")
                ready = startedFile;
            else if (startedFor !== source)
                Qt.callLater(start);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding.normal
        spacing: Theme.spacing.medium
        visible: root.selected !== null && root.selected.kind !== "info"

        // A picture (a clipboard image, a file, a thumbnail): a fixed height, so the pane
        // does not jump while it loads
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            visible: root.picture !== ""
            radius: Theme.rounding.medium
            color: Theme.high

            Image {
                anchors.fill: parent
                source: root.fileUrl(root.picture)
                // Big screenshots are scaled down once on load, not on every paint
                sourceSize.width: 800
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        // A text file's first lines
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(220, snippet.implicitHeight + 20)
            visible: (root.selected?.textPreview ?? "") !== "" && textPeek.snippet !== ""
            radius: Theme.rounding.medium
            color: Theme.high
            clip: true

            Text {
                id: snippet

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                text: textPeek.snippet
                color: Theme.secondary
                font.family: Theme.mono
                font.pixelSize: Theme.size.tiny
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }

        // A clipboard text
        StyledText {
            Layout.fillWidth: true
            visible: (root.selected?.body ?? "") !== "" && root.selected?.kind === "clip"
            text: root.selected?.body ?? ""
            wrapMode: Text.Wrap
            maximumLineCount: 10
            font.pixelSize: Theme.size.small
        }

        StyledText {
            Layout.fillWidth: true
            text: root.selected?.title ?? ""
            font.weight: Font.Medium
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing.medium
            rowSpacing: Theme.spacing.small

            Repeater {
                model: (root.selected?.rows ?? []).reduce((all, row) => all.concat(row), [])

                StyledText {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: index % 2 === 1
                    text: modelData
                    dim: index % 2 === 0
                    font.pixelSize: Theme.size.small
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Nothing selected (still searching, nothing found)
    Icon {
        anchors.centerIn: parent
        visible: root.selected === null || root.selected.kind === "info"
        icon: "preview"
        size: Theme.icon.huge
        dim: true
        opacity: 0.4
    }
}
