//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
import Quickshell
import QtQuick
import qs.modules.seam.pill
import qs.modules.seam.launcher
import qs.modules.seam.wallpaper
import qs.modules.seam.screenshot as Screenshot
import qs.modules.seam.lock
import qs.modules.seam.frame
import qs.modules.seam.powermenu
import qs.modules.seam.dock
import qs.modules.seam.polkit
import qs.modules.seam.settings
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarRight
import qs.modules.ii.notificationPopup
import qs.services
Scope {
  // Seam shell with End-4 modules adapted to Seam's frame and pills.
  Pill {}
  Launcher {}
  Wallpaper {}
  Dock {}
  Settings {}
  PowerMenu {}
  SidebarLeft {}
  SidebarRight {}
  NotificationPopup {}
  Lock {}
  ReloadPopup {}
  PolkitDialog {}
  // Keep the frame above every shell surface.
  ScreenFrame {}

  Component.onCompleted: {
    MaterialThemeLoader.reapplyTheme()
    Screenshot.Controller.init()
  }
}
