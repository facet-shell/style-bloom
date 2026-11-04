import QtQuick
import qs.components
import qs.config

// A notification rule (Config.notifyRules): always, not in game, never. Its reset button
// puts back the rule's own default (Config.setRule), not the whole notifyRules key.
ConfigRow {
    id: rule

    property string kind: ""
    readonly property string value: Config.notifyRules[kind] ?? "always"

    resettable: true
    changed: (Config.user.notifyRules ?? {})[kind] !== undefined
    onResetClicked: Config.setRule(rule.kind, Config.notifyRuleDefaults[rule.kind] ?? "always")

    SegmentedButtons {
        model: [
            { key: "always", label: "always" },
            { key: "game", label: "not in game" },
            { key: "never", label: "never" }
        ]
        current: rule.value
        onSelected: key => Config.setRule(rule.kind, key)
    }
}
