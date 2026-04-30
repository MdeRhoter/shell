pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Tokens.padding.normal
    
    // Get workspace group letter based on workspace ID
    readonly property string workspaceGroup: {
        const wsId = Hypr.activeWsId;
        if (wsId >= 1 && wsId <= 3) return "W";  // Work
        if (wsId >= 4 && wsId <= 6) return "M";  // Music
        if (wsId >= 7 && wsId <= 9) return "P";  // Personal
        return wsId.toString();
    }
    
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
    
    // Generate tooltip with special workspace windows
    readonly property string specialTooltip: {
        if (specialCount === 0)
            return "Special workspace is empty";
        
        const toplevels = Hypr.toplevels.values;
        let apps = [];
        for (const toplevel of toplevels) {
            if (toplevel.workspace?.name.startsWith("special:")) {
                const className = toplevel.lastIpcObject.class || "Unknown";
                const title = toplevel.title || "No title";
                apps.push(`• ${className}: ${title}`);
            }
        }
        return apps.join("\n");
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Tokens.rounding.full

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            Hypr.dispatch("togglespecialworkspace magic");
        }
        
        ToolTip {
            visible: parent.containsMouse && root.specialCount > 0
            text: root.specialTooltip
            delay: 500
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
