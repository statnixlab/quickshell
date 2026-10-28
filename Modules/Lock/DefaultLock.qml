import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Wallpaper

Item {
    id: root

    required property WlSessionLock lock
    required property var context
    property var snapshotProvider: null
    property var screen: null
    readonly property var snapshotResult: snapshotProvider && screen ? snapshotProvider.snapshot(screen) :
                                                                       null
    readonly property bool snapshotReady: snapshotResult !== null && snapshot.status === Image.Ready
    property bool useSnapshot: true
    property bool started: false
    property bool exiting: false
    property bool revealPending: false
    property int preparationFrames: 0
    property real reveal: 0
    property real sceneOpacity: 1
    readonly property string screenName: screen ? screen.name : ""

    function startReveal() {
        if (started || exiting || !screen)
            return;
        if (snapshotResult && snapshot.status !== Image.Ready && snapshot.status !== Image.Error)
            return;
        if (!wallpaper.ready && wallpaper.imageStatus !== Image.Error)
            return;
        useSnapshot = snapshotReady;
        started = true;
        if (snapshotReady) {
            preparationFrames = 0;
            revealPending = true;
        } else {
            reveal = 1;
        }
        content.forceAuthFocus();
    }

    onScreenChanged: Qt.callLater(startReveal)
    Component.onCompleted: Qt.callLater(startReveal)

    // Captured before acquiring the session lock. Decode synchronously so the
    // first surface frame already has a desktop underneath the reveal.
    Image {
        id: snapshot
        anchors.fill: parent
        source: root.snapshotResult ? root.snapshotResult.url : ""
        fillMode: Image.Stretch
        asynchronous: false
        cache: true
        onStatusChanged: Qt.callLater(root.startReveal)
    }

    Item {
        id: scene
        anchors.fill: parent
        opacity: root.started ? (root.useSnapshot ? root.sceneOpacity : 1) : 0
        layer.enabled: true
        layer.effect: ShaderEffect {
            property var source
            property vector2d resolution: Qt.vector2d(width, height)
            property real progress: root.reveal
            fragmentShader: Paths.fileUrl(Paths.assetsDir + "/shaders/lock/qsb/reveal.frag.qsb")
        }

        Rectangle {
            anchors.fill: parent
            color: "#15191D"
        }

        WallpaperImageViewport {
            id: wallpaper
            onReadyChanged: Qt.callLater(root.startReveal)
            onImageStatusChanged: Qt.callLater(root.startReveal)
            anchors.fill: parent
            sourcePath: WallpaperService.wallpaperForScreen(root.screenName)
            imageFillMode: WallpaperService.qtFillMode(WallpaperService.fillModeForScreen(root.screenName))
            panoramaEnabled: WallpaperService.fillModeForScreen(root.screenName) === "panorama"
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: 1
                blurMultiplier: 1
                saturation: -0.2
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#66000000"
        }

        DefaultLockContent {
            id: content
            anchors.fill: parent
            context: root.context
            enabled: !root.exiting
        }
    }

    Connections {
        target: root.lock
        function onUnlockRequested() {
            if (root.exiting)
                return;
            root.exiting = true;
            root.revealPending = false;
            entrance.stop();
            exitAnimation.start();
        }
    }

    NumberAnimation {
        id: entrance
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 850
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }

    FrameAnimation {
        running: root.revealPending
        onTriggered: {
            // Allocate the scene/blur layers and prepare the reveal shader
            // before advancing the animation, while the snapshot covers it.
            if (++root.preparationFrames >= 2) {
                root.revealPending = false;
                entrance.start();
            }
        }
    }

    NumberAnimation {
        id: exitAnimation
        target: root
        property: "sceneOpacity"
        to: 0
        duration: 300
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
        onFinished: root.context.finishUnlock()
    }
}
