import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.config

// The system tray: one round button per app that has a tray icon (StatusNotifierItem), in a
// pill that is gone while there are none. Click: the app (or its menu, for apps that only
// have one); right click: its menu out of the bar (TrayMenu); middle click: the app's second
// action; the wheel goes to the app. A dot while the app wants attention.
Pill {
    id: root

    property ShellScreen screen: null
    property var menu: null
    readonly property int count: SystemTray.items.values.length

    padding: 4
    spacing: 2
    opacity: count > 0 ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        Anim {
            duration: Theme.anim.small
        }
    }

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property SystemTrayItem modelData
            readonly property bool menuOpen: (root.menu?.open ?? false) && root.menu.item === modelData

            implicitWidth: 30
            implicitHeight: 30

            function showMenu() {
                if (root.menu && entry.modelData.hasMenu)
                    root.menu.toggle(root.screen, entry.modelData, entry);
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: area.containsMouse || entry.menuOpen ? Theme.high : "transparent"
                scale: area.pressed ? 0.85 : 1

                Behavior on color {
                    ColorAnim {}
                }
                Behavior on scale {
                    SpringAnim {}
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Theme.icon.small
                    source: entry.modelData.icon
                    asynchronous: true
                }
            }

            Badge {
                anchors.right: parent.right
                anchors.top: parent.top
                shown: entry.modelData.status === Status.NeedsAttention
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        entry.modelData.hasMenu ? entry.showMenu() : entry.modelData.secondaryActivate();
                    else if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else if (entry.modelData.onlyMenu)
                        entry.showMenu();
                    else
                        entry.modelData.activate();
                }
                onWheel: wheel => {
                    const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
                    entry.modelData.scroll(Math.round((horizontal ? wheel.angleDelta.x : wheel.angleDelta.y) / 120), horizontal);
                }
            }
        }
    }
}
