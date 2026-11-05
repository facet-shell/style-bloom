import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// A category's menu: its pages as rows (MenuRow), one card per group, like the first level
// of Apple's settings. A click opens the page; a row with `open` opens an app instead.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    Repeater {
        model: page.view.groupsOf(page.view.category)

        delegate: ColumnLayout {
            id: group

            required property var modelData

            Layout.fillWidth: true
            spacing: Theme.spacing.small

            PageHeading {
                visible: group.modelData.title !== ""
                Layout.topMargin: Theme.spacing.small
                text: group.modelData.title
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rows.implicitHeight
                radius: Theme.rounding.large
                color: Theme.container

                Behavior on color {
                    ColorAnim {
                        duration: Theme.anim.color
                    }
                }

                Column {
                    id: rows

                    width: parent.width

                    Repeater {
                        model: group.modelData.pages

                        delegate: MenuRow {
                            required property var modelData
                            required property int index

                            width: rows.width
                            first: index === 0
                            icon: modelData.icon
                            title: modelData.label
                            subtitle: modelData.subtitle ?? ""
                            value: page.view.valueOf(page.view.category, modelData.key)
                            onClicked: page.view.openPage(modelData.key)
                        }
                    }
                }
            }
        }
    }
}
