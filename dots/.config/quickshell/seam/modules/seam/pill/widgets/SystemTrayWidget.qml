import QtQuick
import qs.modules.common
import qs.modules.seam.pill.widgets.systray as End4Tray

Rectangle {
  id: root

  implicitWidth: tray.implicitWidth + 8
  implicitHeight: 22
  radius: Appearance.radius(height / 2)
  color: Appearance.colors.colLayer0
  visible: tray.implicitWidth > 0

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  End4Tray.SysTray {
    id: tray
    anchors.centerIn: parent
    vertical: false
    invertSide: false
    showSeparator: false
    showOverflowMenu: true
  }
}
