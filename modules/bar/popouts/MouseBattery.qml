pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Fly-out for the mouseBattery status icon: every OpenLogi device with a
// battery, plus a shortcut into the OpenLogi app.
ColumnLayout {
    id: root

    required property PopoutState popouts

    function kindIcon(kind: string): string {
        switch (kind) {
        case "mouse":
            return "mouse";
        case "keyboard":
            return "keyboard";
        case "headset":
            return "headset_mic";
        default:
            return "devices_other";
        }
    }

    function statusText(d: var): string {
        if (d.charging)
            return Tr.tr("Charging");
        if (Peripherals.isLow(d))
            return Tr.tr("Low — time to recharge");
        return Tr.tr("On battery");
    }

    // Opening the fly-out is a good moment for a fresh reading; the agent
    // answers from its cached inventory, so this is cheap.
    Component.onCompleted: Peripherals.refresh()

    width: 280
    spacing: Tokens.spacing.small

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        text: Tr.tr("Peripherals")
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    StyledText {
        visible: Peripherals.devices.length === 0
        text: Tr.tr("No devices reported by OpenLogi")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Repeater {
        model: ScriptModel {
            values: Peripherals.devices
        }

        ColumnLayout {
            id: device

            required property var modelData
            readonly property bool low: Peripherals.isLow(modelData)
            readonly property color accent: low ? Colours.palette.m3error : Colours.palette.m3primary

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: root.kindIcon(device.modelData.kind)
                    fill: 1
                    color: device.accent
                    font: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: device.modelData.name
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.statusText(device.modelData)
                        color: device.low ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                StyledText {
                    text: `${device.modelData.percentage}%`
                    color: device.accent
                    font: Tokens.font.mono.small
                }
            }

            StyledProgressBar {
                Layout.fillWidth: true
                implicitHeight: Tokens.padding.small
                value: device.modelData.percentage / 100
                fgColour: device.accent
            }
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.small
        visible: Peripherals.lastUpdated !== null
        text: Tr.tr("Updated %1").arg(Qt.formatTime(Peripherals.lastUpdated, Units.twelveHourClock ? "hh:mm a" : "hh:mm"))
        color: Colours.palette.m3outline
        font: Tokens.font.body.small
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.extraSmall
        text: Tr.tr("Open OpenLogi")
        icon: "settings"

        onClicked: {
            Quickshell.execDetached(["openlogi-desktop"]);
            root.popouts.hasCurrent = false;
        }
    }
}
