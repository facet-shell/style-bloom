import QtQuick
import qs.config

// Text, saved on Enter or when the field loses focus; list: comma separated into an array.
ConfigRow {
    id: txt

    property string placeholder: ""
    property bool list: false
    readonly property string current: list ? (Config[key] ?? []).join(", ") : String(Config[key] ?? "")

    function commit() {
        const v = field.text.trim();
        if (v === current)
            return;
        Config.set(key, list ? v.split(",").map(s => s.trim()).filter(s => s !== "") : v);
    }

    TextBox {
        id: field

        text: txt.current
        placeholder: txt.placeholder
        onAccepted: txt.commit()
        onFinished: txt.commit()
    }
}
