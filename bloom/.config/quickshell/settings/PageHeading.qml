import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// A group's heading in a settings page: small capitals in primary, like the mockup's h4.
// `sub: true` is the lighter one inside a group (Discord, Steam under the rules).
StyledText {
    property bool sub: false

    Layout.fillWidth: true
    Layout.topMargin: sub ? Theme.spacing.small : Theme.spacing.medium
    color: sub ? Theme.secondary : Theme.primary
    font.pixelSize: Theme.size.small
    font.weight: Font.DemiBold
    font.capitalization: sub ? Font.MixedCase : Font.AllUppercase
    font.letterSpacing: sub ? 0 : 0.4
}
