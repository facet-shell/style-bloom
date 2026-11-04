import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components

// A tray app's own menu, out of the bar under its icon, in the bloom look instead of the
// app's toolkit. Submenus open in place with a "back" row on top; check boxes and radio
// entries show their state.
BarMenu {
    id: root

    // The tray item whose menu is out
    property SystemTrayItem item: null
    // Menu handles from the top menu to the one shown
    property var stack: []
    readonly property var handle: stack.length > 0 ? stack[stack.length - 1] : null

    namespace: "qs-tray-menu"
    title: item ? (item.tooltipTitle || item.title || item.id) : ""
    entries: {
        const rows = (opener.children?.values ?? []).map(e => e.isSeparator ? { separator: true } : {
            text: e.text,
            image: e.icon,
            enabled: e.enabled,
            checked: e.buttonType === QsMenuButtonType.None ? undefined : e.checkState === Qt.Checked,
            more: e.hasChildren,
            entry: e
        });
        return stack.length > 1 ? [{ text: "back", back: true }].concat(rows) : rows;
    }

    // Opens the menu of `trayItem` under `button`; the same one again closes it
    function toggle(screen, trayItem, button) {
        if (open && item === trayItem) {
            open = false;
            return;
        }
        item = trayItem;
        stack = [trayItem.menu];
        popup(screen, button);
    }

    onOpenChanged: {
        if (!open)
            stack = [];
    }

    onActivated: (index, row) => {
        if (row.back) {
            stack = stack.slice(0, -1);
        } else if (row.more) {
            stack = stack.concat([row.entry]);
        } else {
            row.entry.triggered();
            open = false;
        }
    }

    // An app that quits takes its menu along
    Connections {
        target: SystemTray.items
        function onValuesChanged() {
            if (root.item && !SystemTray.items.values.includes(root.item))
                root.open = false;
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.handle
    }
}
