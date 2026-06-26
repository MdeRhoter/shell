import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.normal

    readonly property string groupLabel: WorkspaceNameConfig.nameForWorkspace(Hypr.activeWsId)

    readonly property var specialWindows: Hypr.toplevels.values.filter(t => t.workspace?.name.startsWith("special:"))

    StyledText {
        text: root.groupLabel
        font.weight: Font.Medium
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colours.palette.m3outline
        opacity: 0.3
    }

    StyledText {
        visible: root.specialWindows.length === 0
        text: qsTr("Special workspace is empty")
        opacity: 0.6
        font.pointSize: Tokens.font.size.smaller
    }

    Repeater {
        model: ScriptModel {
            values: root.specialWindows
        }

        StyledText {
            required property var modelData

            text: `\u2022 ${modelData.lastIpcObject.class || "Unknown"}: ${modelData.title || "No title"}`
            font.family: Tokens.font.family.mono
            font.pointSize: Tokens.font.size.smaller
        }
    }
}
