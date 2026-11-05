import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// Launcher: the web search engine, Claude, where file search looks and the snooze length.
// One block per page of the category (view.page).
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page

    spacing: Theme.spacing.medium

    // ── Web search ──

    ConfigRow {
        visible: page.sub === "web"
        key: "searchDefault"
        title: "Search with"
        subtitle: `${Config.searchEngines[Config.searchDefault]?.[0] ?? Config.searchDefault} without a shortcut; with one: ? g, ? yt, ? aw …`

        SegmentedButtons {
            model: Object.keys(Config.searchEngines).map(k => ({ key: k, label: k }))
            current: Config.searchDefault
            onSelected: key => Config.set("searchDefault", key)
        }
    }

    // ── Claude ──

    ConfigSwitch {
        visible: page.sub === "claude"
        key: "claudeEnabled"
        title: "Ask Claude in the launcher"
        subtitle: "c, then the question; only there when the claude command is installed"
    }
    ConfigText {
        visible: page.sub === "claude"
        key: "claudeModel"
        title: "Model"
        subtitle: "passed as --model; empty: your CLI's default"
        placeholder: "haiku"
    }

    // ── Files and timers ──

    ConfigText {
        visible: page.sub === "files"
        key: "fileSearchRoot"
        title: "Search files in"
        subtitle: "/ in the launcher; empty: your home folder"
        placeholder: "~"
    }
    ConfigNumber {
        visible: page.sub === "files"
        key: "snoozeMinutes"
        title: "Snooze"
        subtitle: "how long an alarm (a) waits when snoozed"
        min: 1
        max: 60
        unit: " min"
    }
}
