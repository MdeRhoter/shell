pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.large

    readonly property var filteredWindows: {
        const all = Hypr.toplevels.values
            .filter(t => t.workspace != null && !t.workspace.name.startsWith("special:"))
            .sort((a, b) => (a.workspace?.id ?? 0) - (b.workspace?.id ?? 0));

        const q = search.text.toLowerCase().trim();
        if (!q) return all;

        return all.filter(t =>
            t.lastIpcObject.title.toLowerCase().includes(q) ||
            t.lastIpcObject.class.toLowerCase().includes(q)
        );
    }

    implicitWidth: 560
    implicitHeight: searchWrapper.implicitHeight + listWrapper.implicitHeight + padding * 2 + Tokens.spacing.small

    // Search bar at the top
    StyledRect {
        id: searchWrapper

        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Tokens.rounding.full

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight)

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "manage_search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            anchors.left: searchIcon.right
            anchors.right: parent.right
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: root.padding

            topPadding: Tokens.padding.larger
            bottomPadding: Tokens.padding.larger

            placeholderText: qsTr("Search windows…")

            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onEscapePressed: root.visibilities.windowswitcher = false

            Keys.onPressed: event => {
                const digit = parseInt(event.text);
                if (digit >= 1 && digit <= 9) {
                    const win = root.filteredWindows.find(w => w.workspace?.id === digit);
                    if (win) {
                        Hypr.dispatch("focuswindow address:" + win.lastIpcObject.address);
                        root.visibilities.windowswitcher = false;
                        event.accepted = true;
                    }
                }
            }

            onAccepted: {
                const win = root.filteredWindows[list.currentIndex];
                if (win) {
                    Hypr.dispatch("focuswindow address:" + win.lastIpcObject.address);
                    root.visibilities.windowswitcher = false;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                function onWindowswitcherChanged(): void {
                    if (root.visibilities.windowswitcher)
                        search.forceActiveFocus();
                    else
                        search.text = "";
                }

                target: root.visibilities
            }
        }
    }

    // Window list
    Item {
        id: listWrapper

        anchors.top: searchWrapper.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.spacing.small
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding

        implicitHeight: list.implicitHeight

        StyledListView {
            id: list

            anchors.fill: parent

            model: ScriptModel {
                values: root.filteredWindows
            }

            spacing: Tokens.spacing.small
            orientation: Qt.Vertical
            implicitHeight: Math.min(
                (Tokens.sizes.launcher.itemHeight + spacing) * count - spacing,
                420
            )

            highlight: StyledRect {
                radius: Tokens.rounding.normal
                color: Colours.palette.m3onSurface
                opacity: 0.08

                y: list.currentItem?.y ?? 0
                implicitWidth: list.width
                implicitHeight: list.currentItem?.implicitHeight ?? 0

                Behavior on y {
                    Anim { type: Anim.DefaultSpatial }
                }
            }

            highlightFollowsCurrentItem: false
            preferredHighlightBegin: 0
            preferredHighlightEnd: height
            highlightRangeMode: ListView.ApplyRange

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: WindowItem {
                required property var modelData

                window: modelData
                visibilities: root.visibilities
            }
        }
    }
}
