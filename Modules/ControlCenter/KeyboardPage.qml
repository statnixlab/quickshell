pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root
    property bool presentationActive: false
    readonly property var keyboard: NiriConfigService.keyboardOptions
    readonly property var catalog: NiriConfigService.keyboardCatalog
    readonly property bool editable: NiriConfigService.ready("keyboard")
    readonly property var layouts: keyboard.layouts || []
    readonly property var optionList: String(keyboard.options || "").split(",").filter(option => option
                                                                                                 !== "")
    readonly property var capsNames: catalog.capsOptions.map(option => option.name)
    property string pendingLayout: ""
    property string pendingVariant: ""

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    function layoutEntry(name) {
        return catalog.layouts.find(layout => layout.name === name) || null;
    }

    function layoutLabel(row) {
        const layout = layoutEntry(row.layout);
        if (!layout)
            return row.variant ? row.layout + " (" + row.variant + ")" : row.layout;
        if (!row.variant)
            return layout.label;
        const variant = layout.variants.find(entry => entry.name === row.variant);
        return variant ? variant.label : layout.label + " (" + row.variant + ")";
    }

    function variantOptions(name) {
        const layout = layoutEntry(name);
        return [
                    {
                        label: qsTr("Default"),
                        value: ""
                    }
                ].concat(layout ? layout.variants.map(variant => ({
                    label: variant.label,
                    value: variant.name
                })) : []);
    }

        function setLayouts(rows) {
        NiriConfigService.setKeyboardOptions({
        layouts: rows
    });
    }

        function moveLayout(index, offset) {
        const rows = layouts.slice();
        const target = index + offset;
        if (target < 0 || target >= rows.length)
        return;
        const row = rows[index];
        rows[index] = rows[target];
        rows[target] = row;
        setLayouts(rows);
    }

        // Replace one group of XKB options while preserving every option the page does not manage.
        function optionValue(matches) {
        return optionList.find(matches) || "";
    }

        function setOption(matches, value) {
        const options = optionList.filter(option => !matches(option));
        if (value)
        options.push(value);
        NiriConfigService.setKeyboardOptions({
        options: options.join(",")
    });
    }

        function isSwitchOption(option) {
        return option.startsWith("grp:");
    }

        function isCapsOption(option) {
        return root.capsNames.indexOf(option) >= 0;
    }

        Component.onCompleted: {
        NiriConfigService.refresh();
        NiriConfigService.loadKeyboardCatalog();
    }
        onPresentationActiveChanged: if (presentationActive)
        NiriConfigService.refresh()

        ColumnLayout {
        id: contentColumn
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
        Layout.fillWidth: true
        message: NiriConfigService.busy || NiriConfigService.pendingKeyboardOptions !== null ? qsTr(
        "Saving…") : qsTr("Changes are saved and applied automatically")
    }

        InlineStatusBanner {
        Layout.fillWidth: true
        visible: NiriConfigService.error !== "" || NiriConfigService.readError !== ""
        tone: "error"
        message: NiriConfigService.error || NiriConfigService.readError
    }

        NiriSetupPrompt {
        Layout.fillWidth: true
        title: qsTr("Enable keyboard settings")
        description: qsTr(
        "Clavis takes over keyboard layouts and key repeat, starting from your current values.")
        integrationState: NiriConfigService.state("keyboard")
        busy: NiriConfigService.busy
        blocked: NiriConfigService.busy
        onSetupRequested: NiriConfigService.setup("keyboard")
    }

        SettingsSection {
        id: layoutsSection
        Layout.fillWidth: true
        title: layoutsAnchor.title
        iconName: "language"
        supportingText: root.keyboard.file ? qsTr(
        "A keymap file is configured and takes precedence over these layouts.") : qsTr(
        "Input methods such as Fcitx 5 may use their own layout.")
        SettingsSearchAnchor {
        id: layoutsAnchor
        target: layoutsSection
        declaration:
        '{"id":"general.keyboard.section.layouts","route":"general.keyboard","title":"Keyboard layouts","context":"KeyboardPage","icon":"language","aliases":["xkb","layout","language"]}'
    }

        SettingsRow {
        Layout.fillWidth: true
        visible: root.layouts.length === 0
        title: qsTr("System default")
        supportingText: qsTr("No layout is configured; the XKB default is used.")
    }

        Repeater {
        model: root.layouts

        SettingsRow {
        id: layoutRow
        required property var modelData
        required property int index
        Layout.fillWidth: true
        iconName: "keyboard"
        title: root.layoutLabel(layoutRow.modelData)
        supportingText: layoutRow.index === 0 ? qsTr("Primary layout") : ""
        trailing: RowLayout {
        spacing: 0
        IconButton {
        iconName: "arrow_upward"
        accessibleName: qsTr("Move up")
        enabled: root.editable && layoutRow.index > 0
        onClicked: root.moveLayout(layoutRow.index, -1)
    }
        IconButton {
        iconName: "arrow_downward"
        accessibleName: qsTr("Move down")
        enabled: root.editable && layoutRow.index < root.layouts.length - 1
        onClicked: root.moveLayout(layoutRow.index, 1)
    }
        IconButton {
        iconName: "delete"
        accessibleName: qsTr("Remove")
        enabled: root.editable
        onClicked: root.setLayouts(root.layouts.filter((_, row) => row !== layoutRow.index))
    }
    }
    }
    }

        RowLayout {
        Layout.fillWidth: true
        visible: root.layouts.length < 4
        spacing: Metrics.spacingS

        SearchSelectMenuField {
        objectName: "keyboardLayoutField"
        Layout.fillWidth: true
        implicitHeight: 40
        enabled: root.editable
        options: root.catalog.layouts.map(layout => ({
        label: layout.label,
        value: layout.name
    }))
        value: root.pendingLayout
        placeholder: qsTr("Add a layout")
        onAccepted: value => {
        root.pendingLayout = value;
        root.pendingVariant = "";
    }
    }

        SearchSelectMenuField {
        objectName: "keyboardVariantField"
        Layout.preferredWidth: 200
        implicitHeight: 40
        enabled: root.editable && root.pendingLayout !== ""
        options: root.variantOptions(root.pendingLayout)
        value: root.pendingVariant
        placeholder: qsTr("Variant")
        onAccepted: value => root.pendingVariant = value
    }

        ActionButton {
        text: qsTr("Add")
        iconName: "add"
        enabled: root.editable && root.pendingLayout !== ""
        onClicked: {
        root.setLayouts(root.layouts.concat([
        {
        layout: root.pendingLayout,
        variant: root.pendingVariant
    }
        ]));
        root.pendingLayout = "";
        root.pendingVariant = "";
    }
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Switch layouts with")
        supportingText: root.layouts.length > 1 ? "" : qsTr(
        "Add a second layout to use a switching shortcut.")
        trailing: SearchSelectMenuField {
        objectName: "keyboardSwitchField"
        implicitWidth: 220
        implicitHeight: 40
        enabled: root.editable && root.layouts.length > 1
        options: [
        {
        label: qsTr("No shortcut"),
        value: ""
    }
        ].concat(root.catalog.switchOptions.map(option => ({
        label: option.label,
        value: option.name
    })))
        value: root.optionValue(root.isSwitchOption)
        onAccepted: value => root.setOption(root.isSwitchOption, value)
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Remember layout")
        trailing: SearchSelectMenuField {
        objectName: "keyboardTrackLayoutField"
        implicitWidth: 220
        implicitHeight: 40
        enabled: root.editable
        options: [
        {
        label: qsTr("For all windows"),
        value: "global"
    },
        {
        label: qsTr("For each window"),
        value: "window"
    }
        ]
        value: root.keyboard.trackLayout
        onAccepted: value => NiriConfigService.setKeyboardOptions({
        trackLayout: value
    })
    }
    }
    }

        SettingsSection {
        id: keysSection
        Layout.fillWidth: true
        title: keysAnchor.title
        iconName: "keyboard"
        SettingsSearchAnchor {
        id: keysAnchor
        target: keysSection
        declaration:
        '{"id":"general.keyboard.section.keys","route":"general.keyboard","title":"Keys and repeat","context":"KeyboardPage","icon":"keyboard","aliases":["repeat","delay","caps lock","num lock"]}'
    }

        GeneralSliderSetting {
        objectName: "keyboardRepeatDelaySetting"
        enabled: root.editable
        title: qsTr("Repeat delay")
        description: qsTr("How long a key is held before it starts repeating. The default is 600 ms.")
        from: 100
        to: 1500
        stepSize: 25
        suffix: qsTr(" ms")
        value: root.keyboard.repeatDelay
        onMoved: value => NiriConfigService.setKeyboardOptions({
        repeatDelay: Math.round(value)
    })
    }

        GeneralSliderSetting {
        objectName: "keyboardRepeatRateSetting"
        enabled: root.editable
        title: qsTr("Repeat rate")
        description: qsTr("Characters per second while a key repeats. The default is 25.")
        from: 1
        to: 100
        stepSize: 1
        suffix: qsTr("/s")
        value: root.keyboard.repeatRate
        onMoved: value => NiriConfigService.setKeyboardOptions({
        repeatRate: Math.round(value)
    })
    }

        OutlinedTextField {
        Layout.fillWidth: true
        placeholderText: qsTr("Type here to test")
    }

        SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Caps Lock key")
        trailing: SearchSelectMenuField {
        objectName: "keyboardCapsField"
        implicitWidth: 220
        implicitHeight: 40
        enabled: root.editable
        options: [
        {
        label: qsTr("Caps Lock"),
        value: ""
    }
        ].concat(root.catalog.capsOptions.map(option => ({
        label: option.label,
        value: option.name
    })))
        value: root.optionValue(root.isCapsOption)
        onAccepted: value => root.setOption(root.isCapsOption, value)
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Turn on Num Lock at login")
        trailing: StyledSwitch {
        objectName: "keyboardNumlockSwitch"
        checked: root.keyboard.numlock
        enabled: root.editable
        Accessible.name: qsTr("Turn on Num Lock at login")
        onToggled: NiriConfigService.setKeyboardOptions({
        numlock: checked
    })
    }
    }

        ActionButton {
        text: qsTr("Reset key repeat")
        iconName: "restart_alt"
        enabled: root.editable
        onClicked: NiriConfigService.setKeyboardOptions({
        repeatDelay: 600,
        repeatRate: 25
    })
    }
    }

        SettingsSection {
        id: inputMethodSection
        Layout.fillWidth: true
        title: inputMethodAnchor.title
        iconName: "translate"
        SettingsSearchAnchor {
        id: inputMethodAnchor
        target: inputMethodSection
        declaration:
        '{"id":"general.keyboard.section.input-method","route":"general.keyboard","title":"Input method","context":"KeyboardPage","icon":"translate","aliases":["fcitx","ime","pinyin","rime"]}'
    }

        SettingsActionRow {
        Layout.fillWidth: true
        iconName: "translate"
        text: qsTr("Fcitx 5 settings")
        description: qsTr("Input methods, candidate window and input method shortcuts")
        onClicked: Quickshell.execDetached(["fcitx5-configtool"])
    }
    }
    }
    }
