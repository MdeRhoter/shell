pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Tokens.padding.normal
    readonly property string workspaceName: {
        const name = Hypr.focusedWorkspace?.name ?? "";
        // For numbered workspaces, just return the number
        if (name.match(/^\d+$/))
            return name;
        // For special workspaces (special:name), show just the name
        if (name.startsWith("special:"))
            return name.substring(8);
        return name || "1";
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Tokens.rounding.full

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter

            text: "workspaces"
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

            horizontalAlignment: StyledText.AlignHCenter
            text: root.workspaceName
            font.pointSize: Tokens.font.size.small
            font.family: Tokens.font.family.sans
            color: root.colour
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
}
