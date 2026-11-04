import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// STUB (editor part): the editors for recordings and pictures as their own window, opened
// through the Editor service ("edit" on a notification, the media app, `qs ipc call editor
// open <file>`). In bloom: a rounded window on Theme.surface, tools as IconButtons and Chips,
// the timeline on Theme.container. tui's editor/ has both editors to port (EditorView,
// ImageEditorView, the projects, the timeline).
// Keep: open, file, openFile(path), hide() and the IPC target "editor".
Scope {
    id: root

    property bool open: false
    property string file: ""

    function openFile(path) {
        file = path;
        console.warn(`bloom: the editor is not built yet (editor/EditorWindow.qml): ${path}`);
    }

    function hide() {
        open = false;
    }

    Connections {
        target: Editor
        function onOpenRequested(file) {
            root.openFile(file);
        }
    }

    IpcHandler {
        target: "editor"

        function open(path: string): void {
            Editor.open(path);
        }

        // Paint: an empty page in the theme's background (`new` is a word JavaScript keeps)
        function paint(): void {
            Editor.newPicture("theme");
        }

        // paper: theme, white or clear
        function paintOn(paper: string): void {
            Editor.newPicture(paper);
        }

        function close(): void {
            root.hide();
        }
    }
}
