import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.seam.frame

Scope {
  id: root

  property bool failed: false
  property bool opened: false
  property string errorString: ""
  property real revealProgress: 0
  property int timeoutDuration: failed ? 12000 : 2600
  property int timeoutRemaining: 0

  function showPopup(isFailure, error) {
    failed = isFailure;
    errorString = error || "";
    timeoutDuration = isFailure ? 12000 : 2600;
    timeoutRemaining = timeoutDuration;
    opened = true;
    revealProgress = 1;
    dismissTimer.restart();
  }

  function closePopup() {
    opened = false;
    revealProgress = 0;
    dismissTimer.stop();
  }

  Connections {
    target: Quickshell

    function onReloadCompleted() {
      root.showPopup(false, "Configuration loaded successfully");
    }

    function onReloadFailed(error: string) {
      root.showPopup(true, error);
    }
  }

  Behavior on revealProgress {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }

  Timer {
    id: dismissTimer
    interval: 50
    repeat: true
    onTriggered: {
      if (panelHover.hovered)
        return;
      root.timeoutRemaining -= interval;
      if (root.timeoutRemaining <= 0)
        root.closePopup();
    }
  }

  PanelWindow {
    visible: root.opened || root.revealProgress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "comic-reload-popup"

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: 390
    mask: Region { item: reloadPanel }

    Item {
      id: reloadPanel
      anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: FrameConfig.thickness
      }

      width: 120 + 440 * root.revealProgress
      height: 36 + ((root.failed ? 250 : 76) - 36) * root.revealProgress
      opacity: root.revealProgress
      clip: true

      readonly property real bottomRadius: Appearance.radius(18 + 6 * root.revealProgress)

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: Appearance.m3colors.m3surface
          startX: 0
          startY: 0
          PathLine { x: reloadPanel.width; y: 0 }
          PathLine { x: reloadPanel.width; y: reloadPanel.height - reloadPanel.bottomRadius }
          PathArc {
            x: reloadPanel.width - reloadPanel.bottomRadius
            y: reloadPanel.height
            radiusX: reloadPanel.bottomRadius
            radiusY: reloadPanel.bottomRadius
          }
          PathLine { x: reloadPanel.bottomRadius; y: reloadPanel.height }
          PathArc {
            x: 0
            y: reloadPanel.height - reloadPanel.bottomRadius
            radiusX: reloadPanel.bottomRadius
            radiusY: reloadPanel.bottomRadius
          }
          PathLine { x: 0; y: 0 }
        }
      }

      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      HoverHandler { id: panelHover }

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

        Row {
          width: parent.width
          spacing: 12

          Rectangle {
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: root.failed ? Appearance.m3colors.m3errorContainer : Appearance.m3colors.m3primaryContainer

            Text {
              anchors.centerIn: parent
              text: root.failed ? "!" : "✓"
              color: root.failed ? Appearance.m3colors.m3onErrorContainer : Appearance.m3colors.m3onPrimaryContainer
              font.pixelSize: 20
              font.bold: true
            }
          }

          Column {
            width: parent.width - 92
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              width: parent.width
              text: root.failed ? "Config reload failed" : "Quickshell reloaded"
              color: Appearance.m3colors.m3onSurface
              font.pixelSize: 17
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.failed ? "The previous configuration is still running" : root.errorString
              color: Appearance.m3colors.m3onSurfaceVariant
              font.pixelSize: 11
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: closeHover.hovered ? Appearance.m3colors.m3surfaceContainerHighest : Appearance.m3colors.m3surfaceContainerHigh

            Text {
              anchors.centerIn: parent
              text: "×"
              color: Appearance.m3colors.m3onSurface
              font.pixelSize: 23
            }

            HoverHandler { id: closeHover }
            TapHandler { onTapped: root.closePopup() }
          }
        }

        Rectangle {
          visible: root.failed
          width: parent.width
          height: root.failed ? 142 : 0
          radius: Appearance.radius(14)
          color: Appearance.m3colors.m3surfaceContainer
          clip: true

          Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: errorText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
              id: errorText
              width: parent.width
              text: root.errorString
              color: Appearance.m3colors.m3onSurfaceVariant
              font.family: "monospace"
              font.pixelSize: 11
              wrapMode: Text.WrapAnywhere
            }
          }
        }
      }

      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          leftMargin: 16
          rightMargin: 16
          bottomMargin: 8
        }
        height: 4
        radius: Appearance.radius(2)
        color: Appearance.m3colors.m3surfaceContainerHighest

        Rectangle {
          width: parent.width * Math.max(0, root.timeoutRemaining / Math.max(1, root.timeoutDuration))
          height: parent.height
          radius: parent.radius
          color: root.failed ? Appearance.m3colors.m3error : Appearance.m3colors.m3primary
        }
      }
    }

    RoundCorner {
      anchors { top: reloadPanel.top; right: reloadPanel.left; rightMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.m3colors.m3surface
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      anchors { top: reloadPanel.top; left: reloadPanel.right; leftMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.m3colors.m3surface
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopLeft
    }

  }
}
