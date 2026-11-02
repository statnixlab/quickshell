import QtQuick
import QtQuick.Layouts
import QtQml.Models
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var screen
    required property var axis
    property bool vertical: false
    property point surfaceOffset: Qt.point(0, 0)
    property string popupEdge: axis.edge
    property int itemRevision: 0
    readonly property var keystone: BarLayoutService.keystoneFor(root.screen, root.popupEdge)
    readonly property real horizontalInset: Math.max(0, (root.screen.width - root.width) / 2)
                                            + PersonalizationConfig.barInsetPadding
    readonly property real minimumLeadingWidth: sectionMinimumWidth(true)
    readonly property real minimumTrailingWidth: sectionMinimumWidth(false)
    readonly property real minimumLength: (vertical ? leadingSection.implicitHeight
                                                      + trailingSection.implicitHeight : root.keystone
                                                      ? minimumLeadingWidth + minimumTrailingWidth :
                                                        leadingSection.implicitWidth
                                                        + trailingSection.implicitWidth) + 2
                                          * PersonalizationConfig.barInsetPadding + 8
    readonly property Item leadingInputRegionItem: leadingSection
    readonly property Item trailingInputRegionItem: trailingSection
    readonly property var backgroundItems: {
        const revision = root.itemRevision;
        const items = [];
        for (let index = 0; index < componentInstantiator.count; index += 1) {
            const loader = componentInstantiator.objectAt(index);
            if (loader && loader.item)
                items.push(loader.item);
        }
        return items;
    }

    Component.onCompleted: BarLayoutService.registerBar(root)
    Component.onDestruction: BarLayoutService.unregisterBar(root)

    // Use the icon-only window width for the independent minimum. Keystone
    // can then fit its media title without a cycle through the assigned width.
    function sectionMinimumWidth(leading) {
        const revision = root.itemRevision;
        let extent = 0;
        let count = 0;
        for (let index = 0; index < componentInstantiator.count; ++index) {
            const loader = componentInstantiator.objectAt(index);
            if (!loader || !loader.active || !loader.item || (loader.leadingIndex >= 0) !== leading)
                continue;
            extent += loader.modelData === "activeWindow" ? loader.item.minimumHorizontalWidth :
                                                            loader.item.implicitWidth;
            ++count;
        }
        const section = leading ? leadingSection : trailingSection;
        return extent + Math.max(0, count - 1) * section.columnSpacing;
    }

    function activeWindowAvailableWidth(leading, minimumWidth) {
        if (root.vertical || !root.keystone)
            return Infinity;
        const available = (root.screen.width - root.keystone.contentLength) / 2 - root.horizontalInset
              - BarLayoutService.clearance;
        const fixedWidth = (leading ? root.minimumLeadingWidth : root.minimumTrailingWidth) - minimumWidth;
        return Math.max(minimumWidth, available - fixedWidth);
    }

    Instantiator {
        model: root.backgroundItems

        delegate: GeometryBlurBackdrop {
            required property var modelData

            sourceItem: modelData
            targetScreen: root.screen
            surfaceOffset: root.surfaceOffset
            surfaceNamespace: "clavis-bar-backdrop"
            active: sourceItem && sourceItem.backgroundVisible !== false && (sourceItem.blurFillOpacity
                                                                             === undefined
                                                                             || sourceItem.blurFillOpacity
                                                                             < 1)
        }
    }

    BarSection {
        id: leadingSection

        vertical: root.vertical
        compact: (root.vertical ? root.screen.height : root.screen.width) < 1000
        componentCount: PersonalizationConfig.barLeadingComponents.length

        anchors {
            left: root.vertical ? undefined : parent.left
            top: root.vertical ? parent.top : undefined
            leftMargin: root.vertical ? 0 : PersonalizationConfig.barInsetPadding
            topMargin: root.vertical ? PersonalizationConfig.barInsetPadding : 0
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        }
    }

    BarSection {
        id: trailingSection

        vertical: root.vertical
        compact: (root.vertical ? root.screen.height : root.screen.width) < 1000
        componentCount: PersonalizationConfig.barTrailingComponents.length

        anchors {
            right: root.vertical ? undefined : parent.right
            bottom: root.vertical ? parent.bottom : undefined
            rightMargin: root.vertical ? 0 : PersonalizationConfig.barInsetPadding
            bottomMargin: root.vertical ? PersonalizationConfig.barInsetPadding : 0
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        }
    }

    Instantiator {
        id: componentInstantiator

        model: PersonalizationConfig.barComponentIds
        onObjectAdded: root.itemRevision += 1
        onObjectRemoved: root.itemRevision += 1

        delegate: BarComponentLoader {
            id: componentLoader

            required property string modelData
            readonly property int leadingIndex: PersonalizationConfig.barLeadingComponents.indexOf(modelData)
            readonly property int trailingIndex: PersonalizationConfig.barTrailingComponents.indexOf(
                                                     modelData)
            readonly property int zoneIndex: leadingIndex >= 0 ? leadingIndex : trailingIndex

            componentId: modelData
            screen: root.screen
            axis: root.axis
            barVisualItem: root
            vertical: root.vertical
            activeWindowAvailableWidth: item && modelData === "activeWindow" ? root.activeWindowAvailableWidth(
                                                                                   leadingIndex >= 0,
                                                                                   item.minimumHorizontalWidth) :
                                                                               Infinity
            active: zoneIndex >= 0
            visible: active
            parent: leadingIndex >= 0 ? leadingSection : trailingSection
            Layout.row: root.vertical ? Math.max(0, zoneIndex) : 0
            Layout.column: root.vertical ? 0 : Math.max(0, zoneIndex)
            Layout.alignment: Qt.AlignCenter
            onItemChanged: root.itemRevision += 1
        }
    }
}
