pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running
    // Computed once on creation so it doesn't flip to false when screen
    // goes null during surface teardown, which would deactivate the Content
    // Loader mid-incubation and cause "Object or context destroyed" warnings.
    property bool isLandscape: false

    // Set isLandscape once and start initAnim when the screen is available.
    // We cannot use a live binding: it would flip to false when screen goes
    // null during surface teardown, deactivating the Content Loader while
    // sub-components are still incubating.
    // We cannot use Component.onCompleted alone: Quickshell may assign screen
    // after onCompleted fires, in which case screen.width throws a TypeError
    // and initAnim never starts – leaving an invisible lock surface.
    // Solution: try in both onCompleted and onScreenChanged; the guard
    // !initAnim.running ensures we init at most once.
    function _initForScreen(): void {
        if (screen !== null && !initAnim.running) {
            isLandscape = screen.width >= screen.height;
            initAnim.start();
        }
    }
    Component.onCompleted: _initForScreen()
    onScreenChanged: _initForScreen()

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: "transparent"

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: lockContent
                properties: "implicitWidth,implicitHeight"
                to: lockContent.size
            }
            Anim {
                target: lockBg
                property: "radius"
                to: lockContent.radius
            }
            Anim {
                target: contentLoader
                property: "scale"
                to: 0
            }
            Anim {
                target: contentLoader
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: Anim.StandardLarge
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Tokens.anim.durations.small
                }
                Anim {
                    type: Anim.Standard
                    target: lockContent
                    property: "opacity"
                    to: 0
                }
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    ParallelAnimation {
        id: initAnim

        Anim {
            target: background
            property: "opacity"
            to: 1
            type: Anim.StandardLarge
        }
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: lockContent
                    property: "scale"
                    to: 1
                    type: Anim.FastSpatial
                }
                Anim {
                    target: lockContent
                    property: "rotation"
                    to: 360
                    duration: Tokens.anim.durations.expressiveFastSpatial
                    easing: Tokens.anim.standardAccel
                }
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: root.isLandscape ? 0 : 1
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: contentLoader
                    property: "opacity"
                    to: root.isLandscape ? 1 : 0
                }
                Anim {
                    target: contentLoader
                    property: "scale"
                    to: root.isLandscape ? 1 : 0
                    type: Anim.DefaultSpatial
                }
                Anim {
                    target: lockBg
                    property: "radius"
                    to: root.isLandscape ? lockContent.Tokens.rounding.extraLarge * 1.5 : lockContent.radius
                }
                Anim {
                    target: lockContent
                    property: "implicitWidth"
                    to: root.isLandscape
                        ? (root.screen?.height ?? 0) * lockContent.Tokens.sizes.lock.heightMult * lockContent.Tokens.sizes.lock.ratio
                        : lockContent.size
                    type: Anim.DefaultSpatial
                }
                Anim {
                    target: lockContent
                    property: "implicitHeight"
                    to: root.isLandscape
                        ? (root.screen?.height ?? 0) * lockContent.Tokens.sizes.lock.heightMult
                        : lockContent.size
                    type: Anim.DefaultSpatial
                }
            }
        }
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: Config.lock.useWallpaper ? wallpaperBackground : screencopyBackground
        }
    }

    Component {
        id: screencopyBackground

        ScreencopyView {
            captureSource: root.screen
        }
    }

    Component {
        id: wallpaperBackground

        CachingImage {
            path: Wallpapers.current
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Tokens.padding.large * 4
        readonly property int radius: size / 4 * Tokens.rounding.scale

        anchors.centerIn: parent
        implicitWidth: size
        implicitHeight: size

        visible: Config.lock.enabled
        rotation: 180
        scale: 0

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.palette.m3surface
            radius: parent.radius
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "lock"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(4).weight(Font.Bold).build()
            rotation: 180
        }

        Loader {
            id: contentLoader

            anchors.centerIn: parent
            active: root.isLandscape

            sourceComponent: Content {
                width: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio - Tokens.padding.extraLargeIncreased
                height: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult - Tokens.padding.extraLargeIncreased
                lock: root
            }

            opacity: 0
            scale: 0
        }
    }
}
