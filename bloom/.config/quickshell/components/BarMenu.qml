import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// A menu that drops out of the bar under the button that opened it (a Drawer on the top edge
// with a Menu in it): the tray's right-click menus, the power menu.
//
//   BarMenu { id: menu; title: "Power"; entries: [...]; onActivated: (i, e) => … }
//   menu.popup(screen, button)    opens it under `button`, an Item in the bar
//   menu.open = false             closes it (a click outside or Esc does too)
//
//   entries, title   as in Menu; signal activated(int index, var entry) (it stays open: set
//                    open = false there, or swap the entries for a submenu)
//   menuWidth        240
//   anchorItem       the button it belongs to (set by popup); compare it to toggle
//   namespace        "qs-bar-menu"
Drawer {
    id: root

    property var entries: []
    property string title: ""
    property real menuWidth: 240
    property Item anchorItem: null

    signal activated(int index, var entry)

    edge: "top"
    align: "start"
    padding: 6
    radius: Theme.rounding.large
    namespace: "qs-bar-menu"
    keyboard: WlrKeyboardFocus.OnDemand
    onDismissed: open = false
    onOpenChanged: if (!open) anchorItem = null

    function popup(screen, item) {
        anchorItem = item;
        root.screen = screen;
        // The bar sits in a window over the whole screen, so its coordinates are the screen's
        const pos = item.mapToItem(null, 0, 0);
        const hole = (screen?.width ?? 1920) - Theme.frame.border * 2;
        const full = menuWidth + padding * 2 + joint * 2;
        // Start the menu a little left of the button, or end it a little right of it in the
        // right half; never into the hole's corners
        if (pos.x + item.width / 2 < (screen?.width ?? 1920) / 2) {
            align = "start";
            offset = Math.max(Theme.rounding.hole, Math.min(hole - full - Theme.rounding.hole, pos.x - Theme.frame.border - joint - padding));
        } else {
            align = "end";
            const right = (screen?.width ?? 1920) - (pos.x + item.width);
            offset = Math.max(Theme.rounding.hole, Math.min(hole - full - Theme.rounding.hole, right - Theme.frame.border - joint - padding));
        }
        open = true;
    }

    Menu {
        width: parent.width
        implicitWidth: root.menuWidth
        entries: root.entries
        title: root.title
        onActivated: (index, entry) => root.activated(index, entry)
    }
}
