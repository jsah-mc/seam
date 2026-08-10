pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

BasePill {
  id: root
  rightTopCorner: false
  rightBottomCorner: true
  horizontalPadding: 10
  contentSpacing: 6

  Repeater {
    model: DockPins.widgetsFor("right")
    delegate: Loader {
      required property var modelData
      visible: Config.options.bar.widgets[modelData.id]
      anchors.verticalCenter: parent.verticalCenter
      source: Qt.resolvedUrl(`widgets/${root.widgetFile(modelData.id)}`)
    }
  }

  function widgetFile(id) {
    const files = { launcher: "LauncherButton.qml", workspaces: "WorkspacesWidget.qml", currentWindow: "CurrentWindowWidget.qml", visualizer: "MusicVisualizer.qml", clock: "ClockWidget.qml", battery: "BatteryWidget.qml", connectivity: "ConnectivityTray.qml", wallpaper: "WallpaperButton.qml", settings: "SettingsButton.qml", lock: "LockButton.qml", power: "PowerButton.qml" }
    return files[id] ?? ""
  }
}
