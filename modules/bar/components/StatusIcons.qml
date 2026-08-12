pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.components.status

StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconColumn

    readonly property int spacing: Tokens.spacing.medium / 2

    // Index of the first/last entry that isn't collapsed, for edge margin gating
    readonly property int firstPresent: {
        const values = model.values;
        for (let i = 0; i < values.length; i++)
            if (!collapsed(values[i]))
                return i;
        return -1;
    }
    readonly property int lastPresent: {
        const values = model.values;
        for (let i = values.length - 1; i >= 0; i--)
            if (!collapsed(values[i]))
                return i;
        return -1;
    }

    // Entries that can shrink to nothing, spacing included
    function collapsed(entry: var): bool {
        if (entry.id === "lockStatus")
            return !Hypr.capsLock && !Hypr.numLock;
        // Fork entries. Before v2.3.0 these were WrappedLoaders whose `active:`
        // binding decided whether they were constructed at all. v2.3.0 builds a
        // delegate for every *enabled* config entry, so the condition has to move
        // here — collapsing reserves no space and drops the surrounding spacing,
        // which is the same visual result the old `active: false` gave.
        if (entry.id === "idleInhibitor")
            return !IdleInhibitor.enabled;
        if (entry.id === "mouseBattery")
            return Peripherals.mouse === null;
        return false;
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    clip: true
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: iconColumn.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: iconColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium

        spacing: 0

        Repeater {
            model: ScriptModel {
                id: model

                values: root.Config.bar.statusIcons.values.filter(e => e.enabled)
            }

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "lockStatus"
                    delegate: EntryWrapper {
                        LockStatus {
                            colour: root.colour
                            parentSpacing: root.spacing
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "audio"
                    delegate: EntryWrapper {
                        margin: Tokens.spacing.extraSmall / 2

                        MaterialIcon {
                            animate: true
                            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                            color: root.colour
                            fontStyle: Tokens.font.icon.medium
                            fill: 1
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "microphone"
                    delegate: EntryWrapper {
                        margin: Tokens.spacing.extraSmall / 2
                        name: "audio" // Mic opens audio popout

                        MaterialIcon {
                            animate: true
                            text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                            color: root.colour
                            fontStyle: Tokens.font.icon.medium
                            fill: 1
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "kbLayout"
                    delegate: EntryWrapper {
                        StyledText {
                            animate: true
                            text: Hypr.kbLayout
                            color: root.colour
                            font: Tokens.font.mono.medium
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "network"
                    delegate: EntryWrapper {
                        MaterialIcon {
                            animate: true
                            text: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                            color: root.colour
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "bluetooth"
                    delegate: EntryWrapper {
                        BluetoothStatus {
                            colour: root.colour
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "battery"
                    delegate: EntryWrapper {
                        BatteryStatus {
                            colour: root.colour
                        }
                    }
                }
                // Keep Awake indicator. root.collapsed() only drops the SPACING
                // around an entry — EntryWrapper still sizes to item.implicitHeight —
                // so the item has to collapse itself, the same way LockStatus does.
                DelegateChoice {
                    roleValue: "idleInhibitor"
                    delegate: EntryWrapper {
                        Item {
                            id: inhibitor

                            property real iconHeight: IdleInhibitor.enabled ? coffeeIcon.implicitHeight : 0

                            implicitWidth: coffeeIcon.implicitWidth
                            implicitHeight: Math.round(iconHeight)

                            Behavior on iconHeight {
                                Anim {
                                    type: Anim.SlowEffects
                                }
                            }

                            MaterialIcon {
                                id: coffeeIcon

                                anchors.centerIn: parent

                                text: "coffee"
                                color: Colours.palette.m3primary
                                fill: 1

                                scale: IdleInhibitor.enabled ? 1 : 0.5
                                opacity: IdleInhibitor.enabled ? 1 : 0

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.DefaultEffects
                                    }
                                }

                                Behavior on scale {
                                    Anim {}
                                }
                            }
                        }
                    }
                }
                // Mouse battery, Logitech via Solaar. Same self-collapse as above:
                // without it a "mouse" icon would sit in the bar with no mouse paired.
                DelegateChoice {
                    roleValue: "mouseBattery"
                    delegate: EntryWrapper {
                        Item {
                            id: mouseBattery

                            property real contentHeight: Peripherals.mouse ? mouseColumn.implicitHeight : 0

                            implicitWidth: mouseColumn.implicitWidth
                            implicitHeight: Math.round(contentHeight)

                            Behavior on contentHeight {
                                Anim {
                                    type: Anim.SlowEffects
                                }
                            }

                            ColumnLayout {
                                id: mouseColumn

                                anchors.centerIn: parent
                                spacing: 0

                                opacity: Peripherals.mouse ? 1 : 0

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.DefaultEffects
                                    }
                                }

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    animate: true
                                    text: "mouse"
                                    fill: 1
                                    color: Peripherals.isLow(Peripherals.mouse) ? Colours.palette.m3error : root.colour
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    animate: true
                                    text: Peripherals.mouse ? `${Peripherals.mouse.percentage}` : ""
                                    font: Tokens.font.mono.small
                                    color: Peripherals.isLow(Peripherals.mouse) ? Colours.palette.m3error : root.colour
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        property int margin: root.spacing / 2
        readonly property bool present: !root.collapsed(modelData)
        property real topGap: present && index !== root.firstPresent ? margin : 0
        property real bottomGap: present && index !== root.lastPresent ? margin : 0
        default property Item item
        property string name: modelData.id.toLowerCase()

        Layout.topMargin: Math.round(topGap)
        Layout.bottomMargin: Math.round(bottomGap)
        Layout.alignment: Qt.AlignHCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item

        Behavior on topGap {
            Anim {
                type: Anim.SlowEffects
            }
        }

        Behavior on bottomGap {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }
}
