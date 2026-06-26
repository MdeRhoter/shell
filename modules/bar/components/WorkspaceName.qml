pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Tokens.padding.small
    
    readonly property string workspaceGroup: WorkspaceNameConfig.labelForWorkspace(Hypr.activeWsId)
    
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
            Hypr.dispatch("togglespecialworkspace " + WorkspaceNameConfig.specialWorkspace);
        }
    }

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: WorkspaceNameConfig.showIcon

            text: "workspaces"
            color: root.colour
            animate: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: WorkspaceNameConfig.showIcon
            height: 1

            width: parent.width * 0.8
            color: root.colour
            opacity: 0.2
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            horizontalAlignment: StyledText.AlignHCenter
            text: root.workspaceGroup
            font: Tokens.font.body.builders.small.weight(Font.Bold).build()
            color: root.colour
        }
        
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: WorkspaceNameConfig.showSpecialCount && root.specialCount > 0
            
            horizontalAlignment: StyledText.AlignHCenter
            text: `(${root.specialCount})`
            font: Tokens.font.mono.small
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
