pragma Singleton
import Quickshell
import qs.Services

Singleton {
    readonly property real cornerRadius: 10
    readonly property real barVisualThickness: PersonalizationConfig.barThickness
    readonly property real barPillThickness: PersonalizationConfig.barPillThickness
    readonly property real barPillHorizontalPadding: 6
    readonly property real barControlCircleSize: Math.min(28, barPillThickness - 4)
    readonly property real barWeatherVerticalPillHeight: 56
    readonly property real barOuterEdgeMargin: 8
    readonly property real barShadowBuffer: 36
    readonly property real barPopupGap: 8
    readonly property real barPopupScreenMargin: 10
    // Presentation compatibility aliases. Surface geometry must use the
    // semantic tokens above so margin, visuals, and shadow never mix.
    readonly property real barHeight: barVisualThickness
    readonly property real verticalBarWidth: barVisualThickness
    readonly property real sidebarScrollableListMaxHeight: 224
    readonly property real lockHeightMult: 0.7
    readonly property real lockRatio: 16 / 9
}
