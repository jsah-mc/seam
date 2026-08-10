import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import qs.modules.common

Scope {
  id: root

  property int frameWidth: FrameConfig.thickness
  readonly property int cornerRadius: FrameConfig.cornerRadius
  property color frameColor: FrameConfig.color
  property color outerCornerColor: FrameConfig.outerCornerColor

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: !GlobalStates.screenLocked && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "seam:screen-frame"

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      Rectangle {
        anchors {
          fill: parent
        }
        color: "transparent"
        radius: root.cornerRadius
        border.width: root.frameWidth
        border.color: root.frameColor
        Behavior on border.color { ColorAnimation { duration: 300 } }
      }

      RoundCorner {
        anchors { top: parent.top; left: parent.left }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.TopLeft
      }

      RoundCorner {
        anchors { top: parent.top; right: parent.right }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors { bottom: parent.bottom; left: parent.left }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.BottomLeft
      }

      RoundCorner {
        anchors { bottom: parent.bottom; right: parent.right }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.BottomRight
      }
    }
  }
}
