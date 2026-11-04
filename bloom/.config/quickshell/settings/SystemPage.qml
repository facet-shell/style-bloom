import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

// System: updates, the boot splash and the login screen (sudo, in a terminal), checking and
// cleaning up, what runs (about) and the settings file itself.
ColumnLayout {
    id: page

    required property Item view

    spacing: Theme.spacing.medium

    PageHeading {
        text: "Updates"
    }

    ConfigRow {
        title: "Updates"
        icon: "system_update"
        subtitle: {
            const parts = [];
            if (Updates.total > 0)
                parts.push(`${Updates.total} packages waiting (${Updates.aurCount} from the AUR)`);
            if (Updates.frameCount > 0)
                parts.push(`facet: ${Updates.frameList.map(r => `${r.name} ${r.from} → ${r.to}`).join(", ")}`);
            return parts.length > 0 ? `${parts.join("; ")}, then facet update` : Updates.checking ? "checking…" : "everything is up to date";
        }

        Button {
            text: Updates.updating ? "Updating…" : "Update now"
            icon: "download"
            variant: "filled"
            disabled: Updates.updating
            onClicked: Updates.update()
        }
    }
    ConfigSwitch {
        key: "frameUpdates"
        title: "facet updates"
        subtitle: "count the CLI and the modules behind GitHub in the bar too"
    }

    PageHeading {
        text: "Boot and login"
    }

    ConfigRow {
        title: "Boot splash and console colors"
        subtitle: "Plymouth and the text consoles in the theme (needs sudo)"
        icon: "power_settings_new"

        Button {
            text: "Install"
            variant: "tonal"
            onClicked: page.view.inTerminal("facet boot install", [page.view.facet, "boot", "install"])
        }
        Button {
            text: "Remove"
            variant: "plain"
            onClicked: page.view.inTerminal("facet boot remove", [page.view.facet, "boot", "remove"])
        }
    }
    ConfigRow {
        title: "Login screen"
        subtitle: "the lockscreen look at boot, straight into the locked desktop, or the distro's own (greetd, needs sudo)"
        icon: "login"

        Button {
            text: "Login screen"
            variant: "tonal"
            onClicked: page.view.inTerminal("facet login install", [page.view.facet, "login", "install"])
        }
        Button {
            text: "Auto"
            variant: "plain"
            onClicked: page.view.inTerminal("facet login auto", [page.view.facet, "login", "auto"])
        }
        Button {
            text: "Distro's"
            variant: "plain"
            onClicked: page.view.inTerminal("facet login remove", [page.view.facet, "login", "remove"])
        }
    }

    PageHeading {
        text: "Housekeeping"
    }

    ConfigRow {
        title: "Check and clean"
        subtitle: "what is installed and missing; caches and leftovers facet can remove"
        icon: "cleaning_services"

        Button {
            text: "Status"
            variant: "plain"
            onClicked: page.view.inTerminal("facet status", [page.view.facet, "status"])
        }
        Button {
            text: "Clean"
            variant: "plain"
            onClicked: page.view.inTerminal("facet clean", [page.view.facet, "clean"])
        }
    }
    ConfigRow {
        title: "Settings file"
        subtitle: Config.file.replace(page.view.home, "~")
        icon: "description"

        Button {
            text: "Open"
            icon: "open_in_new"
            variant: "plain"
            onClicked: Quickshell.execDetached(["xdg-open", Config.file])
        }
    }

    PageHeading {
        text: "About"
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: aboutText.implicitHeight + Theme.padding.card * 2
        radius: Theme.rounding.medium
        color: Theme.container

        StyledText {
            id: aboutText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.padding.card
            text: [`bloom · ${Theme.name}`, page.view.about].filter(s => s !== "").join("\n")
            dim: true
            font.family: Theme.mono
            font.pixelSize: Theme.size.small
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
