//@ pragma UseQApplication
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

import QtQuick
import Quickshell
import qs.Modules.DesktopReveal
import qs.Modules.StageManager
import qs.Modules.WindowOverview

ShellRoot {
    AppShell {}
    WindowOverviewHost {}
    StageManagerHost {}
    DesktopRevealHost {}
}
