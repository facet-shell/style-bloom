import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config
import qs.media
import qs.services

// The dashboard's first tab: the weather on the left with the next hours, media and the
// short GitHub card in the middle (its play button in the cover's accent, AlbumColor), the
// month and the next timer or alarm on the right.
RowLayout {
    id: root

    property MprisPlayer player: null
    property var github: null

    signal githubRequested()
    signal mediaRequested()

    spacing: Theme.spacing.medium

    // Weather's Nerd Font glyphs (services/Weather.qml) as Material Symbols
    function weatherSymbol(glyph) {
        const code = glyph ? glyph.codePointAt(0) : 0;
        switch (code) {
        case 0xe30d:
            return "sunny";
        case 0xe32b:
            return "clear_night";
        case 0xe302:
            return "partly_cloudy_day";
        case 0xe312:
            return "cloud";
        case 0xe313:
            return "foggy";
        case 0xe31d:
            return "thunderstorm";
        case 0xe3ad:
            return "weather_mix";
        case 0xe31a:
            return "weather_snowy";
        case 0xe318:
        case 0xe319:
            return "rainy";
        default:
            return "partly_cloudy_day";
        }
    }

    // ── Weather ──────────────────────────────────────────────

    Card {
        Layout.preferredWidth: 220
        Layout.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Weather.ready ? Weather.location.split(" ").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ") : "Weather"
                dim: true
                font.pixelSize: Theme.size.small
            }
            Icon {
                Layout.topMargin: Theme.spacing.small
                icon: Weather.ready ? root.weatherSymbol(Weather.icon) : "cloud_sync"
                size: 64
                weight: 400
                color: Theme.tertiary
            }
            StyledText {
                text: Weather.ready ? `${Weather.temp}°` : "–"
                tabular: true
                font.pixelSize: Theme.size.display
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                text: Weather.ready ? `${Weather.description} · ${Weather.low}° to ${Weather.high}°` : "wttr.in has not answered yet"
                dim: true
                font.pixelSize: Theme.size.small
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            // The next hours
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.medium
                visible: Weather.hours.length > 0
                spacing: Theme.spacing.small

                Repeater {
                    model: Weather.hours

                    Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: hourColumn.implicitHeight + Theme.spacing.large
                        radius: Theme.rounding.normal
                        color: Theme.high

                        ColumnLayout {
                            id: hourColumn

                            anchors.centerIn: parent
                            spacing: Theme.spacing.small

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.time.slice(0, 2)
                                dim: true
                                tabular: true
                                font.pixelSize: Theme.size.tiny
                            }
                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: root.weatherSymbol(modelData.icon)
                                size: 20
                                color: Theme.secondary
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: `${modelData.temp}°`
                                tabular: true
                                font.pixelSize: Theme.size.tiny
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // ── Media and GitHub ─────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Theme.spacing.medium

        Card {
            Layout.fillWidth: true
            interactive: true
            onClicked: root.mediaRequested()

            RowLayout {
                anchors.fill: parent
                spacing: 14

                ClippingRectangle {
                    implicitWidth: 80
                    implicitHeight: 80
                    radius: Theme.rounding.medium + 2
                    color: Theme.high

                    Image {
                        id: cover

                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        icon: root.player ? "music_note" : "music_off"
                        size: Theme.icon.large
                        dim: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || root.player.identity) : "Nothing plays"
                        font.pixelSize: Theme.size.normal + 1
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackArtist || root.player.identity) : "Music and videos show up here"
                        dim: true
                        font.pixelSize: Theme.size.small
                    }
                    RowLayout {
                        visible: root.player !== null
                        Layout.topMargin: Theme.spacing.normal
                        spacing: 6

                        IconButton {
                            icon: "skip_previous"
                            size: Theme.control.button
                            restColor: Theme.high
                            disabled: !(root.player?.canGoPrevious ?? false)
                            onClicked: root.player.previous()
                        }
                        IconButton {
                            icon: root.player?.isPlaying ? "pause" : "play_arrow"
                            size: Theme.control.button
                            filled: true
                            fillColor: AlbumColor.accent
                            iconColor: AlbumColor.textOnAccent
                            active: root.player?.isPlaying ?? false
                            onClicked: root.player.togglePlaying()
                        }
                        IconButton {
                            icon: "skip_next"
                            size: Theme.control.button
                            restColor: Theme.high
                            disabled: !(root.player?.canGoNext ?? false)
                            onClicked: root.player.next()
                        }
                    }
                }
            }
        }

        // The short GitHub card: your two newest PRs; a click opens the GitHub tab
        Card {
            Layout.fillWidth: true
            interactive: true
            onClicked: root.githubRequested()

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.normal

                    Icon {
                        icon: "commit"
                        size: 20
                        color: Theme.primary
                    }
                    StyledText {
                        text: "GitHub"
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        dim: true
                        font.pixelSize: Theme.size.small
                        text: {
                            const gh = root.github;
                            if (!gh || gh.status !== "ok")
                                return "";
                            const parts = [];
                            if (gh.reviewCount > 0)
                                parts.push(gh.reviewCount === 1 ? "1 review waits on you" : `${gh.reviewCount} reviews wait on you`);
                            if (gh.streak > 1)
                                parts.push(`${gh.streak} days in a row`);
                            return parts.join(" · ");
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    dim: true
                    font.pixelSize: Theme.size.small
                    wrapMode: Text.WordWrap
                    text: {
                        const gh = root.github;
                        if (!gh)
                            return "";
                        if (gh.status === "missing")
                            return "Needs the GitHub CLI (gh)";
                        if (gh.status === "loggedOut")
                            return "Log in once with: gh auth login";
                        if (gh.status === "error")
                            return gh.error;
                        if (gh.status !== "ok")
                            return "Asking GitHub …";
                        return gh.prs.length === 0 ? "No pull requests of yours" : "";
                    }
                }

                Repeater {
                    model: root.github?.status === "ok" ? root.github.prs.slice(0, 2) : []

                    PrRow {
                        required property var modelData
                        required property int index

                        first: index === 0
                        icon: modelData.state === "merged" ? "done_all" : modelData.state === "draft" ? "draft" : modelData.state === "closed" ? "close" : "merge"
                        tone: modelData.state
                        title: modelData.title
                        meta: `${modelData.repo.split("/").pop()} #${modelData.number} · ${root.github.ago(modelData.updated)}`
                        review: modelData.review === "merged" ? "" : modelData.review
                        ci: modelData.ci
                        url: modelData.url
                    }
                }
            }
        }
    }

    // ── Calendar and daylight ────────────────────────────────

    ColumnLayout {
        Layout.preferredWidth: 250
        Layout.maximumWidth: 250
        Layout.alignment: Qt.AlignTop
        spacing: Theme.spacing.medium

        Card {
            id: calendar

            // Months away from this one; the wheel pages, a click on the title comes back
            property int shift: 0
            readonly property date today: clock.date
            readonly property date month: new Date(today.getFullYear(), today.getMonth() + shift, 1)
            readonly property int lead: (month.getDay() + 6) % 7
            readonly property int length: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
            readonly property int before: new Date(month.getFullYear(), month.getMonth(), 0).getDate()
            // Whole weeks, Monday first, with the neighbours' days dimmed
            readonly property var cells: {
                const list = [];
                const weeks = Math.ceil((lead + length) / 7);
                for (let i = 0; i < weeks * 7; i++) {
                    const day = i - lead + 1;
                    const inside = day >= 1 && day <= length;
                    list.push({
                        text: String(inside ? day : day < 1 ? before + day : day - length),
                        inside,
                        today: inside && shift === 0 && day === today.getDate()
                    });
                }
                return list;
            }

            Layout.fillWidth: true

            SystemClock {
                id: clock
                precision: SystemClock.Hours
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => calendar.shift += event.angleDelta.y > 0 ? -1 : 1
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacing.small + 2

                StyledText {
                    text: calendar.month.toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy")
                    color: calendar.shift === 0 ? Theme.dim : Theme.primary
                    font.pixelSize: Theme.size.small

                    MouseArea {
                        anchors.fill: parent
                        enabled: calendar.shift !== 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendar.shift = 0
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 3
                    rowSpacing: 3

                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]

                        StyledText {
                            required property string modelData

                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.secondary
                            font.pixelSize: Theme.size.tiny
                            font.weight: Font.DemiBold
                        }
                    }

                    Repeater {
                        model: calendar.cells

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: height / 2
                            color: modelData.today ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.text
                                tabular: true
                                opacity: modelData.inside ? 1 : 0.35
                                color: modelData.today ? Theme.textOnPrimary : Theme.dim
                                font.pixelSize: Theme.size.tiny
                                font.weight: modelData.today ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }
        }

        // Daylight: sunrise and sunset from the weather, and how much of the day is left
        Card {
            id: sun

            // Minutes since midnight, a tick a minute is plenty
            property int now: minutesOf(Qt.formatTime(new Date(), "hh:mm"))
            readonly property int rise: minutesOf(Weather.sunrise)
            readonly property int set: minutesOf(Weather.sunset)
            readonly property bool known: rise >= 0 && set > rise
            readonly property bool day: known && now >= rise && now < set
            readonly property bool beforeDawn: known && now < rise

            function minutesOf(hhmm) {
                const m = String(hhmm ?? "").match(/^(\d{1,2}):(\d{2})$/);
                return m ? Number(m[1]) * 60 + Number(m[2]) : -1;
            }

            function span(minutes) {
                const h = Math.floor(minutes / 60), m = minutes % 60;
                return h > 0 ? `${h} h ${m} min` : `${m} min`;
            }

            Layout.fillWidth: true
            visible: known

            Timer {
                running: sun.visible
                repeat: true
                interval: 60000
                onTriggered: sun.now = sun.minutesOf(Qt.formatTime(new Date(), "hh:mm"))
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    Rectangle {
                        implicitWidth: Theme.control.button
                        implicitHeight: Theme.control.button
                        radius: Theme.rounding.normal
                        color: sun.day ? Theme.secondaryContainer : Theme.high

                        Icon {
                            anchors.centerIn: parent
                            icon: sun.day ? "wb_twilight" : "bedtime"
                            size: 20
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            font.weight: Font.DemiBold
                            tabular: true
                            text: sun.day ? `Sunset at ${Weather.sunset}` : `Sunrise at ${Weather.sunrise}`
                        }
                        StyledText {
                            Layout.fillWidth: true
                            dim: true
                            tabular: true
                            elide: Text.ElideRight
                            font.pixelSize: Theme.size.small
                            text: sun.day ? `${sun.span(sun.set - sun.now)} of daylight left`
                                : sun.beforeDawn ? `in ${sun.span(sun.rise - sun.now)}`
                                : `dark since ${Weather.sunset}`
                        }
                    }
                }

                // The day from sunrise to sunset, filled as far as it has come
                ProgressBar {
                    Layout.fillWidth: true
                    thickness: 4
                    value: sun.day ? (sun.now - sun.rise) / (sun.set - sun.rise) : sun.beforeDawn ? 0 : 1
                    color: sun.day ? Theme.primary : Theme.dim
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        dim: true
                        tabular: true
                        font.pixelSize: Theme.size.small
                        text: Weather.sunrise
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        dim: true
                        font.pixelSize: Theme.size.small
                        opacity: 0.7
                        text: `${sun.span(sun.set - sun.rise)} of light`
                    }
                    StyledText {
                        dim: true
                        tabular: true
                        font.pixelSize: Theme.size.small
                        text: Weather.sunset
                    }
                }
            }
        }
    }
}
