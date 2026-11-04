import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Launcher: the web search engine, Claude, where file search looks and the snooze length.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    PageHeading {
        text: "Web search (?)"
    }
    ConfigRow {
        key: "searchDefault"
        title: "Search with"
        subtitle: `${Config.searchEngines[Config.searchDefault]?.[0] ?? Config.searchDefault} without a shortcut; with one: ? g, ? yt, ? aw …`

        SegmentedButtons {
            model: Object.keys(Config.searchEngines).map(k => ({ key: k, label: k }))
            current: Config.searchDefault
            onSelected: key => Config.set("searchDefault", key)
        }
    }

    PageHeading {
        text: "Claude (c)"
    }
    ConfigSwitch {
        key: "claudeEnabled"
        title: "Ask Claude in the launcher"
        subtitle: "only there when the claude command is installed"
    }
    ConfigText {
        key: "claudeModel"
        title: "Model"
        subtitle: "passed as --model; empty: your CLI's default"
        placeholder: "haiku"
    }

    PageHeading {
        text: "Files (/) and timers (t, a)"
    }
    ConfigText {
        key: "fileSearchRoot"
        title: "Search files in"
        subtitle: "empty: your home folder"
        placeholder: "~"
    }
    ConfigNumber {
        key: "snoozeMinutes"
        title: "Snooze"
        subtitle: "how long an alarm waits when snoozed"
        min: 1
        max: 60
        unit: " min"
    }
}
