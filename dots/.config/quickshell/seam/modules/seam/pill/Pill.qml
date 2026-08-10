import Quickshell
import QtQuick
import qs.modules.seam.frame
import qs.modules.common

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      color: "transparent"

      anchors {
        top: !Config.options.bar.bottom
        bottom: Config.options.bar.bottom
        left: true
        right: true
      }

      implicitHeight: 44 + FrameConfig.thickness

      LeftPill {
        anchors { top: Config.options.bar.bottom ? undefined : parent.top; bottom: Config.options.bar.bottom ? parent.bottom : undefined; left: parent.left; topMargin: FrameConfig.thickness; bottomMargin: FrameConfig.thickness; leftMargin: FrameConfig.thickness }
      }

      CenterPill {
        anchors { top: Config.options.bar.bottom ? undefined : parent.top; bottom: Config.options.bar.bottom ? parent.bottom : undefined; horizontalCenter: parent.horizontalCenter; topMargin: FrameConfig.thickness; bottomMargin: FrameConfig.thickness }
      }

      RightPill {
        anchors { top: Config.options.bar.bottom ? undefined : parent.top; bottom: Config.options.bar.bottom ? parent.bottom : undefined; right: parent.right; topMargin: FrameConfig.thickness; bottomMargin: FrameConfig.thickness; rightMargin: FrameConfig.thickness }
      }
    }
  }
}
