import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Clavis.Lyrics
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import qs.Modules.Keystone.LyricsContent

// Lyrics presentation that occupies the full island in place, keeping the
// island's size so it never covers other windows.
Item {
    id: root

    property bool active: false
    readonly property var player: MediaManager.active
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string trackTitle: player ? player.trackTitle || player.identity || "" : ""
    readonly property string trackArtist: player ? player.trackArtist || "" : ""
    readonly property string artUrl: player ? player.trackArtUrl || "" : ""
    readonly property real position: active ? MediaManager.currentPosition : 0
    readonly property real trackLength: player ? Math.max(0, Number(player.length) || 0) : 0
    readonly property real trackProgress: trackLength > 0 ? Math.max(0, Math.min(1, position / trackLength)) :
                                                            0
    readonly property int currentLineIndex: {
        const lines = Lyrics.lyrics;
        if (!active || !player || !Lyrics.hasSynchronizedLyrics || !lines || lines.length === 0)
            return -1;
        return Math.max(0, Math.min(lines.length - 1, Lyrics.indexForTime(position)));
    }
    readonly property string currentLyric: {
        const lines = Lyrics.lyrics;
        const text = currentLineIndex >= 0 && lines ? String(lines[currentLineIndex].text || "").trim() : "";
        return text.length > 0 ? text : trackTitle;
    }
    // Fraction of the current line already sung, used for the karaoke fill.
    readonly property real lineProgress: {
        if (currentLineIndex < 0)
            return 1;
        const start = Lyrics.timeForIndex(currentLineIndex);
        const next = Lyrics.timeForIndex(currentLineIndex + 1);
        if (start < 0 || position < start)
            return 0;
        const end = next > start ? next : (trackLength > start ? trackLength : start + 5);
        // Finish the fill slightly before the next line starts.
        const span = Math.max(0.5, (end - start) * 0.92);
        return Math.max(0, Math.min(1, (position - start) / span));
    }
    readonly property string spectrumToken: "keystone-full-lyrics-" + String(root)
    readonly property bool spectrumActive: active && visible && playing
    readonly property real sideWidth: 200
    // Size the island from the song's widest line so it stays put between lines.
    readonly property real lyricWidth: Math.max(220, Math.min(440, lyricsMeasure.implicitWidth + 16))
    readonly property real preferredLength: 2 * (sideWidth + PersonalizationConfig.keystoneInsetPadding + 20)
                                            + lyricWidth
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color foreground: Appearance.colors.colOnSurface

    property string shownLyric: ""
    property real shownProgress: 1
    property real lineOffset: 0

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    function showLyricNow() {
        lineSwap.stop();
        shownLyric = currentLyric;
        shownProgress = lineProgress;
        lyricLine.opacity = 1;
        lineOffset = 0;
    }

    onCurrentLyricChanged: {
        if (!active || shownLyric.length === 0)
            showLyricNow();
        else
            lineSwap.restart();
    }
    onLineProgressChanged: {
        if (!lineSwap.running)
            shownProgress = lineProgress;
    }
    onActiveChanged: {
        if (active)
            showLyricNow();
    }
    onSpectrumActiveChanged: {
        if (spectrumActive)
            AudioSpectrum.acquire(spectrumToken);
        else
            AudioSpectrum.release(spectrumToken);
    }
    Component.onCompleted: showLyricNow()
    Component.onDestruction: AudioSpectrum.release(spectrumToken)

    Text {
        id: lyricsMeasure

        visible: false
        text: (Lyrics.hasSynchronizedLyrics ? (Lyrics.lyrics || []).map(line => String(line.text || "").trim(
                                                                                    )) : []).concat(
                  [root.trackTitle]).join("\n")
        textFormat: Text.PlainText
        font: baseText.font
    }

    SequentialAnimation {
        id: lineSwap

        ParallelAnimation {
            NumberAnimation {
                target: lyricLine
                property: "opacity"
                to: 0
                duration: 140
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "lineOffset"
                to: -8
                duration: 140
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                root.shownLyric = root.currentLyric;
                root.shownProgress = 0;
                root.lineOffset = 8;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: lyricLine
                property: "opacity"
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "lineOffset"
                to: 0
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        ScriptAction {
            script: root.shownProgress = root.lineProgress
        }
    }

    // Leading side: spinning disc with a progress ring, then the track name.
    Row {
        id: trackInfo

        anchors.left: parent.left
        anchors.leftMargin: PersonalizationConfig.keystoneInsetPadding + 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.sideWidth
        spacing: 9

        Item {
            id: disc

            readonly property real ringSize: Math.min(30, root.height - 4)

            anchors.verticalCenter: parent.verticalCenter
            width: ringSize
            height: ringSize

            Canvas {
                id: progressRing

                readonly property real progress: root.trackProgress
                readonly property color accent: root.accent

                anchors.fill: parent
                onProgressChanged: requestPaint()
                onAccentChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const context = getContext("2d");
                    context.reset();
                    const line = 2;
                    const centre = width / 2;
                    const radius = centre - line / 2;
                    context.lineWidth = line;
                    context.lineCap = "round";
                    context.strokeStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                                                  0.12);
                    context.beginPath();
                    context.arc(centre, centre, radius, 0, 2 * Math.PI);
                    context.stroke();
                    if (progress > 0) {
                        context.strokeStyle = accent;
                        context.beginPath();
                        context.arc(centre, centre, radius, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI
                                    * progress);
                        context.stroke();
                    }
                }
            }

            Item {
                id: cover

                anchors.centerIn: parent
                width: disc.ringSize - 8
                height: width

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 12000
                    loops: Animation.Infinite
                    running: root.active && root.playing && root.visible
                }

                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(
                                                                                                              height * Screen.devicePixelRatio)))
                    asynchronous: true
                    retainWhileLoading: true
                    visible: source !== ""
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: discMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }

                Rectangle {
                    id: discMask

                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: root.artUrl === ""
                    color: Appearance.applyAlpha(root.accent, 0.15)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: 12
                        color: root.accent
                    }
                }

                // A spindle hole sells the record look without hiding the cover.
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    visible: root.artUrl !== ""
                    color: Appearance.colors.colLayer0
                    opacity: 0.85
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, trackInfo.width - disc.width - trackInfo.spacing)
            spacing: -2

            Text {
                width: parent.width
                text: root.trackTitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: root.foreground
            }

            Text {
                width: parent.width
                visible: root.trackArtist.length > 0
                text: root.trackArtist
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Fonts.ui
                font.pixelSize: 10
                color: Appearance.applyAlpha(root.foreground, 0.55)
            }
        }
    }

    // Centre: the current line with a karaoke-style accent fill.
    Item {
        anchors.centerIn: parent
        width: Math.max(0, root.width - 2 * (root.sideWidth + PersonalizationConfig.keystoneInsetPadding
                                             + 20))

        height: parent.height
        clip: true

        Item {
            id: lyricLine

            width: parent.width
            height: parent.height
            y: root.lineOffset

            Text {
                id: baseText

                anchors.fill: parent
                text: root.shownLyric
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 12
                font.family: Fonts.ui
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: 0.6
                color: Appearance.applyAlpha(root.foreground, 0.4)
            }

            Item {
                readonly property real textLeft: (lyricLine.width - baseText.contentWidth) / 2

                height: parent.height
                width: Math.max(0, textLeft + baseText.contentWidth * root.shownProgress)
                clip: true

                Behavior on width {
                    enabled: !lineSwap.running
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.Linear
                    }
                }

                Text {
                    width: lyricLine.width
                    height: lyricLine.height
                    text: baseText.text
                    textFormat: Text.PlainText
                    horizontalAlignment: baseText.horizontalAlignment
                    verticalAlignment: baseText.verticalAlignment
                    elide: baseText.elide
                    fontSizeMode: baseText.fontSizeMode
                    minimumPixelSize: baseText.minimumPixelSize
                    font: baseText.font
                    color: root.accent
                }
            }
        }
    }

    // Trailing side: transport controls, elapsed time and the live spectrum.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: PersonalizationConfig.keystoneInsetPadding + 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                controlSize: Math.min(26, root.height - 2)
                iconSize: 18
                iconName: "skip_previous"
                accessibleName: qsTr("Previous track")
                enabled: root.player !== null && root.player.canGoPrevious
                onClicked: root.player.previous()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                controlSize: Math.min(26, root.height - 2)
                iconSize: 20
                iconFill: 1
                iconName: root.playing ? "pause" : "play_arrow"
                iconColor: root.accent
                accessibleName: root.playing ? qsTr("Pause") : qsTr("Play")
                enabled: root.player !== null && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                controlSize: Math.min(26, root.height - 2)
                iconSize: 18
                iconName: "skip_next"
                accessibleName: qsTr("Next track")
                enabled: root.player !== null && root.player.canGoNext
                onClicked: root.player.next()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trackLength > 0
            text: root.formatTime(root.position) + " / " + root.formatTime(root.trackLength)
            textFormat: Text.PlainText
            font.family: Fonts.numeric
            font.pixelSize: 10
            color: Appearance.applyAlpha(root.foreground, 0.55)
        }

        LyricsSpectrum {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 16
            active: root.spectrumActive
            dataAvailable: AudioSpectrum.available
            values: AudioSpectrum.values
            barColor: root.accent
        }
    }
}
