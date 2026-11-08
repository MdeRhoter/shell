import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.small

    StyledText {
        text: Updates.loading
            ? qsTr("Checking for updates\u2026")
            : Updates.error.length > 0
                ? qsTr("Update check failed")
                : Updates.count > 0
                    ? qsTr("%1 pending update%2").arg(Updates.count).arg(Updates.count === 1 ? "" : "s")
                    : qsTr("System is up to date")
        color: !Updates.loading && Updates.error.length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurface
        font.weight: Font.Medium
    }

    StyledText {
        Layout.maximumWidth: 400
        visible: !Updates.loading && Updates.error.length > 0
        text: Updates.error
        wrapMode: Text.Wrap
        color: Colours.palette.m3error
        font: Tokens.font.mono.small
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colours.palette.m3outline
        opacity: 0.3
        visible: !Updates.loading && Updates.count > 0
    }

    Repeater {
        model: ScriptModel {
            values: Updates.updates
        }

        StyledText {
            required property var modelData

            text: `${modelData.name}  ${modelData.oldVer} \u2192 ${modelData.newVer}`
            font: Tokens.font.mono.small
        }
    }
}
