import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// One line of the GitHub lists: a round status icon, the title with a small line under it,
// and on the right the review state and the CI icon. A click opens it in the browser.
//
//   PrRow { icon: "merge"; tone: "open"; title: pr.title; meta: "shell #42 · 2 h"
//           review: pr.review; ci: pr.ci; url: pr.url }
//
//   tone     the circle's color: open (ok), merged (primary), bad (error), run (tertiary),
//            draft or anything else (dim)
//   review   approved, changes, waiting, merged, closed or "" (no chip)
//   ci       ok, bad, run or "" (no icon)
//   first    no line above it
Item {
    id: root

    property string icon: "merge"
    property string tone: "open"
    property string title: ""
    property string meta: ""
    property string review: ""
    property string ci: ""
    property string url: ""
    property bool first: false

    readonly property color toneColor: tone === "open" ? Theme.ok : tone === "merged" ? Theme.primary : tone === "bad" ? Theme.error : tone === "run" ? Theme.tertiary : Theme.dim
    readonly property var reviewText: ({ approved: "approved", changes: "changes requested", waiting: "waiting for review", merged: "merged", closed: "closed" })

    Layout.fillWidth: true
    implicitWidth: 300
    implicitHeight: 44

    Rectangle {
        visible: !root.first
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.alpha(Theme.outline, 0.6)
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: Theme.rounding.small
        color: area.containsMouse && root.url !== "" ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnim {}
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing.small
        anchors.rightMargin: Theme.spacing.small
        spacing: 10

        Rectangle {
            implicitWidth: 26
            implicitHeight: 26
            radius: height / 2
            color: root.tone === "draft" || root.tone === "" ? Theme.high : Theme.alpha(root.toneColor, 0.22)

            Icon {
                anchors.centerIn: parent
                icon: root.icon
                size: 16
                color: root.toneColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.size.small + 1
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.meta
                dim: true
                font.pixelSize: Theme.size.tiny
            }
        }

        Rectangle {
            visible: root.review !== ""
            implicitWidth: reviewLabel.implicitWidth + 16
            implicitHeight: 20
            radius: height / 2
            color: root.review === "approved" ? Theme.alpha(Theme.ok, 0.22)
                : root.review === "changes" ? Theme.alpha(Theme.error, 0.2)
                : Theme.high

            StyledText {
                id: reviewLabel
                anchors.centerIn: parent
                text: root.reviewText[root.review] ?? root.review
                color: root.review === "approved" ? Theme.ok : root.review === "changes" ? Theme.error : Theme.dim
                font.pixelSize: Theme.size.tiny
            }
        }

        Icon {
            id: ciIcon

            visible: root.ci !== ""
            icon: root.ci === "ok" ? "check_circle" : root.ci === "bad" ? "cancel" : "progress_activity"
            size: Theme.icon.small
            color: root.ci === "ok" ? Theme.ok : root.ci === "bad" ? Theme.error : Theme.tertiary

            // A running check turns, like the mockup's
            RotationAnimation on rotation {
                running: root.ci === "run" && root.visible && Theme.animated
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: Theme.anim.slow + Theme.anim.medium
                onStopped: ciIcon.rotation = 0
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.url !== ""
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.openUrlExternally(root.url)
    }
}
