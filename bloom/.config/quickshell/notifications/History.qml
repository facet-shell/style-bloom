import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The notification history, out of the right edge under the bell: newest first as rounded
// rows (picture, title, when, app, text, the actions that still make sense), "silent" and
// "clear all" on top. Opening it counts everything as seen (the bell's dot goes).
// `qs ipc call notifications toggle`, also `open` and `close`.
Scope {
    id: root

    property bool open: false
    property ShellScreen screen: null
    // "5m" moves on while the drawer is out
    property int tick: 0

    function show(screen) {
        root.screen = screen ?? Bloom.focusedScreen;
        open = true;
        Notifications.markSeen();
    }

    function hide() {
        open = false;
    }

    function toggle(screen) {
        if (open)
            hide();
        else
            show(screen);
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.open
        onTriggered: root.tick++
    }

    Drawer {
        id: drawer

        screen: root.screen
        edge: "right"
        align: "start"
        offset: 70
        open: root.open
        namespace: "qs-notification-history"
        keyboard: WlrKeyboardFocus.OnDemand
        onDismissed: root.hide()

        ColumnLayout {
            id: content

            // The list scrolls once it would run past most of the screen
            readonly property real maxList: (root.screen?.height ?? 1080) * 0.62

            anchors.fill: parent
            implicitWidth: 400
            spacing: Theme.spacing.medium

            // ── Header ──

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: "Notifications"
                    font.pixelSize: Theme.size.medium
                    font.weight: Font.Medium
                }
                Chip {
                    text: "silent"
                    icon: Toggles.silent ? "notifications_off" : "notifications"
                    selected: Toggles.silent
                    compact: true
                    onClicked: Toggles.silent = !Toggles.silent
                }
                Button {
                    visible: Notifications.history.length > 0
                    text: "clear all"
                    icon: "clear_all"
                    variant: "text"
                    compact: true
                    onClicked: Notifications.clearHistory()
                }
            }

            // ── Nothing yet ──

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.large
                Layout.bottomMargin: Theme.spacing.large
                visible: Notifications.history.length === 0
                spacing: Theme.spacing.normal

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "notifications_none"
                    size: Theme.icon.huge * 0.8
                    dim: true
                    fill: 0
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nothing new"
                    dim: true
                }
            }

            // ── The list ──

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, content.maxList)
                visible: count > 0
                clip: true
                spacing: Theme.spacing.normal
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: Notifications.history
                }

                add: Transition {
                    Anim {
                        property: "opacity"
                        from: 0
                        to: 1
                    }
                }
                displaced: Transition {
                    Anim {
                        properties: "y"
                    }
                }

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    readonly property bool actionable: modelData.actions.length > 0 && modelData.callEnded !== true

                    width: ListView.view.width
                    implicitHeight: rowContent.implicitHeight + Theme.padding.normal * 2
                    radius: Theme.rounding.large
                    color: hover.hovered ? Theme.high : Theme.container

                    Behavior on color {
                        ColorAnim {}
                    }

                    HoverHandler {
                        id: hover
                    }

                    RowLayout {
                        id: rowContent

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.padding.normal
                        spacing: Theme.spacing.medium

                        NoteIcon {
                            Layout.alignment: Qt.AlignTop
                            entry: row.modelData
                            size: 36
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.tiny

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing.normal

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.title
                                    font.weight: Font.Medium
                                    font.pixelSize: Theme.size.small + 1
                                }
                                StyledText {
                                    text: {
                                        root.tick;
                                        return Notifications.ago(row.modelData.time);
                                    }
                                    dim: true
                                    tabular: true
                                    font.pixelSize: Theme.size.tiny
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.app
                                dim: true
                                font.pixelSize: Theme.size.tiny
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.body
                                dim: true
                                font.pixelSize: Theme.size.small
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                            }
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.spacing.small
                                visible: row.actionable
                                spacing: Theme.spacing.small + Theme.spacing.tiny

                                Repeater {
                                    model: row.actionable ? row.modelData.actions : []

                                    delegate: Button {
                                        required property var modelData

                                        text: modelData.label
                                        compact: true
                                        variant: modelData.style === "ok" ? "ok" : modelData.style === "no" ? "danger" : "plain"
                                        onClicked: Notifications.invoke(row.modelData.uid, modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.toggle(null);
        }

        function open(): void {
            root.show(null);
        }

        function close(): void {
            root.hide();
        }
    }
}
