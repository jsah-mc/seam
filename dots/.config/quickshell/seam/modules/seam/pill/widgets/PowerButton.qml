import Quickshell
import QtQuick
import qs
import qs.modules.common

Rectangle {
  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/ttf-material-symbols-variable/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" }
  width: 22
  height: 22
  radius: Appearance.radius(height / 2)
  color: buttonHover.hovered ? Appearance.m3colors.m3errorContainer : Appearance.m3colors.m3surfaceContainerHigh
  scale: buttonHover.hovered ? 1.08 : 1
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Text { anchors.centerIn: parent; text: "power_settings_new"; color: buttonHover.hovered ? Appearance.m3colors.m3onErrorContainer : Appearance.m3colors.m3onSurface; font.family: materialIcons.name; font.pixelSize: 13 }
  HoverHandler { id: buttonHover }
  TapHandler {
    onTapped: {
      GlobalStates.sessionOpen = !GlobalStates.sessionOpen
      if (GlobalStates.sessionOpen) {
        GlobalStates.sidebarLeftOpen = false
        GlobalStates.sidebarRightOpen = false
        GlobalStates.searchOpen = false
      }
    }
  }
}
