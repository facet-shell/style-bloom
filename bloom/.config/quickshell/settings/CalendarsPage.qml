import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// Calendars: the iCloud and Google accounts the dashboard's calendar shows, and connecting new
// ones without a terminal. The work runs in services/Calendar.qml (facet-calendar underneath),
// so a Google login waiting in the browser survives leaving this page. The iCloud password
// goes to the helper over stdin, never on its command line. One block per page (view.page).
ColumnLayout {
    id: page

    required property Item view
    readonly property string sub: view.page

    // A file chooser, if one is installed: "zenity", "kdialog" or ""
    property string chooser: ""

    spacing: Theme.spacing.medium

    Component.onCompleted: {
        if (sub === "accounts")
            Calendar.checkAccounts(false);
        if (sub === "google") {
            chooserProbe.running = true;
            if (Calendar.connecting !== "google")
                latestClient.running = true;
        }
    }

    // ── Accounts ──

    StyledText {
        Layout.fillWidth: true
        visible: page.sub === "accounts"
        text: Calendar.checking ? "asking each account …" : "the dashboard's calendar shows every calendar of these accounts"
        dim: true
        font.pixelSize: Theme.size.small
    }

    Repeater {
        model: page.sub === "accounts" ? Calendar.accountList : []

        delegate: ConfigRow {
            id: acc

            required property var modelData
            property bool confirm: false

            title: modelData.name
            subtitle: {
                const kind = modelData.kind === "google" ? "Google" : "iCloud";
                if (!modelData.ok)
                    return `${kind} · ${modelData.error}`;
                if (modelData.calendars.length === 0)
                    return Calendar.checking ? `${kind} · checking …` : `${kind} · no calendars`;
                return `${kind} · ${modelData.calendars.join(", ")}`;
            }
            icon: !modelData.ok ? "sync_problem" : modelData.kind === "google" ? "account_circle" : "cloud"

            Button {
                visible: !acc.confirm
                text: "Remove"
                icon: "delete"
                variant: "plain"
                disabled: Calendar.removing
                onClicked: acc.confirm = true
            }
            Button {
                visible: acc.confirm
                text: "Cancel"
                variant: "text"
                onClicked: acc.confirm = false
            }
            Button {
                visible: acc.confirm
                text: "Remove"
                icon: "delete"
                variant: "danger"
                disabled: Calendar.removing
                onClicked: {
                    acc.confirm = false;
                    Calendar.removeAccount(acc.modelData.key);
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: page.sub === "accounts" && Calendar.removeError !== ""
        text: Calendar.removeError
        color: Theme.error
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.size.small
    }

    ConfigRow {
        visible: page.sub === "accounts" && Calendar.accountList.length === 0 && !Calendar.checking
        title: "No calendar connected yet"
        subtitle: "iCloud with an app-specific password, Google with your own OAuth client"
        icon: "calendar_month"

        Button {
            text: "iCloud"
            icon: "cloud"
            variant: "tonal"
            onClicked: page.view.openPage("icloud")
        }
        Button {
            text: "Google"
            icon: "account_circle"
            variant: "tonal"
            onClicked: page.view.openPage("google")
        }
    }

    ConfigRow {
        visible: page.sub === "accounts" && Calendar.accountList.length > 0
        title: "Check again"
        subtitle: "asks each account for its calendars, shows a wrong password"
        icon: "sync"

        Button {
            text: "Check"
            icon: "sync"
            variant: "plain"
            disabled: Calendar.checking
            onClicked: Calendar.checkAccounts(false)
        }
    }

    // ── iCloud ──

    Steps {
        visible: page.sub === "icloud"
        lines: [
            "Open appleid.apple.com and sign in",
            "Sign-In and Security → App-Specific Passwords: make one, name it facet",
            "Enter your Apple ID and that password here; your normal Apple ID password does not work"
        ]
        link: "Open appleid.apple.com"
        url: "https://appleid.apple.com"
    }

    ConfigRow {
        visible: page.sub === "icloud"
        title: "Apple ID"
        subtitle: "the mail you sign in to iCloud with"
        icon: "alternate_email"

        TextBox {
            id: appleId

            placeholder: "name@icloud.com"
            onAccepted: password.input.forceActiveFocus()
        }
    }
    ConfigRow {
        visible: page.sub === "icloud"
        title: "App-specific password"
        subtitle: "xxxx-xxxx-xxxx-xxxx; kept in the keyring, nowhere else"
        icon: "key"

        TextBox {
            id: password

            placeholder: "xxxx-xxxx-xxxx-xxxx"
            input.echoMode: TextInput.Password
            input.passwordCharacter: "•"
            onAccepted: page.connectIcloud()
        }
    }
    ConfigRow {
        visible: page.sub === "icloud"
        title: Calendar.connecting === "icloud" ? "Connecting …" : "Connect"
        subtitle: page.resultOf("icloud")
        icon: page.iconOf("icloud")

        Button {
            text: "Connect"
            icon: "link"
            variant: "filled"
            disabled: Calendar.connecting !== "" || appleId.text.trim() === "" || password.text.trim() === ""
            onClicked: page.connectIcloud()
        }
    }

    // ── Google ──

    Steps {
        visible: page.sub === "google"
        lines: [
            "In the Google Cloud console, make a project (any name)",
            "APIs and services → Library: enable the Google Calendar API",
            "OAuth consent screen: user type External, then add yourself under Test users",
            "Credentials (Clients) → Create OAuth client → Desktop app, then download its JSON",
            "Pick that file here and press Connect: the browser opens, allow the calendar access"
        ]
        link: "Open the Cloud console"
        url: "https://console.cloud.google.com/apis/library/calendar-json.googleapis.com"
    }

    ConfigRow {
        visible: page.sub === "google"
        title: "Client file"
        subtitle: "the client_secret_….json Google hands out; only read while connecting"
        icon: "description"

        TextBox {
            id: clientFile

            implicitWidth: 320
            placeholder: "~/Downloads/client_secret_….json"
            onAccepted: page.connectGoogle()
        }
        Button {
            visible: page.chooser !== ""
            text: "Choose"
            icon: "folder_open"
            variant: "plain"
            disabled: chooseCall.running
            onClicked: {
                chooseCall.command = page.chooser === "zenity"
                    ? ["zenity", "--file-selection", "--title=Google OAuth client JSON", "--file-filter=JSON | *.json", `--filename=${Quickshell.env("HOME")}/Downloads/`]
                    : ["kdialog", "--title", "Google OAuth client JSON", "--getopenfilename", `${Quickshell.env("HOME")}/Downloads`, "*.json"];
                chooseCall.running = true;
            }
        }
    }
    ConfigRow {
        visible: page.sub === "google"
        title: Calendar.connecting === "google" ? "Waiting for the login in the browser …" : "Connect"
        subtitle: page.resultOf("google")
        icon: page.iconOf("google")

        Button {
            visible: Calendar.connecting === "google" && Calendar.connectUrl !== ""
            text: "Open login again"
            icon: "open_in_new"
            variant: "plain"
            onClicked: Qt.openUrlExternally(Calendar.connectUrl)
        }
        Button {
            visible: Calendar.connecting === "google"
            text: "Cancel"
            variant: "text"
            onClicked: Calendar.cancelConnect()
        }
        Button {
            visible: Calendar.connecting !== "google"
            text: "Connect"
            icon: "link"
            variant: "filled"
            disabled: Calendar.connecting !== "" || clientFile.text.trim() === ""
            onClicked: page.connectGoogle()
        }
    }

    // ── Shared ──

    function connectIcloud() {
        if (Calendar.connecting !== "" || appleId.text.trim() === "" || password.text.trim() === "")
            return;
        Calendar.connectIcloud(appleId.text, password.text);
    }

    function connectGoogle() {
        if (Calendar.connecting !== "" || clientFile.text.trim() === "")
            return;
        Calendar.connectGoogle(clientFile.text);
    }

    // The line under Connect: what the helper does, its error, or what got connected
    function resultOf(kind) {
        if (Calendar.connecting === kind)
            return Calendar.connectStatus || "starting …";
        if (Calendar.lastKind !== kind)
            return kind === "google" ? "opens the browser to sign in to Google" : "checks the password with iCloud first";
        if (Calendar.connectError !== "")
            return Calendar.connectError;
        return Calendar.connected !== "" ? `${Calendar.connected} The dashboard shows it now.` : "";
    }

    function iconOf(kind) {
        if (Calendar.connecting === kind)
            return "hourglass_top";
        if (Calendar.lastKind === kind && Calendar.connectError !== "")
            return "error";
        if (Calendar.lastKind === kind && Calendar.connected !== "")
            return "check_circle";
        return "link";
    }

    // The password field is emptied once iCloud took it
    Connections {
        target: Calendar

        function onConnectedChanged() {
            if (Calendar.connected !== "" && Calendar.lastKind === "icloud")
                password.text = "";
        }
    }

    // Numbered steps in a card, with a button to the page they start on
    component Steps: Rectangle {
        id: steps

        property var lines: []
        property string link: ""
        property string url: ""

        Layout.fillWidth: true
        implicitHeight: stepsColumn.implicitHeight + Theme.padding.card * 2
        radius: Theme.rounding.medium
        color: Theme.container

        ColumnLayout {
            id: stepsColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.padding.card
            spacing: Theme.spacing.small

            Repeater {
                model: steps.lines

                delegate: RowLayout {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    StyledText {
                        Layout.alignment: Qt.AlignTop
                        text: `${index + 1}.`
                        color: Theme.primary
                        tabular: true
                        font.pixelSize: Theme.size.small
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData
                        dim: true
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        font.pixelSize: Theme.size.small
                    }
                }
            }

            Button {
                Layout.topMargin: Theme.spacing.small
                visible: steps.link !== ""
                text: steps.link
                icon: "open_in_new"
                variant: "tonal"
                onClicked: Qt.openUrlExternally(steps.url)
            }
        }
    }

    // zenity or kdialog, whichever is there
    Process {
        id: chooserProbe

        command: ["sh", "-c", "command -v zenity >/dev/null && echo zenity || { command -v kdialog >/dev/null && echo kdialog; }"]
        stdout: StdioCollector {
            onStreamFinished: page.chooser = text.trim()
        }
    }

    Process {
        id: chooseCall

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    clientFile.text = text.trim();
            }
        }
    }

    // The newest client_secret*.json in Downloads, filled in when the field is empty
    Process {
        id: latestClient

        command: ["sh", "-c", 'ls -t "$HOME"/Downloads/client_secret*.json 2>/dev/null | head -n 1']
        stdout: StdioCollector {
            onStreamFinished: {
                if (clientFile.text === "" && text.trim() !== "")
                    clientFile.text = text.trim();
            }
        }
    }
}
