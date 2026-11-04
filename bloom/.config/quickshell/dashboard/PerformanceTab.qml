import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

// The performance tab: CPU, GPU, RAM and GPU temperature as gauges, and the task manager
// below (services/Tasks.qml, read every two seconds while this tab is on screen). Close asks
// an app to quit; kill ends its whole process tree and wants a second click, as in tui.
ColumnLayout {
    id: root

    // The app whose kill waits for its second click
    property string armed: ""
    // windowed or background
    property string list: "windowed"
    readonly property var apps: list === "windowed" ? Tasks.windowed : Tasks.background.slice(0, 20)

    spacing: Theme.spacing.medium

    function kill(app) {
        if (armed !== app.key) {
            armed = app.key;
            disarm.restart();
            return;
        }
        armed = "";
        Tasks.kill(app);
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    // ── Gauges ───────────────────────────────────────────────

    component GaugeCard: Card {
        id: card

        property real value: 0
        property string number: ""
        property string label: ""
        property string detail: ""
        // Turns warn and then error when it runs hot
        property real warnAt: 0.85

        Layout.fillWidth: true
        Layout.preferredWidth: 1

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.small

            Gauge {
                Layout.alignment: Qt.AlignHCenter
                value: card.value
                color: card.value >= card.warnAt + 0.1 ? Theme.error : card.value >= card.warnAt ? Theme.warn : Theme.primary

                StyledText {
                    text: card.number
                    tabular: true
                    font.pixelSize: Theme.size.large
                    font.weight: Font.DemiBold
                }
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: card.label
                dim: true
                font.pixelSize: Theme.size.small
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                text: card.detail
                dim: true
                opacity: 0.7
                font.pixelSize: Theme.size.tiny
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        GaugeCard {
            value: SystemStats.cpu / 100
            number: `${Math.round(SystemStats.cpu)}%`
            label: "CPU"
            detail: SystemStats.cpuTemp > 0 ? `${Math.round(SystemStats.cpuTemp)}°` : ""
        }
        GaugeCard {
            value: SystemStats.gpu / 100
            number: `${Math.round(SystemStats.gpu)}%`
            label: "GPU"
            detail: SystemStats.vramTotal > 0 ? `VRAM ${SystemStats.vramUsed.toFixed(1)} of ${Math.round(SystemStats.vramTotal)} GB` : ""
        }
        GaugeCard {
            value: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0
            number: `${Math.round(value * 100)}%`
            label: `RAM · ${SystemStats.memUsed.toFixed(1)} of ${Math.round(SystemStats.memTotal)} GB`
        }
        GaugeCard {
            // 100° is the end of the scale
            value: SystemStats.gpuTemp / 100
            number: SystemStats.gpuTemp > 0 ? `${Math.round(SystemStats.gpuTemp)}°` : "–"
            label: "GPU temp"
            warnAt: 0.8
        }
    }

    // ── Task manager ─────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        spacing: Theme.spacing.medium

        SegmentedButtons {
            model: [
                { key: "windowed", label: `With a window · ${Tasks.windowed.length}` },
                { key: "background", label: `Background · ${Tasks.background.length}` }
            ]
            current: root.list
            onSelected: key => root.list = key
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "close asks the app to quit · kill ends it at once (click twice) · 100% CPU is one core"
            dim: true
            font.pixelSize: Theme.size.tiny
        }
    }

    // Column heads
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 6
        spacing: 10

        Item {
            implicitWidth: 30
        }
        StyledText {
            Layout.fillWidth: true
            text: "app"
            dim: true
            font.pixelSize: Theme.size.tiny
        }
        StyledText {
            Layout.preferredWidth: 80
            horizontalAlignment: Text.AlignRight
            text: "CPU"
            dim: true
            font.pixelSize: Theme.size.tiny
        }
        StyledText {
            Layout.preferredWidth: 90
            horizontalAlignment: Text.AlignRight
            text: "memory"
            dim: true
            font.pixelSize: Theme.size.tiny
        }
        Item {
            implicitWidth: Theme.control.iconButton * 2 + 10
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: root.apps.length === 0 ? empty.implicitHeight + Theme.spacing.large : Math.min(rows.implicitHeight, 330)

        StyledText {
            id: empty

            anchors.centerIn: parent
            visible: root.apps.length === 0
            text: !Tasks.loaded ? "Reading /proc …" : root.list === "windowed" ? "No windows open" : "Nothing in the background"
            dim: true
        }

        Flickable {
            id: flick

            anchors.fill: parent
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: rows

                width: flick.width - (flick.contentHeight > flick.height ? 10 : 0)
                spacing: Theme.spacing.small

                // Rows stay with their app across polls (an armed kill keeps its state)
                Repeater {
                    model: ScriptModel {
                        values: root.apps
                        objectProp: "key"
                    }

                    Rectangle {
                        id: row

                        required property var modelData
                        readonly property bool isArmed: root.armed === modelData.key

                        Layout.fillWidth: true
                        implicitHeight: line.implicitHeight + 14
                        radius: Theme.rounding.normal
                        color: isArmed ? Theme.alpha(Theme.errorContainer, 0.6) : Theme.container

                        Behavior on color {
                            ColorAnim {}
                        }

                        RowLayout {
                            id: line

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 10

                            AppIcon {
                                size: 30
                                name: row.modelData.icon
                                letter: row.modelData.glyph
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    font.pixelSize: Theme.size.small + 1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.detail
                                    dim: true
                                    font.pixelSize: Theme.size.tiny
                                }
                            }
                            StyledText {
                                Layout.preferredWidth: 80
                                horizontalAlignment: Text.AlignRight
                                text: `${row.modelData.cpu.toFixed(1)} %`
                                tabular: true
                                color: row.modelData.cpu >= 50 ? Theme.warn : Theme.dim
                                font.pixelSize: Theme.size.small
                            }
                            StyledText {
                                Layout.preferredWidth: 90
                                horizontalAlignment: Text.AlignRight
                                text: Tasks.formatMem(row.modelData.mem)
                                tabular: true
                                dim: true
                                font.pixelSize: Theme.size.small
                            }
                            IconButton {
                                icon: "close"
                                iconSize: Theme.icon.small
                                onClicked: Tasks.close(row.modelData)
                            }
                            IconButton {
                                icon: row.isArmed ? "priority_high" : "dangerous"
                                iconSize: Theme.icon.small
                                active: row.isArmed
                                iconColor: Theme.error
                                onClicked: root.kill(row.modelData)
                            }
                        }
                    }
                }
            }
        }

        // A thin scroll line while the list is longer than its place
        Rectangle {
            visible: flick.contentHeight > flick.height
            anchors.right: parent.right
            width: 4
            radius: width / 2
            y: flick.visibleArea.yPosition * flick.height
            height: flick.visibleArea.heightRatio * flick.height
            color: Theme.outline
        }
    }
}
