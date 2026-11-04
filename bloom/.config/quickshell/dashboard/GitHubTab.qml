import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// The GitHub tab, about you and not about one repo. The menu top left picks the scope: you
// (contributions and streak, this week, your PRs everywhere, what waits on you, languages)
// or an organisation (its open PRs, Actions runs, the board's "in progress"). Data comes
// from GitHubData (the gh CLI); without gh or a login the tab says what to do.
Item {
    id: root

    property var github: null
    // "me" or an organisation's login
    property string scope: "me"
    readonly property bool mine: scope === "me"
    property bool menuOpen: false
    property bool adding: false

    signal scopePicked(string scope)
    signal refreshRequested()

    implicitWidth: 864
    implicitHeight: Math.max(column.implicitHeight, menuOpen ? menu.y + menu.height + Theme.spacing.normal : 0)

    function shortRepo(full) {
        return String(full ?? "").split("/").pop();
    }

    function prIcon(state) {
        return state === "merged" ? "done_all" : state === "draft" ? "draft" : state === "closed" ? "close" : "merge";
    }

    function pick(scope) {
        menuOpen = false;
        adding = false;
        forceActiveFocus();
        scopePicked(scope);
    }

    onMenuOpenChanged: {
        if (!menuOpen)
            adding = false;
    }

    // ── Building blocks ──────────────────────────────────────

    // A card with a dim heading and rows under it
    component ListCard: Card {
        id: listCard

        property string heading: ""
        property string empty: ""
        property int count: 0
        default property alias rows: holder.data

        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: listCard.heading
                dim: true
                font.pixelSize: Theme.size.small
            }
            StyledText {
                Layout.fillWidth: true
                visible: listCard.count === 0 && listCard.empty !== ""
                text: listCard.empty
                dim: true
                opacity: 0.7
                font.pixelSize: Theme.size.small
                wrapMode: Text.WordWrap
            }
            ColumnLayout {
                id: holder

                Layout.fillWidth: true
                spacing: 0
            }
        }
    }

    // The rounded square with a picture or letters: you, an organisation
    component Avatar: AppIcon {
        property bool org: false

        round: false
        tint: org ? Theme.tertiary : Theme.primary
    }

    // A row of the scope menu: you, an organisation, or the add row
    component ScopeRow: Rectangle {
        id: scopeRowItem

        property string label: ""
        property string note: ""
        property string symbol: ""
        property bool org: false
        property bool removable: false
        property bool current: false
        property string avatar: ""

        signal picked()
        signal removed()

        Layout.fillWidth: true
        implicitHeight: 42
        radius: Theme.rounding.normal
        color: rowArea.containsMouse ? Theme.highest : current ? Theme.alpha(Theme.highest, 0.5) : "transparent"

        Behavior on color {
            ColorAnim {}
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: scopeRowItem.picked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10

            Avatar {
                visible: scopeRowItem.symbol === ""
                size: 28
                org: scopeRowItem.org
                source: scopeRowItem.avatar
                letter: scopeRowItem.label.slice(0, scopeRowItem.org ? 2 : 1).toUpperCase()
                name: ""
            }
            Icon {
                visible: scopeRowItem.symbol !== ""
                Layout.preferredWidth: 28
                icon: scopeRowItem.symbol
                size: Theme.icon.small
                dim: true
            }
            StyledText {
                Layout.fillWidth: true
                text: scopeRowItem.label
                font.pixelSize: Theme.size.small + 1
            }
            StyledText {
                visible: !(scopeRowItem.removable && rowArea.containsMouse)
                text: scopeRowItem.note
                dim: true
                font.pixelSize: Theme.size.tiny
            }
            IconButton {
                visible: scopeRowItem.removable && (rowArea.containsMouse || hovered)
                size: 26
                icon: "close"
                iconSize: 16
                onClicked: scopeRowItem.removed()
            }
        }
    }

    // ── Layout ───────────────────────────────────────────────

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.large - 2

        // Scope, the numbers that matter, refresh
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                id: scopeButton

                implicitWidth: scopeRow.implicitWidth + 18
                implicitHeight: scopeRow.implicitHeight + 12
                radius: Theme.rounding.large
                color: root.menuOpen ? Theme.container : "transparent"

                Behavior on color {
                    ColorAnim {}
                }

                RowLayout {
                    id: scopeRow

                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.medium

                    Avatar {
                        size: 46
                        org: !root.mine
                        source: root.mine ? (root.github?.avatar ?? "") : (root.github?.orgInfo.avatar ?? "")
                        letter: (root.mine ? (root.github?.login || "?") : root.scope).slice(0, root.mine ? 1 : 2).toUpperCase()
                        name: ""
                    }
                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            text: root.mine ? (root.github?.login || "You") : root.scope
                            font.pixelSize: Theme.size.medium
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            dim: true
                            font.pixelSize: Theme.size.small
                            text: root.mine ? (root.github?.login ? `you · github.com/${root.github.login}` : "you")
                                : (root.github?.orgInfo.repos ?? 0) > 0 ? `organisation · ${root.github.orgInfo.repos} repos` : "organisation"
                        }
                    }
                    Icon {
                        icon: "expand_more"
                        dim: true
                        rotation: root.menuOpen ? 180 : 0

                        Behavior on rotation {
                            Anim {}
                        }
                    }
                }

                StateLayer {
                    onClicked: root.menuOpen = !root.menuOpen
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // The numbers that matter for this scope
            Row {
                visible: root.github?.status === "ok"
                spacing: 6

                Chip {
                    visible: root.mine && (root.github?.streak ?? 0) > 0
                    selected: true
                    icon: "local_fire_department"
                    text: (root.github?.streak ?? 0) === 1 ? "1 day in a row" : `${root.github?.streak ?? 0} days in a row`
                }
                Chip {
                    readonly property int count: root.mine ? (root.github?.reviewCount ?? 0) : (root.github?.orgReviewCount ?? 0)

                    selected: false
                    icon: "rate_review"
                    text: count === 1 ? "1 review for you" : `${count} reviews for you`
                }
                Chip {
                    readonly property int count: root.mine ? (root.github?.prs ?? []).filter(p => p.state === "open" || p.state === "draft").length : (root.github?.orgPrCount ?? 0)

                    selected: !root.mine
                    icon: "merge"
                    text: count === 1 ? "1 open PR" : `${count} open PRs`
                }
                Chip {
                    readonly property var done: (root.github?.orgRuns ?? []).filter(r => r.state === "ok" || r.state === "bad")

                    visible: !root.mine && done.length > 0
                    icon: "check_circle"
                    text: `CI ${done.filter(r => r.state === "ok").length} of ${done.length} green`
                }
            }

            IconButton {
                id: refresh

                icon: "refresh"
                disabled: root.github?.busy ?? false
                onClicked: root.refreshRequested()

                RotationAnimation on rotation {
                    running: (root.github?.busy ?? false) && Theme.animated
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: Theme.anim.slow
                    onStopped: refresh.rotation = 0
                }
            }
        }

        // gh missing, not logged in, or an error
        Card {
            id: problem

            readonly property string status: root.github?.status ?? "unknown"
            readonly property string orgProblem: !root.mine && status === "ok" ? (root.github?.orgError ?? "") : ""

            Layout.fillWidth: true
            visible: status !== "ok" || orgProblem !== ""

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing.large

                Rectangle {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: Theme.rounding.medium
                    color: problem.status === "error" || problem.orgProblem !== "" ? Theme.errorContainer : Theme.secondaryContainer

                    Icon {
                        anchors.centerIn: parent
                        icon: problem.status === "unknown" ? "hourglass_top" : problem.status === "missing" ? "terminal" : problem.status === "loggedOut" ? "login" : "cloud_off"
                        color: problem.status === "error" || problem.orgProblem !== "" ? Theme.textOnErrorContainer : Theme.text
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        font.weight: Font.DemiBold
                        text: problem.orgProblem !== "" ? `Could not read ${root.scope}`
                            : problem.status === "unknown" ? "Asking GitHub …"
                            : problem.status === "missing" ? "The GitHub CLI is not installed"
                            : problem.status === "loggedOut" ? "gh is not logged in"
                            : "GitHub did not answer"
                    }
                    StyledText {
                        Layout.fillWidth: true
                        dim: true
                        font.pixelSize: Theme.size.small
                        wrapMode: Text.WordWrap
                        text: problem.orgProblem !== "" ? problem.orgProblem
                            : problem.status === "unknown" ? "Through the gh CLI and its login"
                            : problem.status === "missing" ? "This tab reads GitHub through gh: sudo pacman -S github-cli, then gh auth login"
                            : problem.status === "loggedOut" ? "Run gh auth login once in a terminal; the tab uses the same login"
                            : root.github?.error ?? ""
                    }
                }
                Button {
                    visible: problem.status !== "unknown"
                    text: "Try again"
                    icon: "refresh"
                    variant: "tonal"
                    onClicked: root.refreshRequested()
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.github?.status === "ok"
            sourceComponent: root.mine ? meBody : orgBody
        }
    }

    // ── You ──────────────────────────────────────────────────

    Component {
        id: meBody

        RowLayout {
            spacing: Theme.spacing.medium

            ColumnLayout {
                Layout.preferredWidth: (root.width - Theme.spacing.medium) * 0.58
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacing.medium

                // The year as squares, and this week in numbers
                Card {
                    id: yearCard

                    property string hoverText: ""

                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.normal

                        StyledText {
                            Layout.fillWidth: true
                            dim: true
                            font.pixelSize: Theme.size.small
                            text: yearCard.hoverText !== "" ? yearCard.hoverText
                                : `${(root.github?.contributions ?? 0).toLocaleString(Qt.locale("en_US"), "f", 0)} contributions in the last year`
                                    + (root.github?.busiestDay ? ` · most on ${root.github.busiestDay}` : "")
                        }

                        // One square per day, a column per week (Sunday on top, like GitHub);
                        // as many recent weeks as fit
                        Item {
                            id: heat

                            readonly property int cell: 11
                            readonly property int gap: 3
                            readonly property var days: root.github?.days ?? []
                            readonly property int lead: days.length > 0 ? days[0].weekday : 0
                            readonly property int columns: Math.ceil((lead + days.length) / 7)
                            readonly property int fit: Math.max(1, Math.floor((width + gap) / (cell + gap)))
                            readonly property int firstColumn: Math.max(0, columns - fit)
                            readonly property int most: days.reduce((m, d) => Math.max(m, d.count), 0)
                            readonly property var cells: {
                                const out = [];
                                days.forEach((d, i) => {
                                    const col = Math.floor((i + lead) / 7);
                                    if (col < firstColumn)
                                        return;
                                    out.push({
                                        x: (col - firstColumn) * (cell + gap),
                                        y: ((i + lead) % 7) * (cell + gap),
                                        level: d.count === 0 || most === 0 ? 0 : Math.max(1, Math.min(4, Math.ceil(d.count / most * 4))),
                                        text: `${d.count} on ${new Date(d.date).toLocaleDateString(Qt.locale("en_GB"), "ddd d MMM")}`
                                    });
                                });
                                return out;
                            }

                            Layout.fillWidth: true
                            implicitHeight: 7 * cell + 6 * gap

                            Repeater {
                                model: heat.cells

                                Rectangle {
                                    required property var modelData

                                    x: modelData.x
                                    y: modelData.y
                                    width: heat.cell
                                    height: heat.cell
                                    radius: Math.round(Theme.rounding.small * 0.3)
                                    color: modelData.level === 0 ? Theme.high
                                        : modelData.level === 4 ? Theme.primary
                                        : Theme.mix(Theme.high, Theme.primary, [0, 0.3, 0.55, 0.8][modelData.level])

                                    Behavior on color {
                                        ColorAnim {
                                            duration: Theme.anim.color
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onContainsMouseChanged: {
                                            if (containsMouse)
                                                yearCard.hoverText = parent.modelData.text;
                                            else if (yearCard.hoverText === parent.modelData.text)
                                                yearCard.hoverText = "";
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: Theme.spacing.normal

                            Repeater {
                                model: [
                                    { value: root.github?.week.commits ?? 0, label: "commits this week" },
                                    { value: root.github?.week.prs ?? 0, label: "PRs opened" },
                                    { value: root.github?.week.reviews ?? 0, label: "reviews" },
                                    { value: root.github?.week.issues ?? 0, label: "issues opened" }
                                ]

                                Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: numColumn.implicitHeight + 20
                                    radius: Theme.rounding.medium
                                    color: Theme.high

                                    ColumnLayout {
                                        id: numColumn

                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.padding.normal
                                        anchors.rightMargin: Theme.padding.small
                                        anchors.topMargin: 10
                                        anchors.bottomMargin: 10
                                        spacing: 0

                                        StyledText {
                                            text: String(modelData.value)
                                            tabular: true
                                            font.pixelSize: Theme.size.large
                                            font.weight: Font.DemiBold
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            dim: true
                                            font.pixelSize: Theme.size.tiny
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ListCard {
                    heading: "Your pull requests · everywhere"
                    empty: "None you opened or are part of"
                    count: (root.github?.prs ?? []).length

                    Repeater {
                        model: (root.github?.prs ?? []).slice(0, 6)

                        PrRow {
                            required property var modelData
                            required property int index

                            first: index === 0
                            icon: root.prIcon(modelData.state)
                            tone: modelData.state
                            title: modelData.title
                            meta: `${modelData.repo} #${modelData.number} · ${root.github.ago(modelData.updated)}`
                            review: modelData.review
                            ci: modelData.ci
                            url: modelData.url
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacing.medium

                ListCard {
                    heading: "Waiting on you"
                    empty: "Nothing waits on you"
                    count: (root.github?.waiting ?? []).length

                    Repeater {
                        model: (root.github?.waiting ?? []).slice(0, 6)

                        PrRow {
                            required property var modelData
                            required property int index

                            readonly property var what: ({ review: "asks for your review", mention: "mentions you", assigned: "assigned to you" })

                            first: index === 0
                            icon: modelData.kind === "review" ? "rate_review" : modelData.kind === "mention" ? "alternate_email" : "bug_report"
                            tone: modelData.kind === "review" ? "open" : "draft"
                            title: `${root.shortRepo(modelData.repo)} #${modelData.number} · ${modelData.title}`
                            meta: `${modelData.repo.split("/")[0]} · ${what[modelData.kind]} · ${root.github.ago(modelData.updated)}`
                            url: modelData.url
                        }
                    }
                }

                // Languages by size over the repos you pushed to this year
                Card {
                    Layout.fillWidth: true
                    visible: (root.github?.languages ?? []).length > 0

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing.normal

                        StyledText {
                            text: "What you wrote this year"
                            dim: true
                            font.pixelSize: Theme.size.small
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 8

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Theme.high
                                clip: true

                                Row {
                                    anchors.fill: parent
                                    spacing: 0

                                    Repeater {
                                        model: root.github?.languages ?? []

                                        Rectangle {
                                            required property var modelData

                                            width: modelData.share * parent.width
                                            height: parent.height
                                            // GitHub's own language colors are data, like album art
                                            color: modelData.color !== "" ? modelData.color : Theme.outline
                                        }
                                    }
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.medium

                            Repeater {
                                model: root.github?.languages ?? []

                                Row {
                                    required property var modelData

                                    spacing: 5

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 8
                                        height: 8
                                        radius: height / 2
                                        color: modelData.color !== "" ? modelData.color : Theme.outline
                                    }
                                    StyledText {
                                        text: `${modelData.name} ${Math.round(modelData.share * 100)}%`
                                        dim: true
                                        font.pixelSize: Theme.size.tiny
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── An organisation ──────────────────────────────────────

    Component {
        id: orgBody

        RowLayout {
            spacing: Theme.spacing.medium

            ListCard {
                Layout.preferredWidth: (root.width - Theme.spacing.medium) * 0.58
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignTop
                heading: "Pull requests"
                empty: root.github?.orgFetchedAt > 0 ? "No open pull requests" : "Asking GitHub …"
                count: (root.github?.orgPrs ?? []).length

                Repeater {
                    model: root.github?.orgPrs ?? []

                    PrRow {
                        required property var modelData
                        required property int index

                        first: index === 0
                        icon: root.prIcon(modelData.state)
                        tone: modelData.state
                        title: modelData.title
                        meta: `${root.shortRepo(modelData.repo)} #${modelData.number} · ${modelData.author} · ${root.github.ago(modelData.updated)}`
                        review: modelData.review
                        ci: modelData.ci
                        url: modelData.url
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacing.medium

                ListCard {
                    heading: "Actions"
                    empty: root.github?.orgFetchedAt > 0 ? "No runs in the repos pushed last" : "Asking GitHub …"
                    count: (root.github?.orgRuns ?? []).length

                    Repeater {
                        model: root.github?.orgRuns ?? []

                        PrRow {
                            required property var modelData
                            required property int index

                            first: index === 0
                            icon: modelData.state === "ok" ? "check" : modelData.state === "bad" ? "close" : modelData.state === "run" ? "progress_activity" : "remove"
                            tone: modelData.state === "ok" ? "open" : modelData.state
                            title: `${modelData.repo} · ${modelData.name}`
                            meta: `${modelData.branch} · ${modelData.state === "run" ? "running" : root.github.ago(modelData.updated)}`
                            url: modelData.url
                        }
                    }
                }

                ListCard {
                    heading: "Board · in progress"
                    empty: root.github?.boardNote ?? ""
                    count: (root.github?.orgBoard ?? []).length

                    Repeater {
                        model: (root.github?.orgBoard ?? []).slice(0, 6)

                        PrRow {
                            required property var modelData
                            required property int index

                            first: index === 0
                            icon: "radio_button_unchecked"
                            tone: "draft"
                            title: modelData.title
                            meta: modelData.number > 0 ? `${modelData.repo} #${modelData.number}` : modelData.repo
                        }
                    }
                }
            }
        }
    }

    // ── The scope menu ───────────────────────────────────────

    // A click anywhere else closes it
    MouseArea {
        anchors.fill: parent
        z: 9
        visible: root.menuOpen
        onClicked: root.menuOpen = false
    }

    Rectangle {
        id: menu

        z: 10
        x: scopeButton.x
        y: scopeButton.y + scopeButton.height + 6
        width: 290
        height: menuColumn.implicitHeight + 12
        radius: Theme.rounding.large
        color: Theme.high
        visible: opacity > 0.01
        opacity: root.menuOpen ? 1 : 0
        scale: root.menuOpen ? 1 : 0.92
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            Anim {
                duration: Theme.anim.small
            }
        }
        Behavior on scale {
            Anim {}
        }

        // Keeps clicks on the menu from the catcher behind it
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: menuColumn

            x: 6
            y: 6
            width: parent.width - 12
            spacing: 2

            ScopeRow {
                label: root.github?.login || "you"
                note: "you"
                avatar: root.github?.avatar ?? ""
                current: root.mine
                onPicked: root.pick("me")
            }

            Repeater {
                model: root.github?.orgs ?? []

                ScopeRow {
                    required property string modelData

                    label: modelData
                    note: "organisation"
                    org: true
                    removable: true
                    avatar: root.github?.orgInfo.login === modelData ? root.github.orgInfo.avatar : ""
                    current: root.scope === modelData
                    onPicked: root.pick(modelData)
                    onRemoved: {
                        if (root.scope === modelData)
                            root.pick("me");
                        root.github.removeOrg(modelData);
                    }
                }
            }

            ScopeRow {
                visible: !root.adding
                label: "Add an organisation …"
                symbol: "add"
                onPicked: {
                    root.adding = true;
                    orgField.text = "";
                    orgField.focusField();
                }
            }

            SearchField {
                id: orgField

                visible: root.adding
                Layout.fillWidth: true
                implicitHeight: Theme.control.button
                baseColor: Theme.container
                icon: "corporate_fare"
                placeholder: "organisation, e.g. facet-shell"
                onAccepted: {
                    const name = text.trim();
                    if (root.github?.addOrg(name))
                        root.pick(name);
                }
                onEscaped: {
                    root.adding = false;
                    // Back to the drawer, so the next Esc closes it
                    root.forceActiveFocus();
                }
            }
        }
    }
}
