pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Tokens.padding.normal
    
    // Show the current workspace number
    readonly property string workspaceGroup: Hypr.activeWsId.toString()
    
    // Count windows in special workspaces
    readonly property int specialCount: {
        let count = 0;
        const toplevels = Hypr.toplevels.values;
        for (const toplevel of toplevels) {
            if (toplevel.workspace?.name.startsWith("special:"))
                count++;
        }
        return count;
    }
    
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Tokens.rounding.full

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            Hypr.dispatch("togglespecialworkspace magic");
        }
    }

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
            text: root.workspaceGroup
            font.pointSize: Tokens.font.size.normal
            font.family: Tokens.font.family.sans
            font.weight: Font.Bold
            color: root.colour
        }
        
        // Special workspace counter (only shown when > 0)
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.specialCount > 0
            
            horizontalAlignment: StyledText.AlignHCenter
            text: `(${root.specialCount})`
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            color: root.colour
            opacity: 0.8
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
}
