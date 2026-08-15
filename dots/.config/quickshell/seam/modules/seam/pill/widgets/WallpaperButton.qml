import Quickshell
import QtQuick
import qs.modules.common

Rectangle {

  width: 22
  height: 22
  radius: Appearance.radius(height / 2)
  color: buttonHover.hovered ? Appearance.m3colors.m3primaryContainer : Appearance.m3colors.m3surfaceContainerHigh
  scale: buttonHover.hovered ? 1.1 : 1

  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Text {
    anchors.centerIn: parent
    text: "wallpaper"
    color: Appearance.m3colors.m3onSurface
    font.family: Appearance.font.family.iconMaterial
    font.pixelSize: 13
  }

  HoverHandler { id: buttonHover }

  TapHandler {
    onTapped: Quickshell.execDetached(["qs", "ipc", "-c", "seam", "call", "wallpaper", "toggle"])
  }
}
