#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <tuple>

struct NiriWorkspace {
    quint64 id = 0;
    int index = 0;
    QString name;
    QString output;
    bool isActive = false;
    bool isFocused = false;
    bool isUrgent = false;
    quint64 activeWindowId = 0;
    int windowCount = 0;
    int tiledWindowCount = 0;
    int tiledColumnCount = 0;
    QVariantList icons;
};

struct NiriWindow {
    quint64 id = 0;
    QString title;
    QString appId;
    QString appName;
    qint64 pid = -1;
    quint64 workspaceId = 0;
    bool isFocused = false;
    bool isFloating = false;
    bool isMinimized = false;
    bool isUrgent = false;
    int layoutColumn = 999999;
    int layoutRow = 999999;
    bool hasLayoutPosition = false;
    QString iconPath;

    bool operator==(const NiriWindow &other) const
    {
        return std::tie(id, title, appId, appName, pid, workspaceId, isFocused, isFloating, isMinimized,
                        isUrgent, layoutColumn, layoutRow, hasLayoutPosition, iconPath) ==
               std::tie(other.id, other.title, other.appId, other.appName, other.pid, other.workspaceId,
                        other.isFocused, other.isFloating, other.isMinimized, other.isUrgent,
                        other.layoutColumn, other.layoutRow, other.hasLayoutPosition, other.iconPath);
    }
};

struct NiriOutput {
    QString name;
    QString make;
    QString model;
    QString serial;
    int logicalX = 999999;
    int logicalY = 999999;
    int logicalWidth = 0;
    int logicalHeight = 0;
    double scale = 1.0;
    QString transform;
    QString currentMode;
    QVariantList modes;
    bool enabled = true;
    bool vrrSupported = false;
    bool vrrEnabled = false;
};
