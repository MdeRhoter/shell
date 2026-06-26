import QtQuick.Layouts
import Caelestia.Config
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
        text: IdleInhibitor.enabled
            ? qsTr("Active since %1").arg(Qt.formatTime(IdleInhibitor.enabledSince, GlobalConfig.services.useTwelveHourClock ? "hh:mm a" : "hh:mm"))
            : qsTr("Normal power management")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    SwitchRow {
        label: qsTr("Prevent sleep")
        checked: IdleInhibitor.enabled
        onToggled: IdleInhibitor.enabled = checked
    }
}
