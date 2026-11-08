import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// GitHub for the dashboard, through the gh CLI and the login it already has (gh auth login).
// Two scopes: you (contributions, your PRs everywhere, what waits on you, languages) and an
// organisation (its open PRs, the newest Actions runs, the project board "in progress").
// Each scope is one GraphQL request; the Actions runs are REST calls per repo. Nothing runs
// on its own: the dashboard calls refresh() / refreshOrg() on open and every few minutes.
Scope {
    id: root

    // "unknown" (not asked yet), "missing" (no gh), "loggedOut", "ok", "error"
    property string status: "unknown"
    property string error: ""
    readonly property bool busy: check.running || me.running || orgCall.running || runsCall.running

    // Connecting gh from the tab: "" (nothing going on), "browser" (a one-time code waits to be
    // entered on github.com), "token" (a pasted token is being checked), "failed" (authError)
    property string authState: ""
    property string authCode: ""
    property string authUrl: ""
    property string authError: ""
    // The login lacks read:project: the organisation loads without its project board
    property bool boardBlocked: false

    // ── You ──────────────────────────────────────────────────

    property string login: ""
    property string name: ""
    property string avatar: ""
    // [{ date, count, weekday }], oldest first, the last year
    property var days: []
    property int contributions: 0
    property int streak: 0
    // "Tuesdays": the weekday with the most contributions
    property string busiestDay: ""
    // The last seven days
    property var week: ({ commits: 0, prs: 0, reviews: 0, issues: 0 })
    // [{ number, title, url, state, repo, author, review, ci, updated }], newest first;
    // state: open, draft, merged, closed; review: approved, changes, waiting, merged, closed or "";
    // ci: ok, bad, run or ""
    property var prs: []
    // [{ kind (review, mention, assigned), title, number, repo, url, updated }]
    property var waiting: []
    property int reviewCount: 0
    // [{ name, color, share (0..1) }], the languages of your repos pushed this year
    property var languages: []
    property real fetchedAt: 0

    // ── An organisation ──────────────────────────────────────

    // Organisations in the scope menu (more can be added there)
    readonly property var orgs: Config.user.githubOrgs ?? ["facet-shell"]
    // The one loaded below
    property string org: ""
    property string orgError: ""
    property var orgInfo: ({ login: "", name: "", avatar: "", repos: 0 })
    property var orgPrs: []
    property int orgPrCount: 0
    property int orgReviewCount: 0
    // [{ repo, name, state (ok, bad, run), branch, updated, url }], newest first
    property var orgRuns: []
    // [{ repo, title, number }] with the board's Status "In progress"
    property var orgBoard: []
    // Why the board is empty when GitHub did not say "nothing in progress"
    property string boardNote: ""
    property real orgFetchedAt: 0

    function addOrg(name) {
        // "facet-shell", "@facet-shell" or a github.com link
        const clean = String(name ?? "").trim().replace(/^@/, "").split("github.com/").pop().split("/")[0];
        if (clean === "" || !/^[A-Za-z0-9-]+$/.test(clean) || orgs.includes(clean))
            return false;
        Config.set("githubOrgs", orgs.concat([clean]));
        return true;
    }

    function removeOrg(name) {
        Config.set("githubOrgs", orgs.filter(o => o !== name));
    }

    // ── Connecting ───────────────────────────────────────────

    // gh's device flow without a terminal: gh prints the one-time code and the URL on stderr,
    // the tab shows the code and opens the page, gh finishes once GitHub says yes.
    // read:project comes along so the organisation's project board can be read too.
    function signIn() {
        startAuth("browser", ["gh", "auth", "login", "-h", "github.com", "-w", "-p", "https", "-s", "read:project"]);
    }

    // Adds read:project to the login gh already has
    function grantBoard() {
        startAuth("browser", ["gh", "auth", "refresh", "-h", "github.com", "-s", "read:project"]);
    }

    // A personal access token (classic: repo, read:org, read:project). It goes to gh over
    // stdin, never on a command line, and gh keeps it in the keyring like any other login.
    function useToken(token) {
        const clean = String(token ?? "").trim();
        if (clean === "" || authCall.running)
            return;
        authCall.token = clean;
        startAuth("token", ["gh", "auth", "login", "-h", "github.com", "-p", "https", "--with-token"]);
    }

    function cancelAuth() {
        if (authCall.running)
            authCall.signal(15);
        authState = "";
        authCode = "";
        authUrl = "";
    }

    function startAuth(kind, args) {
        if (authCall.running)
            return;
        authState = kind;
        authCode = "";
        authUrl = "";
        authError = "";
        authCall.stderrLines = [];
        authCall.stdinEnabled = kind === "token";
        authCall.command = args;
        authCall.running = true;
    }

    function authLine(line) {
        authCall.stderrLines.push(line);
        const code = line.match(/\b([A-Z0-9]{4}-[A-Z0-9]{4})\b/);
        if (code)
            authCode = code[1];
        const url = line.match(/https:\/\/\S+/);
        if (url && authUrl === "") {
            authUrl = url[0];
            Qt.openUrlExternally(authUrl);
        }
    }

    function authDone(code) {
        if (authState === "")
            return; // cancelled
        if (code !== 0) {
            authState = "failed";
            const lines = authCall.stderrLines.filter(l => l.trim() !== "" && !/one-time code|open this url|press enter/i.test(l));
            authError = (lines.pop() ?? `gh exited with ${code}`).replace(/^(gh: |error validating token: |X )/, "");
            return;
        }
        authState = "";
        authCode = "";
        authUrl = "";
        boardBlocked = false;
        // Ask again from the start: a new login can be another account
        status = "unknown";
        login = "";
        fetchedAt = 0;
        orgFetchedAt = 0;
        refresh(true);
    }

    // ── Asking ───────────────────────────────────────────────

    // force: also when the last answer is younger than two minutes
    function refresh(force) {
        if (check.running || me.running)
            return;
        if (!force && status === "ok" && Date.now() - fetchedAt < 120000)
            return;
        if (status !== "ok" || login === "")
            check.run(["sh", "-c", "command -v gh >/dev/null 2>&1 || exit 127; exec gh api user --jq .login"]);
        else
            askMe();
    }

    function refreshOrg(name, force) {
        if (status !== "ok" || name === "" || orgCall.running)
            return;
        if (!force && name === org && Date.now() - orgFetchedAt < 120000)
            return;
        if (name !== org) {
            orgPrs = [];
            orgRuns = [];
            orgBoard = [];
            orgInfo = { login: name, name: "", avatar: "", repos: 0 };
        }
        org = name;
        orgError = "";
        orgCall.run(["gh", "api", "graphql",
            "-f", `query=${boardBlocked ? orgQueryNoBoard : orgQuery}`,
            "-f", `org=${name}`,
            "-f", `qPrs=is:pr is:open org:${name} sort:updated-desc`,
            "-f", `qReview=is:pr is:open org:${name} review-requested:${login}`]);
        // The org name goes in as $1, never into the script itself
        runsCall.run(["sh", "-c", runsScript, "gh-runs", name]);
    }

    function askMe() {
        const from = new Date(Date.now() - 7 * 86400000).toISOString();
        me.run(["gh", "api", "graphql",
            "-f", `query=${meQuery}`,
            "-f", `from=${from}`,
            "-f", `qPrs=is:pr involves:${login} sort:updated-desc`,
            "-f", `qReview=is:pr is:open review-requested:${login} sort:updated-desc`,
            "-f", `qMention=is:open mentions:${login} sort:updated-desc`,
            "-f", `qAssigned=is:issue is:open assignee:${login} sort:updated-desc`]);
    }

    // gh exits 4 when it has no login; other failures (offline, rate limit) keep the login
    function failed(code, err) {
        if (code === 127) {
            status = "missing";
        } else if (code === 4 || /gh auth login|not logged in|authentication/i.test(err)) {
            status = "loggedOut";
            login = "";
        } else {
            status = status === "ok" ? "ok" : "error";
            error = (err.trim().split("\n")[0] || `gh exited with ${code}`).replace(/^gh: /, "");
        }
    }

    // GraphQL answers can carry data and errors at once (a missing token scope empties one
    // field only), so whatever data came is used
    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    // ── Shaping the answers ──────────────────────────────────

    function prOf(n) {
        if (!n || n.number === undefined || n.isDraft === undefined)
            return null;
        const state = n.state === "MERGED" ? "merged" : n.state === "CLOSED" ? "closed" : n.isDraft ? "draft" : "open";
        const roll = n.commits?.nodes?.[0]?.commit?.statusCheckRollup?.state ?? "";
        const ci = roll === "SUCCESS" ? "ok" : roll === "FAILURE" || roll === "ERROR" ? "bad" : roll === "PENDING" || roll === "EXPECTED" ? "run" : "";
        const review = state === "merged" || state === "closed" ? state
            : n.reviewDecision === "APPROVED" ? "approved"
            : n.reviewDecision === "CHANGES_REQUESTED" ? "changes"
            : n.reviewDecision === "REVIEW_REQUIRED" ? "waiting" : "";
        return {
            number: n.number, title: n.title ?? "", url: n.url ?? "", state, review, ci,
            repo: n.repository?.nameWithOwner ?? "", author: n.author?.login ?? "", updated: n.updatedAt ?? ""
        };
    }

    function itemOf(n, kind) {
        if (!n || n.number === undefined)
            return null;
        return { kind, title: n.title ?? "", number: n.number, repo: n.repository?.nameWithOwner ?? "", url: n.url ?? "", updated: n.updatedAt ?? "" };
    }

    function takeMe(code, out, err) {
        const answer = parse(out);
        const v = answer?.data?.viewer;
        if (!v) {
            failed(code === 0 ? 1 : code, err || (answer?.errors?.[0]?.message ?? ""));
            return;
        }
        status = "ok";
        error = "";
        login = v.login ?? login;
        name = v.name ?? "";
        avatar = v.avatarUrl ?? "";

        // The year as days, and what it says
        const cal = v.year?.contributionCalendar;
        const list = [];
        for (const w of cal?.weeks ?? [])
            for (const d of w.contributionDays ?? [])
                list.push({ date: d.date, count: d.contributionCount, weekday: d.weekday });
        days = list;
        contributions = cal?.totalContributions ?? 0;
        // Today without anything yet does not break the streak
        let run = 0;
        for (let i = list.length - 1; i >= 0; i--) {
            if (list[i].count > 0)
                run++;
            else if (i !== list.length - 1)
                break;
        }
        streak = run;
        const perDay = [0, 0, 0, 0, 0, 0, 0];
        for (const d of list)
            perDay[d.weekday] += d.count;
        const top = perDay.indexOf(Math.max(...perDay));
        busiestDay = contributions > 0 ? ["Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"][top] : "";

        const wk = v.week ?? {};
        week = {
            commits: wk.totalCommitContributions ?? 0,
            prs: wk.totalPullRequestContributions ?? 0,
            reviews: wk.totalPullRequestReviewContributions ?? 0,
            issues: wk.totalIssueContributions ?? 0
        };

        const data = answer.data;
        prs = (data.prs?.nodes ?? []).map(prOf).filter(p => p);
        reviewCount = data.review?.issueCount ?? 0;
        // A review request is also a mention now and then: each item once, the strongest kind
        const seen = {};
        const wait = [];
        for (const [key, kind] of [["review", "review"], ["assigned", "assigned"], ["mention", "mention"]])
            for (const n of data[key]?.nodes ?? []) {
                const item = itemOf(n, kind);
                if (item && !seen[item.url]) {
                    seen[item.url] = true;
                    wait.push(item);
                }
            }
        waiting = wait;

        // Bytes per language over the repos pushed in the last year
        const yearAgo = Date.now() - 365 * 86400000;
        const sizes = {}, colors = {};
        let total = 0;
        for (const repo of v.repositories?.nodes ?? []) {
            if (!repo || Date.parse(repo.pushedAt) < yearAgo)
                continue;
            for (const e of repo.languages?.edges ?? []) {
                sizes[e.node.name] = (sizes[e.node.name] ?? 0) + e.size;
                colors[e.node.name] = e.node.color;
                total += e.size;
            }
        }
        const sorted = Object.keys(sizes).sort((a, b) => sizes[b] - sizes[a]);
        const langs = sorted.slice(0, 5).map(n => ({ name: n, color: colors[n] ?? "", share: sizes[n] / total }));
        const rest = sorted.slice(5).reduce((sum, n) => sum + sizes[n], 0);
        if (rest > 0)
            langs.push({ name: "other", color: "", share: rest / total });
        languages = langs;

        fetchedAt = Date.now();
    }

    function takeOrg(code, out, err) {
        const answer = parse(out);
        const o = answer?.data?.organization;
        // Without read:project GitHub refuses the whole request, not only the board: once more
        // without it, and the tab offers to add the scope
        const scopeError = (answer?.errors ?? []).some(e => e.type === "INSUFFICIENT_SCOPES" || /read:project/.test(e.message ?? ""));
        if (!o && scopeError && !boardBlocked) {
            boardBlocked = true;
            Qt.callLater(() => root.refreshOrg(root.org, true));
            return;
        }
        if (!o) {
            orgError = answer?.errors?.[0]?.message ?? (err.trim().split("\n")[0] || `gh exited with ${code}`);
            if (code === 4)
                failed(code, err);
            return;
        }
        orgInfo = { login: o.login ?? org, name: o.name ?? "", avatar: o.avatarUrl ?? "", repos: o.repositories?.totalCount ?? 0 };
        orgPrs = (answer.data.prs?.nodes ?? []).map(prOf).filter(p => p);
        orgPrCount = answer.data.prs?.issueCount ?? orgPrs.length;
        orgReviewCount = answer.data.review?.issueCount ?? 0;

        // Every open board's items whose Status says "in progress"
        const board = [];
        for (const project of o.projectsV2?.nodes ?? []) {
            if (!project || project.closed)
                continue;
            for (const item of project.items?.nodes ?? []) {
                const st = item?.status?.name ?? "";
                if (!/progress|doing/i.test(st))
                    continue;
                const c = item.content ?? {};
                board.push({ repo: c.repository?.name ?? project.title, title: c.title ?? "", number: c.number ?? 0 });
            }
        }
        orgBoard = board;
        if (scopeError)
            boardBlocked = true;
        boardNote = boardBlocked ? "The board needs the read:project permission"
            : (o.projectsV2?.nodes ?? []).length === 0 ? "No project board" : "Nothing in progress";
        orgFetchedAt = Date.now();
    }

    function takeRuns(code, out) {
        const runs = [];
        for (const line of out.split("\n")) {
            const r = parse(line);
            if (!r)
                continue;
            const state = r.status !== "completed" ? "run" : r.conclusion === "success" ? "ok" : r.conclusion === "skipped" || r.conclusion === "neutral" ? "" : "bad";
            runs.push({ repo: r.repo ?? "", name: r.name ?? "", state, branch: r.branch ?? "", updated: r.updated ?? "", url: r.url ?? "" });
        }
        runs.sort((a, b) => Date.parse(b.updated) - Date.parse(a.updated));
        orgRuns = runs.slice(0, 6);
    }

    // "now", "12 min", "5 h", "yesterday", "3 d", "4 Oct"
    function ago(iso) {
        const t = Date.parse(iso);
        if (isNaN(t))
            return "";
        const s = (Date.now() - t) / 1000;
        if (s < 90)
            return "now";
        if (s < 3600)
            return `${Math.round(s / 60)} min`;
        if (s < 86400)
            return `${Math.round(s / 3600)} h`;
        if (s < 172800)
            return "yesterday";
        if (s < 30 * 86400)
            return `${Math.round(s / 86400)} d`;
        return new Date(t).toLocaleDateString(Qt.locale("en_GB"), "d MMM");
    }

    // ── The requests ─────────────────────────────────────────

    readonly property string prFields: "number title url state isDraft updatedAt reviewDecision author { login } repository { nameWithOwner } commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }"
    readonly property string itemFields: "... on Issue { number title url updatedAt repository { nameWithOwner } } ... on PullRequest { number title url updatedAt repository { nameWithOwner } }"

    readonly property string meQuery: [
        "query($from: DateTime!, $qPrs: String!, $qReview: String!, $qMention: String!, $qAssigned: String!) {",
        "  viewer {",
        "    login name avatarUrl",
        "    year: contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount weekday } } } }",
        "    week: contributionsCollection(from: $from) { totalCommitContributions totalPullRequestContributions totalPullRequestReviewContributions totalIssueContributions }",
        "    repositories(first: 50, isFork: false, ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER], orderBy: { field: PUSHED_AT, direction: DESC }) {",
        "      nodes { pushedAt languages(first: 6, orderBy: { field: SIZE, direction: DESC }) { edges { size node { name color } } } }",
        "    }",
        "  }",
        "  prs: search(query: $qPrs, type: ISSUE, first: 8) { issueCount nodes { ... on PullRequest { " + prFields + " } } }",
        "  review: search(query: $qReview, type: ISSUE, first: 5) { issueCount nodes { " + itemFields + " } }",
        "  mention: search(query: $qMention, type: ISSUE, first: 5) { issueCount nodes { " + itemFields + " } }",
        "  assigned: search(query: $qAssigned, type: ISSUE, first: 5) { issueCount nodes { " + itemFields + " } }",
        "}"
    ].join("\n")

    readonly property string orgQuery: [
        "query($org: String!, $qPrs: String!, $qReview: String!) {",
        "  organization(login: $org) {",
        "    login name avatarUrl",
        "    repositories(first: 1) { totalCount }",
        "    projectsV2(first: 5, orderBy: { field: UPDATED_AT, direction: DESC }) {",
        "      nodes { title closed items(first: 100) { nodes {",
        '        status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }',
        "        content { ... on Issue { title number repository { name } } ... on PullRequest { title number repository { name } } ... on DraftIssue { title } }",
        "      } } }",
        "    }",
        "  }",
        "  prs: search(query: $qPrs, type: ISSUE, first: 8) { issueCount nodes { ... on PullRequest { " + prFields + " } } }",
        "  review: search(query: $qReview, type: ISSUE, first: 1) { issueCount }",
        "}"
    ].join("\n")

    // The same without the project board, for a login without read:project
    readonly property string orgQueryNoBoard: orgQuery.replace(/    projectsV2[\s\S]*?\n    \}\n/, "")

    // The newest runs of the six repos pushed last, one JSON object per line
    readonly property string runsScript: [
        'gh api "orgs/$1/repos?sort=pushed&per_page=6" --jq ".[] | select(.archived | not) | .name" |',
        "while read -r repo; do",
        '  gh api "repos/$1/$repo/actions/runs?per_page=3" --jq ".workflow_runs[] | {repo: .repository.name, name, status, conclusion, branch: .head_branch, updated: .updated_at, url: .html_url} | @json"',
        "done"
    ].join("\n")

    // ── Processes ────────────────────────────────────────────

    // A gh call that hands over exit code, stdout and stderr once all three are in (the
    // exit and the end of the streams come in any order)
    component GhCall: Process {
        id: call

        property var handler: null
        property int code: -1
        property bool outDone: false
        property bool errDone: false
        property bool handed: false

        function run(args) {
            if (running)
                return;
            code = -1;
            outDone = false;
            errDone = false;
            handed = false;
            command = args;
            running = true;
        }

        function finish() {
            if (handed || code < 0 || !outDone || !errDone)
                return;
            handed = true;
            if (handler)
                handler(code, outText.text, errText.text);
        }

        stdout: StdioCollector {
            id: outText
            onStreamFinished: {
                call.outDone = true;
                call.finish();
            }
        }
        stderr: StdioCollector {
            id: errText
            onStreamFinished: {
                call.errDone = true;
                call.finish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            call.code = exitCode;
            call.finish();
        }
    }

    GhCall {
        id: check
        handler: (code, out, err) => {
            if (code === 0 && out.trim() !== "") {
                root.login = out.trim();
                root.status = "ok";
                root.askMe();
            } else {
                root.failed(code, err);
            }
        }
    }

    GhCall {
        id: me
        handler: (code, out, err) => root.takeMe(code, out, err)
    }

    GhCall {
        id: orgCall
        handler: (code, out, err) => root.takeOrg(code, out, err)
    }

    Process {
        id: authCall

        property string token: ""
        property var stderrLines: []

        // gh reads the token from stdin; closing stdin tells it that was all
        onStarted: {
            if (stdinEnabled) {
                write(token + "\n");
                token = "";
                stdinEnabled = false;
            }
        }
        stdout: SplitParser {
            onRead: line => root.authLine(line)
        }
        stderr: SplitParser {
            onRead: line => root.authLine(line)
        }
        onExited: (exitCode, exitStatus) => root.authDone(exitCode)
    }

    GhCall {
        id: runsCall
        handler: (code, out, err) => root.takeRuns(code, out)
    }
}
