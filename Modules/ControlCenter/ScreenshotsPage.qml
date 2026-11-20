pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.FilePicker
import qs.Widgets.common

StyledFlickable {
    id: root
    property var parentModal: null
    property bool presentationActive: false
    readonly property var screenshots: NiriConfigService.screenshotOptions
    readonly property bool editable: NiriConfigService.ready("screenshots")
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string path: screenshots.path || ""
    readonly property string folder: path.lastIndexOf("/") >= 0 ? path.slice(0, path.lastIndexOf("/")) : ""
    readonly property string fileName: path.slice(path.lastIndexOf("/") + 1)
    readonly property var namePatterns: [qsTr("Screenshot") + " %Y-%m-%d %H-%M-%S.png",
        "Screenshot from %Y-%m-%d %H-%M-%S.png", "%Y%m%d_%H%M%S.png"]

    signal navigateRequested(string pageId)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    function closeChildWindows() {
        folderPicker.dismiss();
    }

    // niri expands a leading ~, which keeps the saved path independent of the home directory.
    function shortPath(value) {
        return home && value.startsWith(home + "/") ? "~" + value.slice(home.length) : value;
    }

    function picturesFolder() {
        const url = String(StandardPaths.writableLocation(StandardPaths.PicturesLocation));
        return shortPath(decodeURIComponent(url.replace(/^file:\/\//, "")));
    }

    // A readable example of a strftime pattern, for the common fields only.
    function example(pattern) {
        const now = new Date();
        const pad = value => String(value).padStart(2, "0");
        const fields = {
            "Y": now.getFullYear(),
            "m": pad(now.getMonth() + 1),
            "d": pad(now.getDate()),
            "H": pad(now.getHours()),
            "M": pad(now.getMinutes()),
            "S": pad(now.getSeconds())
        };
        return pattern.replace(/%([YmdHMS])/g, (_, key) => fields[key]);
    }

    function setPath(folderValue, nameValue) {
        NiriConfigService.setScreenshotOptions({
                                                   path: folderValue.replace(/\/+$/, "") + "/" + nameValue
                                               });
    }

    function setSaving(enabled) {
        const patch = {
            save: enabled
        };
        // niri's default location assumes an English Pictures folder; use the user's own.
        if (enabled && path.startsWith("~/Pictures/Screenshots/") && picturesFolder() !== "~/Pictures")
            patch.path = picturesFolder() + "/" + qsTr("Screenshots") + "/" + namePatterns[0];
        NiriConfigService.setScreenshotOptions(patch);
    }

    Component.onCompleted: NiriConfigService.refresh()
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
            message: NiriConfigService.busy || NiriConfigService.pendingScreenshotOptions !== null ? qsTr(
                                                                                                         "Saving…") :
                                                                                                     qsTr("Screenshots are always copied to the clipboard")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NiriConfigService.error !== "" || NiriConfigService.readError !== ""
            tone: "error"
            message: NiriConfigService.error || NiriConfigService.readError
        }

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Enable screenshot settings")
            description: qsTr(
                             "Clavis takes over where niri saves screenshots, starting from your current values.")
            integrationState: NiriConfigService.state("screenshots")
            busy: NiriConfigService.busy
            blocked: NiriConfigService.busy
            onSetupRequested: NiriConfigService.setup("screenshots")
        }

        SettingsSection {
            id: saveSection
            Layout.fillWidth: true
            title: saveAnchor.title
            iconName: "screenshot_monitor"
            SettingsSearchAnchor {
                id: saveAnchor
                target: saveSection
                declaration:
                    '{"id":"general.screenshots.section.saving","route":"general.screenshots","title":"Saving screenshots","context":"ScreenshotsPage","icon":"screenshot_monitor","aliases":["screenshot folder","print screen","save location"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Also save to a file")
                supportingText: qsTr("Applies to niri screenshots, such as Print and Mod+Shift+S")
                trailing: StyledSwitch {
                    objectName: "screenshotSaveSwitch"
                    checked: root.screenshots.save
                    enabled: root.editable
                    Accessible.name: qsTr("Also save to a file")
                    onToggled: root.setSaving(checked)
                }
            }

            MaterialFilledTextField {
                id: folderField
                Layout.fillWidth: true
                visible: root.screenshots.save
                enabled: root.editable
                labelText: qsTr("Folder")
                text: root.folder
                trailingContentWidth: Metrics.touchTarget
                onAccepted: root.setPath(text, root.fileName)
                onEditingFinished: if (text !== root.folder)
                                       root.setPath(text, root.fileName)

                trailingContent: Component {
                    IconButton {
                        anchors.centerIn: parent
                        iconName: "folder_open"
                        accessibleName: qsTr("Choose folder")
                        tooltipText: qsTr("Choose folder")
                        controlSize: Metrics.touchTarget
                        onClicked: folderPicker.openAt(root.folder.replace(/^~/, root.home))
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.screenshots.save
                title: qsTr("File name")
                supportingText: qsTr("For example: %1").arg(root.example(root.fileName))
                trailing: SearchSelectMenuField {
                    objectName: "screenshotNameField"
                    implicitWidth: 260
                    implicitHeight: 40
                    enabled: root.editable
                    options: {
                        const names = root.namePatterns.indexOf(root.fileName) >= 0 ? root.namePatterns :
                                                                                      root.namePatterns.concat(
                                                                                          [root.fileName]);
                        return names.map(name => ({
                            label: root.example(name),
                            value: name
                        }));
                    }
                        value: root.fileName
                        onAccepted: value => root.setPath(root.folder, value)
                    }
                    }
                    }

                        SettingsSection {
                        id: recordingSection
                        Layout.fillWidth: true
                        title: recordingAnchor.title
                        iconName: "videocam"
                        SettingsSearchAnchor {
                        id: recordingAnchor
                        target: recordingSection
                        declaration:
                        '{"id":"general.screenshots.section.recording","route":"general.screenshots","title":"Screen recording","context":"ScreenshotsPage","icon":"videocam","aliases":["recording folder","gif"]}'
                    }

                        SettingsActionRow {
                        Layout.fillWidth: true
                        iconName: "videocam"
                        text: qsTr("Recording save locations")
                        description: qsTr("Video, GIF and audio recordings are set in Keystone")
                        trailingIconName: "chevron_right"
                        onClicked: root.navigateRequested("keystone")
                    }
                    }
                    }

                        FilePickerWindow {
                        id: folderPicker

                        parentModal: root.parentModal
                        requiresParentWindow: true
                        selectionMode: FilePickerWindow.Folders
                        allowCurrentFolderSelection: true
                        dialogTitle: qsTr("Screenshot folder")
                        nameFilters: []
                        windowIconName: "folder_open"
                        emptyStateText: qsTr("This folder is empty")
                        selectionPrompt: qsTr("Choose folder")
                        acceptLabel: qsTr("Choose")
                        formatSummary: qsTr("Choose the current folder or a selected subfolder")
                        onAccepted: function (path, isDirectory) {
                        if (isDirectory)
                        root.setPath(root.shortPath(path), root.fileName);
                    }
                    }
                    }
