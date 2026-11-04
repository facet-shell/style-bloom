import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The app rules for the virtual channels (Config.audioRules, used by services/Channels.qml),
// as a block like the game list: one line per rule (the chips pick its channel, × takes it
// off), a field to add one with its channel, and the apps playing right now as suggestions.
Rectangle {
    id: rules

    readonly property var list: Config.audioRules
    readonly property var channels: Audio.outputRoutes
    property string newChannel: channels.includes("game") ? "game" : channels[0] ?? ""

    function label(route) {
        const l = Audio.routeLabel(route);
        return l.charAt(0).toUpperCase() + l.slice(1);
    }

    function store(next) {
        if (JSON.stringify(next) === JSON.stringify(Config.audioRuleDefaults))
            Config.reset("audioRules");
        else
            Config.set("audioRules", next);
    }

    function has(pattern) {
        return list.some(r => String(r[0]).toLowerCase() === String(pattern).toLowerCase());
    }

    function add(pattern, channel) {
        const p = String(pattern).trim();
        if (p === "" || channel === "" || has(p))
            return;
        store(list.concat([[p, channel]]));
    }

    function change(index, channel) {
        store(list.map((r, i) => i === index ? [r[0], channel] : r));
    }

    function remove(index) {
        store(list.filter((r, i) => i !== index));
    }

    // The apps playing now that no rule names yet: their program, else their name
    readonly property var playing: {
        const seen = new Set();
        const out = [];
        for (const n of Audio.playback) {
            const props = n.properties ?? {};
            const id = String(props["application.process.binary"] || props["application.name"] || "");
            if (id === "" || seen.has(id.toLowerCase()) || has(id))
                continue;
            seen.add(id.toLowerCase());
            out.push(id);
        }
        return out;
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Theme.padding.normal * 2
    radius: Theme.rounding.medium
    color: Theme.container

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.padding.normal
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: Theme.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.tiny

            StyledText {
                Layout.fillWidth: true
                text: "Apps on their channel"
            }
            StyledText {
                Layout.fillWidth: true
                text: "When an app starts playing on System it moves to its channel. The app's name or program, any case, * matches anything; @game is the game that runs. What you pick in the mixer wins."
                dim: true
                font.pixelSize: Theme.size.small
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        Repeater {
            model: rules.list

            delegate: RowLayout {
                id: ruleRow

                required property var modelData
                required property int index
                readonly property string channel: String(modelData[1])

                Layout.fillWidth: true
                spacing: Theme.spacing.normal

                StyledText {
                    Layout.preferredWidth: 170
                    text: String(ruleRow.modelData[0])
                    dim: !rules.channels.includes(ruleRow.channel)
                    font.pixelSize: Theme.size.small
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: rules.channels

                        delegate: Chip {
                            required property string modelData

                            compact: true
                            text: rules.label(modelData)
                            selected: ruleRow.channel === modelData
                            onClicked: rules.change(ruleRow.index, modelData)
                        }
                    }
                    StyledText {
                        visible: !rules.channels.includes(ruleRow.channel)
                        height: 24
                        text: `${ruleRow.channel} · not set up`
                        dim: true
                        font.pixelSize: Theme.size.tiny
                    }
                }
                IconButton {
                    size: 28
                    iconSize: 16
                    icon: "close"
                    onClicked: rules.remove(ruleRow.index)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            TextBox {
                id: entry

                Layout.preferredWidth: 220
                placeholder: "app, *pattern* or @game"
                onAccepted: {
                    rules.add(text, rules.newChannel);
                    text = "";
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: rules.channels

                    delegate: Chip {
                        required property string modelData

                        compact: true
                        text: rules.label(modelData)
                        selected: rules.newChannel === modelData
                        onClicked: rules.newChannel = modelData
                    }
                }
            }
            Button {
                text: "Add"
                icon: "add"
                variant: "tonal"
                disabled: entry.text.trim() === "" || rules.newChannel === ""
                onClicked: {
                    rules.add(entry.text, rules.newChannel);
                    entry.text = "";
                }
            }
        }

        // What plays now: a click puts it in the field
        Flow {
            Layout.fillWidth: true
            visible: rules.playing.length > 0
            spacing: Theme.spacing.normal

            StyledText {
                height: Theme.control.chip
                text: "playing now"
                dim: true
                font.pixelSize: Theme.size.tiny
            }
            Repeater {
                model: rules.playing

                delegate: Chip {
                    required property string modelData

                    icon: "add"
                    text: modelData
                    onClicked: entry.text = modelData
                }
            }
        }
    }
}
