import QtQuick
import QtQuick.Shapes
import qs.modules.common

Item {
  id: root

  default property alias content: contentRow.data
  property real horizontalPadding: 12
  property real contentSpacing: 7
  property bool leftTopCorner: true
  property bool rightTopCorner: true
  property bool leftBottomCorner: false
  property bool rightBottomCorner: false
  readonly property bool bottomAttached: Config.options.bar.bottom
  property real entranceProgress: 0


  readonly property real bottomRadius: Appearance.radius(height / 2)
  readonly property real leftBottomRadius: leftBottomCorner ? 0 : bottomRadius
  readonly property real rightBottomRadius: rightBottomCorner ? 0 : bottomRadius

  width: contentRow.implicitWidth + horizontalPadding * 2
  height: 30
  opacity: entranceProgress
  scale: 0.92 + entranceProgress * 0.08
  transform: Translate { y: (1 - root.entranceProgress) * -12 }

  Component.onCompleted: Qt.callLater(() => entranceProgress = 1)

  Behavior on entranceProgress {
    NumberAnimation { duration: 420; easing.type: Easing.OutBack }
  }

  Behavior on width {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
      origin.y: root.height / 2
      yScale: root.bottomAttached ? -1 : 1
    }

    ShapePath {
      strokeWidth: 0
      fillColor: Appearance.colors.colLayer0
      Behavior on fillColor { ColorAnimation { duration: 260 } }
      startX: 0
      startY: 0
      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width; y: root.height - root.rightBottomRadius }
      PathArc {
        x: root.width - root.rightBottomRadius
        y: root.height
        radiusX: root.rightBottomRadius
        radiusY: root.rightBottomRadius
      }
      PathLine { x: root.leftBottomRadius; y: root.height }
      PathArc {
        x: 0
        y: root.height - root.leftBottomRadius
        radiusX: root.leftBottomRadius
        radiusY: root.leftBottomRadius
      }
      PathLine { x: 0; y: 0 }
    }
  }

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: root.contentSpacing
  }

  Item {
    anchors.fill: parent
    transform: Scale {
      origin.y: root.height / 2
      yScale: root.bottomAttached ? -1 : 1
    }

    RoundCorner {
      visible: root.leftTopCorner
      anchors { top: parent.top; right: parent.left; rightMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.colors.colLayer0
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      visible: root.rightTopCorner
      anchors { top: parent.top; left: parent.right; leftMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.colors.colLayer0
      corner: RoundCorner.CornerEnum.TopLeft
    }
    RoundCorner {
      visible: root.rightBottomCorner
      anchors { top: parent.bottom; right: parent.right; topMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.colors.colLayer0
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      visible: root.leftBottomCorner
      anchors { top: parent.bottom; left: parent.left; topMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.colors.colLayer0
      corner: RoundCorner.CornerEnum.TopLeft
    }
  }
}
