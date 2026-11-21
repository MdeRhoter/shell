import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
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

    // A plain Repeater grew the popout past the screen edge with 200+ updates.
    // Cap the list at maxRows and scroll the rest.
    readonly property int maxRows: 20
    readonly property var lines: Updates.updates.map(u => `${u.name}  ${u.oldVer} \u2192 ${u.newVer}`)
    readonly property string longestLine: lines.reduce((a, b) => b.length > a.length ? b : a, "")

    TextMetrics {
        id: lineMetrics

        font: Tokens.font.mono.small
        text: root.longestLine
    }

    StyledListView {
        id: list

        visible: !Updates.loading && Updates.count > 0
        Layout.preferredWidth: Math.ceil(lineMetrics.advanceWidth) + Tokens.padding.medium
        Layout.preferredHeight: Math.min(count, root.maxRows) * lineMetrics.height
        Layout.rightMargin: -Tokens.spacing.small
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        model: root.lines

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

        delegate: StyledText {
            required property string modelData

            text: modelData
            font: Tokens.font.mono.small
        }
    }
}
