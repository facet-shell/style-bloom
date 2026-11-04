import QtQuick
import qs.components
import qs.config
import qs.services

// Top right of the lockscreen: the weather in one line, "9° · Würzburg" after its icon.
// The Weather service's icons are Nerd Font glyphs, so the Material Symbol is picked here
// from its description.
Row {
    id: root

    function symbol(description, night) {
        const d = description ?? "";
        if (/thunder/.test(d))
            return "thunderstorm";
        if (/snow|sleet|blizzard|ice|pellets/.test(d))
            return "weather_snowy";
        if (/rain|drizzle|shower/.test(d))
            return "rainy";
        if (/fog|mist|haze/.test(d))
            return "foggy";
        if (/overcast/.test(d))
            return "cloud";
        if (/partly|patchy/.test(d))
            return night ? "partly_cloudy_night" : "partly_cloudy_day";
        if (/cloud/.test(d))
            return "cloud";
        if (/sun|clear/.test(d))
            return night ? "clear_night" : "sunny";
        return night ? "partly_cloudy_night" : "partly_cloudy_day";
    }

    // The service keeps the place in lower case; a place name reads better capitalised
    function place(text) {
        return (text ?? "").split(" ").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    }

    spacing: Theme.spacing.normal

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.symbol(Weather.description, Weather.isNight())
        size: Theme.icon.large
        color: Theme.tertiary
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.location !== "" ? `${Weather.temp}° · ${root.place(Weather.location)}` : `${Weather.temp}°`
        font.pixelSize: Theme.size.medium - 1
    }
}
