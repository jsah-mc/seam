import Quickshell.Io
import QtQuick
import qs.modules.common

Item {
  id: root

  property bool available: false
  property bool charging: false
  property int percentage: 0

  function batteryIcon() {
    if (charging)
      return "battery_charging_full";
    if (percentage <= 10)
      return "battery_0_bar";
    if (percentage <= 20)
      return "battery_1_bar";
    if (percentage <= 30)
      return "battery_2_bar";
    if (percentage <= 40)
      return "battery_3_bar";
    if (percentage <= 50)
      return "battery_3_bar";
    if (percentage <= 60)
      return "battery_4_bar";
    if (percentage <= 70)
      return "battery_5_bar";
    if (percentage <= 80)
      return "battery_6_bar";
    if (percentage <= 90)
      return "battery_6_bar";
    return "battery_full";
  }

  visible: available
  implicitWidth: available ? batteryContent.implicitWidth : 0
  implicitHeight: 20

  Row {
    id: batteryContent
    anchors.centerIn: parent
    spacing: 3

    Text {
      text: root.batteryIcon()
      color: root.percentage <= 15 ? Appearance.m3colors.m3error : Appearance.m3colors.m3onSurface
      font.family: Appearance.font.family.iconMaterial
      font.pixelSize: 13
      font.hintingPreference: Font.PreferNoHinting
    }

    Text {
      text: root.percentage + "%"
      color: Appearance.m3colors.m3onSurface
      font.pixelSize: 10
      font.weight: Font.Medium
    }
  }

  Process {
    id: batteryStatus
    command: ["sh", "-c", "for device in $(upower -e | grep battery); do info=$(upower -i \"$device\"); echo \"$info\" | grep -q 'power supply: *yes' && { echo \"$info\"; exit 0; }; done; exit 1"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const percentageMatch = text.match(/percentage:\s*([0-9]+)%/);
        const stateMatch = text.match(/state:\s*([^\n]+)/);
        root.available = percentageMatch !== null;

        if (percentageMatch)
          root.percentage = Number(percentageMatch[1]);
        if (stateMatch)
          root.charging = stateMatch[1].trim() === "charging";
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: batteryStatus.running = true
  }
}
