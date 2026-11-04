import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// Bottom right of the lockscreen: "while you were away", what arrived since the screen locked,
// one row per app ("2 from Discord", the senders on the right). Popups cannot show over a
// session lock, so this is where they end up. Hidden while nothing came in.
Card {
    id: root

    // When the screen locked; only what came later counts
    property date since: new Date()

    readonly property var groups: {
        const start = since.getTime();
        const byApp = {};
        const order = [];
        for (const entry of Notifications.history) {
            if (!entry.time || entry.time.getTime() < start)
                continue;
            const key = entry.app || "app";
            if (!byApp[key]) {
                byApp[key] = { app: key, image: entry.image || "", glyph: entry.glyph || "", count: 0, names: [] };
                order.push(key);
            }
            const group = byApp[key];
            group.count += 1;
            if (entry.title && !group.names.includes(entry.title))
                group.names.push(entry.title);
        }
        // history is newest first, so the app heard from last comes first
        return order.slice(0, 4).map(k => byApp[k]);
    }

    function appName(app) {
        return app.charAt(0).toUpperCase() + app.slice(1);
    }

    implicitWidth: 300

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.normal

        StyledText {
            text: "while you were away"
            dim: true
            font.pixelSize: Theme.size.tiny
        }

        Repeater {
            model: root.groups

            RowLayout {
                id: row

                required property var modelData

                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                AppIcon {
                    size: 30
                    name: row.modelData.app
                    letter: row.modelData.glyph || row.modelData.app.charAt(0).toUpperCase()
                }

                StyledText {
                    text: `${row.modelData.count} from ${root.appName(row.modelData.app)}`
                    font.pixelSize: Theme.size.small + 1
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.names.join(", ")
                    dim: true
                    font.pixelSize: Theme.size.tiny
                }
            }
        }
    }
}
