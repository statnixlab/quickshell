import QtQuick
import QtTest
import "../../Services/DockBadges.js" as Badges

TestCase {
    name: "DockBadges"
    readonly property var applications: [
        {
            id: "qq",
            name: "QQ",
            startupClass: "QQ"
        },
        {
            id: "wechat",
            name: "微信",
            startupClass: "wechat"
        }
    ]

    function test_countsSurvivePopupExpiryAndUseExactApplicationMetadata() {
        const notifications = [
                  {
                      desktopEntry: "qq.desktop",
                      dockUnread: true,
                      popup: false
                  },
                  {
                      appName: "QQ",
                      dockUnread: true
                  },
                  {
                      appName: "微信",
                      dockUnread: true
                  },
                  {
                      appName: "QQ helper",
                      dockUnread: true
                  },
                  {
                      appName: "QQ",
                      dockUnread: false
                  },
                  {
                      appName: "QQ",
                      dockUnread: true,
                      isTransient: true
                  },
                  {
                      appName: "QQ",
                      dockUnread: true,
                      localKind: "file-saved"
                  },
                  {
                      appName: "QQ"
                  }
              ];
        const counts = Badges.counts(notifications, applications, []);
        compare(counts["app:qq"], 2);
        compare(counts["app:wechat"], 1);
        compare(Object.keys(counts).length, 2);
        compare(Badges.total(counts), 3);
        compare(Badges.total(Badges.counts([], applications, [])), 0);
        compare(Badges.label(0), "");
        compare(Badges.label(99), "99");
        compare(Badges.label(100), "99+");
    }

    function test_focusAcknowledgesOnlyThatApplicationIncludingXwaylandClass() {
        const qq = {
            appName: "QQ",
            dockUnread: true
        };
        const wechat = {
            desktopEntry: "wechat",
            dockUnread: true
        };
        const windows = [
                  {
                      id: 1,
                      appId: "QQ",
                      isFocused: true
                  }
              ];
        const selected = Badges.focusedNotifications([qq, wechat], applications, windows);
        compare(Badges.total(Badges.counts([qq, wechat], applications, windows)), 2);
        compare(selected.length, 1);
        compare(selected[0], qq);
        selected.forEach(notification => notification.dockUnread = false);
        compare(Badges.counts([qq, wechat], applications, windows)["app:qq"], undefined);
        compare(Badges.counts([qq, wechat], applications, windows)["app:wechat"], 1);
        compare(Badges.total(Badges.counts([qq, wechat], applications, windows)), 1);
        compare(Badges.focusedNotifications([wechat], applications, []).length, 0);
    }

    function test_updatesPreserveReadStateAndHistoryMigrationStartsRead() {
        verify(Badges.unreadForArrival([], false));
        verify(Badges.unreadForArrival([
                                           {
                                               dockUnread: true
                                           }
                                       ], false));
        verify(!Badges.unreadForArrival([
                                            {
                                                dockUnread: false
                                            }
                                        ], false));
        verify(!Badges.unreadForArrival([
                                            {}
                                        ], false));
        verify(!Badges.unreadForArrival([], true));
        verify(!Badges.unreadForArrival([], false, true));
        verify(!Badges.unreadForArrival([
                                            {
                                                dockUnread: true
                                            }
                                        ], false, true));
        verify(Badges.unreadForArrival([], false, false));
    }

    function test_openingCenterAcknowledgesAllAppsWithoutDeletingHistory() {
        const notifications = [
                  {
                      appName: "QQ",
                      dockUnread: true,
                      summary: "First message"
                  },
                  {
                      appName: "微信",
                      dockUnread: true,
                      summary: "Second message"
                  },
                  {
                      appName: "QQ",
                      dockUnread: false,
                      summary: "Already read"
                  }
              ];
        compare(Badges.total(Badges.counts(notifications, applications, [])), 2);
        verify(Badges.acknowledgeAll(notifications));
        compare(Badges.total(Badges.counts(notifications, applications, [])), 0);
        compare(notifications.length, 3);
        compare(notifications[0].summary, "First message");
        compare(notifications[1].summary, "Second message");
        verify(!Badges.acknowledgeAll(notifications));
        verify(!Badges.unreadForArrival([notifications[0]], false, false));
        notifications.push({
                               appName: "QQ",
                               dockUnread: Badges.unreadForArrival([], false, false)
                           });
        compare(Badges.total(Badges.counts(notifications, applications, [])), 1);
    }

    function test_ambiguousNamesAndConflictingDesktopIdsAreNotGuessed() {
        const apps = [
                  {
                      id: "one",
                      name: "Shared"
                  },
                  {
                      id: "two",
                      name: "Shared"
                  }
              ];
        compare(Badges.keyForNotification({
                                              appName: "Shared"
                                          }, apps, []), "");
        compare(Badges.keyForNotification({
                                              desktopEntry: "unrelated",
                                              appName: "QQ"
                                          }, applications, []), "");
        compare(Badges.keyForNotification({
                                              appName: "Chat"
                                          }, [], [
                                              {
                                                  id: 8,
                                                  appId: "Chat"
                                              }
                                          ]), "window-app:Chat");
    }
}
