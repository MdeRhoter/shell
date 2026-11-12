import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    spacing: Tokens.spacing.small

    StyledText {
        text: qsTr("Keep Awake")
        font: Tokens.font.body.medium
    }

    StyledText {
        text: RuntimeState.inhibitIdle
            ? qsTr("Active since %1").arg(Tr.formatDateTime(new Date(RuntimeState.inhibitingIdleSince), Units.twelveHourClock ? "hh:mm a" : "hh:mm"))
            : qsTr("Normal power management")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    SwitchRow {
        label: qsTr("Prevent sleep")
        checked: RuntimeState.inhibitIdle
        onToggled: RuntimeState.inhibitIdle = checked
    }
}
