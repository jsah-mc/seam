import Quickshell
import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
  width: 22
  height: 22
  radius: Appearance.radius(height / 2)
  color: buttonHover.hovered ? Appearance.m3colors.m3primaryContainer : Appearance.m3colors.m3surfaceContainerHigh
  scale: buttonHover.hovered ? 1.08 : 1

  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  CustomIcon {
    anchors.centerIn: parent
    width: 14
    height: 14
    source: "spark-symbolic.svg"
    colorize: true
    color: Appearance.m3colors.m3onSurface
  }

  HoverHandler { id: buttonHover }
  TapHandler {
    onTapped: {
      const opening = !GlobalStates.sidebarLeftOpen
      GlobalStates.sidebarLeftOpen = opening
      if (opening) {
        GlobalStates.sidebarRightOpen = false
        GlobalStates.searchOpen = false
      }
    }
  }
}
