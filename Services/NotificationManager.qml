pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Common
import Clavis.Niri
import "NotificationActivation.js" as NotificationActivation
import "DockBadges.js" as DockBadges

Singleton {
    id: root

    readonly property int defaultPopupTimeoutMs: UiPreferences.notificationPopupSeconds * 1000
    readonly property string notificationsDir: Paths.stateHome + "/notifications"
    readonly property string filePath: notificationsDir + "/notifications.json"
    readonly property bool silent: UiPreferences.dndEnabled
    readonly property bool centerVisible: WidgetState.dashboardSidebarOpen
                                          && WidgetState.dashboardSidebarView === "info"
    // A critical banner may pass through Do Not Disturb; ordinary ones never get popup state then.
    readonly property bool criticalPopupActive: UiPreferences.notificationCriticalBypassDnd && popupList.some(
                                                    notif => notif.urgency === NotificationUrgency.Critical)
    readonly property bool popupInhibited: centerVisible || (silent && !criticalPopupActive)
    readonly property bool hasNotifs: popupList.length > 0

    property bool historyReady: false
    property var pendingSavedFiles: []
    property int unread: 0
    property int idOffset: 0
    property int activationRevision: 0

    Connections {
        target: Niri
        function onWindowsChanged() {
            root.activationRevision += 1;
        }
    }
    property list<Notif> list: []
    property var popupList: list.filter(notif => notif.popup).sort((a, b) => b.receivedAt - a.receivedAt)
    property var latestTimeForApp: ({})
    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    signal notify(notification: var)
    signal discard(id: int)
    signal discardAll
    signal timeout(id: var)
    signal initDone

    component Notif: QtObject {
        id: wrapper

        required property int notificationId
        property int serverNotificationId: -1
        property Notification notification: null
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string desktopEntry: ""
        property string image: ""
        property bool isTransient: false
        property bool dockUnread: false
        property bool popup: false
        property double popupExpiresAt: 0
        property double popupStartedAt: 0
        property double receivedAt: Date.now()
        property string summary: ""
        property string localKind: ""
        property string filePath: ""
        property Timer timer: null
        property var urgency: NotificationUrgency.Normal
        property Connections closeConnection: Connections {
            target: wrapper.notification

            function onClosed(reason) {
                root.handleNativeClosed(wrapper.notificationId, reason);
            }
        }

        onNotificationChanged: {
            if (notification === null && serverNotificationId !== -1)
                root.detachNotification(notificationId);
        }
    }

    component NotifTimer: Timer {
        required property int notificationId
        running: true
        repeat: false

        onTriggered: {
            const notifObject = root.notificationById(notificationId);
            if (notifObject)
                notifObject.timer = null;
            destroy();
            root.expireNotification(notificationId);
        }
    }

    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    Component.onCompleted: ensureStoreDir.running = true

    onInitDone: {
        root.historyReady = true;
        const pending = root.pendingSavedFiles;
        root.pendingSavedFiles = [];
        pending.forEach(item => root.fileSaved(item.title, item.path));
    }

    Connections {
        target: FileActionService
        function onFinished(action, path, response) {
            if (!response || !response.ok)
                root.addLocal(qsTr("File action failed"), qsTr(
                                  "Could not open the saved file or its location: %1").arg(path));
            else if (!response.fileExists)
                root.addLocal(qsTr("File no longer exists"), qsTr("Opened the containing folder: %1").arg(
                                  path));
        }
    }

    function fileSaved(title, path) {
        if (typeof path !== "string" || !path.startsWith("/") || path.indexOf("\u0000") !== -1)
            return;
        if (!root.historyReady) {
            root.pendingSavedFiles = [...root.pendingSavedFiles,
                                      {
                                          title,
                                          path
                                      }
                    ];
            return;
        }
        root.addLocal(title, path, path);
    }

    function addLocal(title, body, filePath) {
        const now = Date.now();
        const notif = notifComponent.createObject(root, {
                                                      notificationId: ++root.idOffset,
                                                      appName: "Clavis Shell",
                                                      appIcon: "folder",
                                                      summary: title,
                                                      body: body.replace(/&/g, "&amp;").replace(/</g,
                                                                                                "&lt;").replace(
                                                                />/g, "&gt;"),
                                                      localKind: filePath ? "file-saved" : "",
                                                      filePath: filePath || "",
                                                      receivedAt: now,
                                                      urgency: NotificationUrgency.Low,
                                                      popup: !root.popupInhibitedFor("Clavis Shell",
                                                                                     NotificationUrgency.Low),
                                                      popupStartedAt: now,
                                                      popupExpiresAt: now + root.defaultPopupTimeoutMs
                                                  });
        notif.timer = notifTimerComponent.createObject(root, {
                                                           notificationId: notif.notificationId,
                                                           interval: root.defaultPopupTimeoutMs
                                                       });
        root.list = [...root.list, notif];
        if (notif.popup)
            root.unread++;
        root.trimPopupList(1);
        root.saveNotifications();
        root.notify(notif);
    }

    onListChanged: {
        const nextLatest = {};
        root.list.forEach(notif => {
            if (!nextLatest[notif.appName] || notif.receivedAt > nextLatest[notif.appName])
                nextLatest[notif.appName] = notif.receivedAt;
        });
        root.latestTimeForApp = nextLatest;
    }

    Process {
        id: ensureStoreDir
        command: ["mkdir", "-p", root.notificationsDir]
        running: false
        onExited: root.refresh()
    }

    // Notification sounds for new arrivals, never history or updates. WeChat
    // and QQ send notifications without playing audio themselves: they get
    // their own message sounds; every other app gets the sound it names in
    // the notification, or else the sound theme's message sound (macOS-style
    // with the macOS theme). One sound at a time, with a short per-kind
    // cooldown so bursts of notifications do not chime repeatedly.
    readonly property string wechatSoundFile: Paths.xdgDataHome + "/sounds/clavis/wechat-classic.wav"
    readonly property string qqSoundFile: "/opt/QQ/resources/app/resource/msg.wav"
    property var _soundCooldownUntil: ({})

    Process {
        id: notificationSound
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("Notification sound failed:", exitCode, command.join(" "));
        }
    }

    function notificationSoundKind(notification) {
        const desktopEntry = (notification.desktopEntry || "").toLowerCase();
        const appName = (notification.appName || "").toLowerCase();
        if (desktopEntry === "wechat" || desktopEntry === "wechat.desktop" || appName === "wechat" || appName
                === "weixin" || appName === "微信")
            return "wechat";
        if (desktopEntry === "qq" || desktopEntry === "qq.desktop" || appName === "qq")
            return "qq";
        return "other";
    }

    // canberra-gtk-play arguments for a notification, or [] when it stays silent.
    function notificationSoundSource(notification, kind) {
        const hints = notification.hints || {};
        if (kind === "wechat")
            return UiPreferences.wechatExtraSoundEnabled ? ["--file=" + root.wechatSoundFile] : [];
        if (kind === "qq")
            return UiPreferences.qqSoundEnabled ? ["--file=" + root.qqSoundFile] : [];
        if (!UiPreferences.notificationSoundEnabled)
            return [];
        const file = String(hints["sound-file"] || "");
        if (file.startsWith("/"))
            return ["--file=" + file];
        const name = String(hints["sound-name"] || "");
        return ["--id=" + (/^[a-z0-9][a-z0-9.-]*$/.test(name) ? name : "message-new-instant")];
    }

    function playNotificationSound(notification, isReplacement) {
        const hints = notification.hints || {};
        const muted = UiPreferences.notificationMutedApps.indexOf(notification.appName
                                                                  || notification.desktopEntry) >= 0;
        if (root.silent || muted || isReplacement || hints["suppress-sound"] || notification.urgency
                === NotificationUrgency.Low || notificationSound.running)
            return;
        const kind = root.notificationSoundKind(notification);
        const now = Date.now();
        if ((root._soundCooldownUntil[kind] || 0) > now)
            return;
        const source = root.notificationSoundSource(notification, kind);
        if (source.length === 0)
            return;
        const cooldown = Object.assign({}, root._soundCooldownUntil);
        cooldown[kind] = now + (kind === "other" ? 1500 : 3000);
        root._soundCooldownUntil = cooldown;
        notificationSound.command = ["canberra-gtk-play"].concat(source,
                                                                 ["--property=application.name=Clavis Notification",
                                                                  "--property=media.role=notification"]);
        notificationSound.running = true;
    }

    NotificationServer {
        id: notifServer

        actionsSupported: true
        actionIconsSupported: false
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        inlineReplySupported: false
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            const replaced = root.list.filter(notif => notif.serverNotificationId === notification.id);
            replaced.forEach(notif => root.stopPopupTimer(notif));

            const now = Date.now();
            const timeoutMs = root.popupTimeoutMs(notification.expireTimeout, notification.urgency);
            root.idOffset++;
            const newNotifObject = notifComponent.createObject(root, {
                                                                   "notificationId": root.idOffset,
                                                                   "serverNotificationId": notification.id,
                                                                   "notification": notification,
                                                                   "appIcon": notification.appIcon || "",
                                                                   "appName": notification.appName
                                                                              || notification.desktopEntry
                                                                              || qsTr("System"),
                                                                   "body": notification.body || "",
                                                                   "desktopEntry": notification.desktopEntry
                                                                                   || "",
                                                                   "image": notification.image || "",
                                                                   "isTransient": notification.transient,
                                                                   "dockUnread": DockBadges.unreadForArrival(
                                                                                     replaced, notification.transient,
                                                                                     root.centerVisible),
                                                                   "summary": notification.summary
                                                                              || notification.appName || qsTr(
                                                                                  "Notification"),
                                                                   "receivedAt": now,
                                                                   "urgency": notification.urgency
                                                               });

            if (timeoutMs > 0) {
                newNotifObject.popupStartedAt = now;
                newNotifObject.popupExpiresAt = now + timeoutMs;
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                                                                            "notificationId":
                                                                            newNotifObject.notificationId,
                                                                            "interval": timeoutMs
                                                                        });
            }

            if (!root.popupInhibitedFor(newNotifObject.appName, notification.urgency)) {
                newNotifObject.popup = true;
                root.unread++;
            }

            root.list = [...root.list.filter(notif => notif.serverNotificationId !== notification.id),
                         newNotifObject,];
            replaced.forEach(notif => Qt.callLater(() => notif.destroy()));
            root.trimPopupList(1);
            root.saveNotifications();
            root.playNotificationSound(notification, replaced.length > 0);
            root.notify(newNotifObject);
        }
    }

    FileView {
        id: notifFileView
        path: root.filePath

        onLoaded: {
            try {
                const fileContents = notifFileView.text();
                const loaded = JSON.parse(fileContents && fileContents.trim() !== "" ? fileContents : "[]");
                if (!Array.isArray(loaded)) {
                    root.list = [];
                    root.initDone();
                    return;
                }

                let maxId = 0;
                root.list = loaded.map(notif => {
                    const notificationId = Number(notif.notificationId || notif.id || 0);
                    maxId = Math.max(maxId, notificationId);
                    return notifComponent.createObject(root, {
                                                           "notificationId": notificationId,
                                                           "dockUnread": notif.dockUnread === true &&
                                                                         !root.centerVisible,
                                                           "localKind": notif.localKind === "file-saved"
                                                                        ? "file-saved" : "",
                                                           "filePath": notif.localKind === "file-saved"
                                                                       && typeof notif.filePath === "string"
                                                                       && notif.filePath.startsWith("/")
                                                                       && notif.filePath.indexOf("\u0000")
                                                                       === -1 ? notif.filePath : "",
                                                           "appIcon": root.durableHistorySource(notif.appIcon),
                                                           "appName": notif.appName || qsTr("System"),
                                                           "body": notif.body || "",
                                                           "desktopEntry": notif.desktopEntry || "",
                                                           "image": root.durableHistorySource(notif.image),
                                                           "summary": notif.summary || notif.appName || qsTr(
                                                                          "Notification"),
                                                           "receivedAt": Number(notif.receivedAt
                                                                                || notif.time) || Date.now(),
                                                           "urgency": notif.urgency
                                                                      ?? NotificationUrgency.Normal
                                                       });
                });
                root.idOffset = maxId;
                root.saveNotifications();
                root.initDone();
            } catch (error) {
                console.warn("NotificationManager failed to load history:", error);
                root.list = [];
                root.idOffset = 0;
                root.initDone();
            }
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.list = [];
                root.saveNotifications();
                root.initDone();
            } else {
                console.warn("NotificationManager failed to load notification file:", error);
                root.initDone();
            }
        }
    }

    function notificationById(id) {
        return root.list.find(notif => notif.notificationId === id) || null;
    }

    function popupTimeoutMs(expireTimeoutSeconds, urgency) {
        // Ordinary banners must not pin the island indefinitely. The snapshot
        // remains in history after expiry, so unread messages are still available.
        if (expireTimeoutSeconds === 0 && urgency === NotificationUrgency.Critical)
            return 0;
        if (!Number.isFinite(expireTimeoutSeconds) || expireTimeoutSeconds <= 0)
            return root.defaultPopupTimeoutMs;
        const requestedMs = Math.max(1, Math.round(expireTimeoutSeconds * 1000));
        return urgency === NotificationUrgency.Critical ? requestedMs : Math.min(root.defaultPopupTimeoutMs,
                                                                                 requestedMs);
    }

    function nativeActions(notifObject) {
        if (notifObject && notifObject.localKind === "file-saved" && notifObject.filePath) {
            const path = notifObject.filePath;
            return [
                        {
                            identifier: "default",
                            text: qsTr("Show in folder"),
                            invoke: () => FileActionService.run("reveal", path)
                        },
                        {
                            identifier: "reveal",
                            text: qsTr("Show in folder"),
                            invoke: () => FileActionService.run("reveal", path)
                        },
                        {
                            identifier: "open",
                            text: qsTr("Open"),
                            invoke: () => FileActionService.run("open", path)
                        }
                    ];
        }
        return notifObject && notifObject.notification && notifObject.notification.actions
                ? notifObject.notification.actions : [];
    }

    function applicationTarget(notifObject) {
        // searchWindows is an invokable, not a notifying property. Include
        // the revision so a window arriving later enables the notification.
        const revision = root.activationRevision;
        return NotificationActivation.resolve(notifObject, ApplicationService.applications, Niri.searchWindows(
                                                  ""));
    }

    function focusNotificationWindow(id) {
        // Resolve again at click time; never launch an app for a stale notification.
        const target = root.applicationTarget(root.notificationById(id));
        return target && target.window ? Niri.focusWindow(target.window.id) : false;
    }

    function defaultAction(notifObject) {
        const nativeAction = root.nativeActions(notifObject).find(action => action.identifier === "default");
        if (nativeAction) {
            const id = notifObject.notificationId;
            return {
                identifier: "default",
                text: nativeAction.text || qsTr("Open"),
                invoke: () => {
                    nativeAction.invoke();
                    // XWayland apps may handle the action but cannot raise
                    // their own window across workspaces on Niri.
                    root.focusNotificationWindow(id);
                    return true;
                }
            };
        }
        const target = root.applicationTarget(notifObject);
        if (!target || !target.window)
            return null;
        const id = notifObject.notificationId;
        return {
            identifier: "default",
            text: qsTr("Focus application window"),
            invoke: () => root.focusNotificationWindow(id)
        };
    }

    function normalActions(notifObject) {
        return root.nativeActions(notifObject).filter(action => action.identifier !== "default");
    }

    function durableHistorySource(source) {
        const value = source || "";
        return value.startsWith("image://qsimage/") ? "" : value;
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "localKind": notif.localKind,
            "filePath": notif.filePath,
            "appIcon": root.durableHistorySource(notif.appIcon),
            "appName": notif.appName,
            "body": notif.body,
            "desktopEntry": notif.desktopEntry,
            "dockUnread": notif.dockUnread,
            "image": root.durableHistorySource(notif.image),
            "receivedAt": notif.receivedAt,
            "summary": notif.summary,
            "urgency": notif.urgency
        };
    }

    function stringifyList(notifications) {
        return JSON.stringify(notifications.filter(notif => !notif.isTransient).map(notif => root.notifToJSON(
                                                                                                 notif)), null,
                              2);
    }

    function refresh() {
        notifFileView.reload();
    }

    function saveNotifications() {
        notifFileView.setText(root.stringifyList(root.list));
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].receivedAt - groups[a].receivedAt);
    }

    function groupsForList(notifications) {
        const groups = {};
        notifications.forEach(notif => {
            const appName = notif.appName || qsTr("System");
            if (!groups[appName]) {
                groups[appName] = {
                    appName,
                    appIcon: notif.appIcon,
                    desktopEntry: notif.desktopEntry,
                    notifications: [],
                    receivedAt: 0
                };
            }
            groups[appName].notifications.push(notif);
            groups[appName].receivedAt = root.latestTimeForApp[appName] || notif.receivedAt;
            if (!groups[appName].appIcon && notif.appIcon)
                groups[appName].appIcon = notif.appIcon;
            if (!groups[appName].desktopEntry && notif.desktopEntry)
                groups[appName].desktopEntry = notif.desktopEntry;
        });
        return groups;
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    function stopPopupTimer(notifObject) {
        if (!notifObject || !notifObject.timer)
            return;
        notifObject.timer.stop();
        notifObject.timer.destroy();
        notifObject.timer = null;
    }

    function hidePopup(notifObject) {
        if (notifObject)
            notifObject.popup = false;
    }

    function finishPopupLifetime(notifObject) {
        if (!notifObject)
            return;
        root.stopPopupTimer(notifObject);
        notifObject.popup = false;
        notifObject.popupStartedAt = 0;
        notifObject.popupExpiresAt = 0;
    }

    function trimPopupList(maxCount) {
        const popups = root.list.filter(notif => notif.popup).sort((a, b) => b.receivedAt - a.receivedAt
                                                                             || b.notificationId
                                                                             - a.notificationId);
        for (let i = maxCount; i < popups.length; i++)
            root.hidePopup(popups[i]);
        if (popups.length > maxCount)
            root.triggerListChange();
    }

    // Banners stay hidden while the center is open, for muted apps, and in Do Not Disturb
    // unless critical notifications are allowed through.
    function popupInhibitedFor(appName, urgency) {
        if (root.centerVisible || UiPreferences.notificationMutedApps.indexOf(appName) >= 0)
            return true;
        return root.silent && !(urgency === NotificationUrgency.Critical
                                && UiPreferences.notificationCriticalBypassDnd);
    }

    function setSilent(value) {
        UiPreferences.setDndEnabled(value);
    }

    function markAllRead() {
        root.unread = 0;
        if (DockBadges.acknowledgeAll(root.list))
            root.saveNotifications();
    }

    function detachNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        if (notifObject.isTransient) {
            root.removeSnapshot(id);
            return;
        }
        root.finishPopupLifetime(notifObject);
        notifObject.appIcon = root.durableHistorySource(notifObject.appIcon);
        notifObject.image = root.durableHistorySource(notifObject.image);
        notifObject.serverNotificationId = -1;
        notifObject.notification = null;
        root.triggerListChange();
        root.saveNotifications();
    }

    function handleNativeClosed(id, reason) {
        root.detachNotification(id);
    }

    function removeSnapshot(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        root.stopPopupTimer(notifObject);
        root.list = root.list.filter(candidate => candidate.notificationId !== id);
        root.saveNotifications();
        Qt.callLater(() => notifObject.destroy());
    }

    function dismissPopup(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        const nativeNotification = notifObject.notification;
        root.finishPopupLifetime(notifObject);
        if (nativeNotification)
            nativeNotification.dismiss();
        else if (notifObject.isTransient)
            root.removeSnapshot(id);
        root.triggerListChange();
    }

    function expireNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        const nativeNotification = notifObject.notification;
        root.finishPopupLifetime(notifObject);
        if (nativeNotification)
            nativeNotification.expire();
        else if (notifObject.isTransient)
            root.removeSnapshot(id);
        root.triggerListChange();
        root.timeout(id);
    }

    function discardNotification(id) {
        root.discardNotifications([id]);
    }

    function discardNotifications(ids) {
        const targetIds = new Set(ids || []);
        const removed = root.list.filter(notif => targetIds.has(notif.notificationId));
        if (removed.length === 0)
            return;
        removed.forEach(notif => root.stopPopupTimer(notif));
        root.list = root.list.filter(candidate => !targetIds.has(candidate.notificationId));
        root.saveNotifications();
        removed.forEach(notif => {
            if (notif.notification)
                notif.notification.dismiss();
            root.discard(notif.notificationId);
            Qt.callLater(() => notif.destroy());
        });
    }

    function discardAllNotifications() {
        const removed = root.list.slice();
        removed.forEach(notif => root.stopPopupTimer(notif));
        root.list = [];
        root.saveNotifications();
        removed.forEach(notif => {
            if (notif.notification)
                notif.notification.dismiss();
            Qt.callLater(() => notif.destroy());
        });
        root.discardAll();
    }

    function hideAllPopups() {
        root.popupList.forEach(notif => root.hidePopup(notif));
        root.triggerListChange();
    }

    function invokeDefaultAction(id) {
        const notifObject = root.notificationById(id);
        const action = root.defaultAction(notifObject);
        if (!action)
            return false;
        root.finishPopupLifetime(notifObject);
        root.triggerListChange();
        WidgetState.closeAllPopups();
        // Unmapping the notification surface can otherwise restore focus
        // over the application activation performed earlier in this callback.
        Qt.callLater(() => action.invoke());
        return true;
    }

    function invokeAction(action) {
        if (action)
            action.invoke();
    }
}
