import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import qs.Modules.FilePicker

Item {
    id: root

    property var screen: null
    signal closeRequested

    onVisibleChanged: {
        if (visible)
            QuickAccessService.refreshBookmarks();
    }

    FilePickerWindow {
        id: folderPicker
        targetScreen: root.screen
        dialogTitle: qsTr("Add folder")
        description: ""
        selectionMode: FilePickerWindow.Folders
        allowCurrentFolderSelection: true
        nameFilters: []
        windowIconName: "folder_open"
        emptyStateText: qsTr("No subfolders")
        selectionPrompt: qsTr("Choose a folder")
        acceptLabel: qsTr("Add folder")
        formatSummary: ""
        startPath: Paths.homeDir
        onAccepted: (path, isDirectory) => {
            if (isDirectory)
                QuickAccessService.addFolder("file://" + path.split("/").map(part => encodeURIComponent(part)).join(
                                                 "/"));
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: qsTr("Quick access")
                font.family: Fonts.ui
                font.pixelSize: 22
                font.bold: true
                color: Appearance.colors.colOnLayer0
            }

            ActionButton {
                text: qsTr("Add folder")
                iconName: "create_new_folder"
                filled: true
                enabled: QuickAccessService.ready && QuickAccessService.writable
                onClicked: folderPicker.openAt(folderPicker.currentPath)
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("File manager bookmarks appear here automatically. Add one in Files with Ctrl+D.")
            font.family: Fonts.ui
            font.pixelSize: 12
            color: Appearance.colors.colOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: message !== ""
            tone: "error"
            message: QuickAccessService.errorMessage || QuickAccessService.bookmarkError
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: QuickAccessService.ready && QuickAccessService.folders.length === 0

                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "folder_open"
                    iconSize: 56
                    color: Appearance.colors.colPrimary
                }

                Text {
                    text: qsTr("Add your frequently used folders here.")
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    color: Appearance.colors.colOnLayer0
                }
            }

            ListView {
                id: folderList
                anchors.fill: parent
                clip: true
                spacing: 8
                model: QuickAccessService.folders
                ScrollBar.vertical: ScrollBar {}

                delegate: RowLayout {
                    id: folderRow
                    required property string modelData
                    width: folderList.width - 16
                    height: 72
                    spacing: 8

                    RippleButton {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        buttonRadius: Appearance.rounding.normal
                        containerColor: Appearance.colors.colLayer2
                        Accessible.name: QuickAccessService.folderPath(folderRow.modelData)
                        focusPolicy: Qt.StrongFocus
                        onClicked: {
                            if (QuickAccessService.openFolder(folderRow.modelData))
                                root.closeRequested();
                        }

                        contentItem: RowLayout {
                            spacing: 14

                            MaterialSymbol {
                                text: "folder"
                                iconSize: 30
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: QuickAccessService.folderName(folderRow.modelData)
                                    textFormat: Text.PlainText
                                    font.family: Fonts.ui
                                    font.pixelSize: 16
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: QuickAccessService.folderPath(folderRow.modelData)
                                    textFormat: Text.PlainText
                                    font.family: Fonts.ui
                                    font.pixelSize: 12
                                    color: Appearance.colors.colOnSurfaceVariant
                                    elide: Text.ElideMiddle
                                }
                            }

                            MaterialSymbol {
                                text: "open_in_new"
                                iconSize: 20
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    IconButton {
                        iconName: "close"
                        accessibleName: qsTr("Remove from Quick access")
                        visible: !QuickAccessService.isBookmark(folderRow.modelData)
                        enabled: QuickAccessService.writable
                        onClicked: QuickAccessService.removeFolder(folderRow.modelData)
                    }

                    Item {
                        Layout.preferredWidth: 40
                        Layout.fillHeight: true
                        visible: QuickAccessService.isBookmark(folderRow.modelData)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "bookmark"
                            iconSize: 22
                            color: Appearance.colors.colPrimary
                        }

                        HoverHandler {
                            id: bookmarkHover
                        }

                        StyledToolTip {
                            text: qsTr("File manager bookmark. Rename or remove it in Files.")
                            extraVisibleCondition: bookmarkHover.hovered
                        }
                    }
                }
            }
        }
    }
}
