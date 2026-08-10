import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.modules.common

Rectangle {
  id: root

  FontLoader {
    id: materialIcons
    source: "file:///usr/share/fonts/ttf-material-symbols-variable/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
  }

  property bool wifiEnabled: false
  property bool wifiConnected: false
  property bool ethernetConnected: false
  property int wifiStrength: 0
  property bool bluetoothEnabled: false
  property bool vertical: false

  function networkIcon() {
    if (ethernetConnected)
      return "lan";
    if (!wifiEnabled)
      return "wifi_off";
    if (!wifiConnected || wifiStrength <= 0)
      return "signal_wifi_0_bar";
    if (wifiStrength < 30)
      return "network_wifi_1_bar";
    if (wifiStrength < 55)
      return "network_wifi_2_bar";
    if (wifiStrength < 80)
      return "network_wifi_3_bar";
    return "wifi";
  }

  width: trayContent.implicitWidth + 10
  height: trayContent.implicitHeight + (vertical ? 8 : 4)
  radius: Appearance.radius(height / 2)
  color: Appearance.m3colors.m3surfaceContainerHigh

  TapHandler {
    onTapped: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
  }

  function refresh() {
    if (!networkStatus.running)
      networkStatus.running = true;
    if (!bluetoothStatus.running)
      bluetoothStatus.running = true;
  }

  Grid {
    id: trayContent
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    columnSpacing: 5
    rowSpacing: 4

    Text {
      text: root.networkIcon()
      color: root.ethernetConnected || root.wifiConnected
        ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
      font.family: materialIcons.name
      font.pixelSize: 13

    }

    Text {
      text: root.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
      color: root.bluetoothEnabled ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
      font.family: materialIcons.name
      font.pixelSize: 13

    }
  }

  Process {
    id: networkStatus
    command: ["sh", "-c", "printf '%s\\n' \"$(nmcli radio wifi 2>/dev/null)\" \"$(nmcli -t -f TYPE connection show --active 2>/dev/null | grep -Eq '^(802-3-ethernet|ethernet)$' && echo yes || echo no)\" \"$(nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | awk -F: '$1 == \"*\" { print $2; exit }')\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        root.wifiEnabled = lines[0] === "enabled";
        root.ethernetConnected = lines.length > 1 && lines[1] === "yes";
        root.wifiStrength = lines.length > 2 ? Number(lines[2]) || 0 : 0;
        root.wifiConnected = root.wifiStrength > 0;
      }
    }
  }

  Process {
    id: bluetoothStatus
    command: ["bluetoothctl", "show"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.bluetoothEnabled = text.includes("Powered: yes") }
  }

  Process {
    id: wifiToggle
    onExited: root.refresh()
  }

  Process {
    id: bluetoothToggle
    onExited: root.refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
