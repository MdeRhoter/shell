pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var window
    required property ScreenState screenState

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.small
        onClicked: {
            Hypr.dispatch("focuswindow address:" + root.window.lastIpcObject.address);
            root.screenState.windowswitcher = false;
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.extraSmall
        anchors.bottomMargin: Tokens.padding.extraSmall

        // Workspace badge
        StyledRect {
            id: wsBadge

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left

            implicitWidth: wsLabel.implicitWidth + Tokens.padding.small * 2
            implicitHeight: wsLabel.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.small
            color: Colours.palette.m3primaryContainer

            StyledText {
                id: wsLabel

                anchors.centerIn: parent
                text: root.window.workspace?.id?.toString() ?? "?"
                font: Tokens.font.body.builders.small.weight(Font.Bold).build()
                color: Colours.palette.m3onPrimaryContainer
            }
        }

        // App icon
        IconImage {
            id: appIcon

            asynchronous: true
            source: Icons.getAppIcon(root.window.lastIpcObject.class, "application-x-executable")
            implicitSize: parent.height * 0.7

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: wsBadge.right
            anchors.leftMargin: Tokens.spacing.small
        }

        // Title + class name
        Item {
            anchors.left: appIcon.right
            anchors.leftMargin: Tokens.spacing.small
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            implicitHeight: title.implicitHeight + cls.implicitHeight

            StyledText {
                id: title

                text: root.window.lastIpcObject.title
                font: Tokens.font.body.medium
                elide: Text.ElideRight
                width: parent.width
            }

            StyledText {
                id: cls

                anchors.top: title.bottom
                text: root.window.lastIpcObject.class
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
