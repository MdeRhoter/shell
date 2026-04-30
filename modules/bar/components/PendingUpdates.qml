pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property bool hasUpdates: Updates.count > 0
    readonly property color colour: hasUpdates ? Colours.palette.m3tertiary : Colours.palette.m3secondary

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.normal * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Tokens.rounding.full

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "-e", "garuda-update"]);
        }
    }

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter

            text: root.hasUpdates ? "system_update" : "system_update_alt"
            color: root.colour
            animate: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            width: parent.width * 0.8
            color: root.colour
            opacity: 0.2
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.hasUpdates

            horizontalAlignment: StyledText.AlignHCenter
            text: Updates.count.toString()
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            font.weight: Font.Bold
            color: root.colour
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
}
