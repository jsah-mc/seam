import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.seam.frame

Scope {
  id: root

  property var results: []
  property real revealProgress: GlobalStates.searchOpen ? 1 : 0

  Behavior on revealProgress {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }

  function refreshResults() {
    const query = searchBar.searchInput.text.trim()
    root.results = query.length > 0 ? AppSearch.fuzzyQuery(query) : AppSearch.list
    resultsView.currentIndex = root.results.length > 0 ? 0 : -1
  }

  function close() {
    GlobalStates.searchOpen = false
  }

  function launch(index) {
    const entry = root.results[index]
    if (!entry)
      return
    entry.execute()
    root.close()
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
    function open(): void { GlobalStates.searchOpen = true }
    function close(): void { GlobalStates.searchOpen = false }
  }

  GlobalShortcut {
    name: "launcherToggle"
    description: "Toggle the application launcher"
    onPressed: GlobalStates.searchOpen = !GlobalStates.searchOpen
  }

  PanelWindow {
    id: launcherWindow
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    implicitHeight: screen?.height ?? 1080
    WlrLayershell.namespace: "seam:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.searchOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: GlobalStates.searchOpen ? launcherSurface : null }

    Connections {
      target: GlobalStates
      function onSearchOpenChanged() {
        if (GlobalStates.searchOpen) {
        searchBar.searchInput.text = ""
        root.refreshResults()
        searchBar.forceFocus()
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Item {
      id: launcherSurface
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: FrameConfig.thickness }
      width: card.width + Appearance.radius(28)
      height: card.height
    }

    Rectangle {
      id: card
      anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: FrameConfig.thickness
      }
      readonly property real targetWidth: Math.min(760, parent.width - 24)
      readonly property real targetHeight: Math.min(540, parent.height - 64)
      width: 120 + (targetWidth - 120) * root.revealProgress
      height: 36 + (targetHeight - 36) * root.revealProgress
      topLeftRadius: 0
      topRightRadius: 0
      bottomLeftRadius: Appearance.radius(30)
      bottomRightRadius: Appearance.radius(30)
      color: Appearance.colors.colLayer0
      opacity: root.revealProgress
      clip: true

      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
      }

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

        Search {
          id: searchBar
          width: parent.width - 8
          anchors.horizontalCenter: parent.horizontalCenter
          onSearchingTextChanged: root.refreshResults()
          onAccepted: root.launch(resultsView.currentIndex)
          onEscapePressed: root.close()
          onNavigateRight: resultsView.currentIndex = Math.min(resultsView.count - 1, resultsView.currentIndex + 1)
          onNavigateLeft: resultsView.currentIndex = Math.max(0, resultsView.currentIndex - 1)
          onNavigateDown: resultsView.currentIndex = Math.min(resultsView.count - 1, resultsView.currentIndex + resultsView.columns)
          onNavigateUp: resultsView.currentIndex = Math.max(0, resultsView.currentIndex - resultsView.columns)
        }

        GridView {
          id: resultsView
          width: parent.width
          height: parent.height - 60
          clip: true
          readonly property int columns: Math.max(1, Math.floor(width / 108))
          cellWidth: width / columns
          cellHeight: 92
          model: root.results

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: resultsView.cellWidth - 8
            height: resultsView.cellHeight - 8
            radius: Appearance.radius(18)
            color: resultsView.currentIndex === index || resultHover.hovered
              ? Appearance.m3colors.m3secondaryContainer : "transparent"

            Image {
              anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 }
              width: 42
              height: 42
              source: Quickshell.iconPath(modelData.icon, true)
              sourceSize.width: 42
              sourceSize.height: 42
            }

            MaterialSymbol {
              anchors { top: parent.top; right: parent.right; margins: 7 }
              visible: TaskbarApps.isPinned(modelData.id)
              text: "keep"
              iconSize: 15
              color: Appearance.m3colors.m3primary
            }

            Text {
              anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 9 }
              horizontalAlignment: Text.AlignHCenter
              text: modelData.name
              color: Appearance.m3colors.m3onSurface
              font.family: Appearance.font.family.main
              font.pixelSize: 12
              font.weight: Font.Medium
              elide: Text.ElideRight
            }

            HoverHandler { id: resultHover; onHoveredChanged: if (hovered) resultsView.currentIndex = index }
            TapHandler { onTapped: root.launch(index) }
            TapHandler {
              acceptedButtons: Qt.RightButton
              onTapped: TaskbarApps.togglePin(modelData.id)
            }
          }
        }
      }
    }

    RoundCorner {
      z: 2
      anchors { top: card.top; right: card.left; rightMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: card.color
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      z: 2
      anchors { top: card.top; left: card.right; leftMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: card.color
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopLeft
    }
  }
}
