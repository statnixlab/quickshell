import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    default property alias contentData: contentViewport.data
    property bool backgroundVisible: true
    property bool animateResize: true
    readonly property real pillThickness: backgroundVisible ? PersonalizationConfig.barPillThickness : 36
    readonly property real pillPadding: backgroundVisible ? PersonalizationConfig.barInnerPadding : 6
    readonly property real bandThickness: backgroundVisible ? PersonalizationConfig.barThickness : 36
    readonly property real radius: Math.min(width / 2, height / 2, backgroundVisible
                                            ? PersonalizationConfig.barModuleRadius : Math.min(width, height)
                                              / 2)
    readonly property real blurFillOpacity: pillBackground.fillColor.a

    // Animate the size consumed by the bar layout so the surface, shadow and
    // neighbouring pills follow the same geometry throughout a resize.
    property bool resizeAnimationReady: false
    Component.onCompleted: resizeAnimationReady = true

    // Keep the shadow outside the clipped content subtree.
    data: [
        TopBarPillBackground {
            id: pillBackground
            cornerRadius: root.radius
            visible: root.backgroundVisible
            anchors.fill: parent
        },
        Rectangle {
            id: contentMask
            width: root.width
            height: root.height
            radius: root.radius
            color: "white"
            antialiasing: true
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
        },
        Item {
            id: contentViewport
            anchors.fill: parent
            clip: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: contentMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
    ]

    Behavior on implicitWidth {
        enabled: root.resizeAnimationReady && root.animateResize
        NumberAnimation {
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.resizeAnimationReady && root.animateResize
        NumberAnimation {
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }
    }
}
