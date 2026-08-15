import QtQuick
import qs
import qs.modules.common

Rectangle {

  width: 22
  height: 22
  radius: Appearance.radius(height / 2)
  color: buttonHover.hovered ? Appearance.m3colors.m3primaryContainer : Appearance.m3colors.m3surfaceContainerHigh
  scale: buttonHover.hovered ? 1.08 : 1

  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Text {
    anchors.centerIn: parent
    text: "settings"
    color: Appearance.m3colors.m3onSurface
    font.family: Appearance.font.family.iconMaterial
    font.pixelSize: 13
  }

  HoverHandler { id: buttonHover }
  TapHandler {
    onTapped: {
      const opening = !GlobalStates.settingsOpen
      GlobalStates.settingsOpen = opening
      if (opening) {
        GlobalStates.sidebarLeftOpen = false
        GlobalStates.sidebarRightOpen = false
        GlobalStates.searchOpen = false
        GlobalStates.sessionOpen = false
      }
    }
  }
}
