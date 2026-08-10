import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.common

Row {
  id: root

  readonly property real contentWidth: childrenRect.width
  property int iconRevision: 0
  spacing: 4

  Timer {
    property int refreshCount: 0
    interval: 400
    running: refreshCount < 10
    repeat: true
    onTriggered: {
      root.iconRevision++;
      refreshCount++;
    }
  }

  function workspaceFor(workspaceId) {
    return Hyprland.workspaces.values.find(workspace => workspace.id === workspaceId) || null;
  }

  function appClassFor(toplevel) {
    if (!toplevel)
      return "";
    const ipc = toplevel.lastIpcObject || {};
    return ipc["class"] || ipc.initialClass || toplevel.wayland?.appId || "";
  }

  function normalized(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "");
  }

  function iconFor(toplevel) {
    const appClass = appClassFor(toplevel);
    const target = normalized(appClass);
    if (!target.length)
      return "application-x-executable";

    const aliases = {
      "codeoss": "code",
      "visualstudiocode": "code",
      "googlechrome": "google-chrome",
      "chromiumbrowser": "chromium",
      "orgtelegramdesktop": "telegram",
      "comdiscordappdiscord": "discord"
    };
    const alias = aliases[target] || target;

    function matches(candidateValue) {
      const value = normalized(candidateValue);
      if (!value.length)
        return false;
      if (value === target || value === alias)
        return true;
      if (target.length >= 4 && (value.endsWith(target) || target.endsWith(value)))
        return true;
      return alias.length >= 4 && (value.endsWith(alias) || alias.endsWith(value));
    }

    const entry = DesktopEntries.applications.values.find(candidate => {
      const command = candidate.command || [];
      return matches(candidate.id)
        || matches(candidate.startupClass)
        || matches(candidate.name)
        || command.some(part => matches(String(part).split("/").pop()));
    });

    if (entry?.icon)
      return entry.icon;
    if (Quickshell.hasThemeIcon(appClass))
      return appClass;
    if (Quickshell.hasThemeIcon(String(appClass).toLowerCase()))
      return String(appClass).toLowerCase();
    return "application-x-executable";
  }

  function switchWorkspace(direction) {
    const currentId = Math.max(1, Math.min(10, Hyprland.focusedWorkspace?.id || 1));
    const nextId = ((currentId - 1 + direction + 10) % 10) + 1;
    Hyprland.dispatch("workspace " + nextId);
  }

  WheelHandler {
    onWheel: event => {
      if (event.angleDelta.y === 0)
        return;
      root.switchWorkspace(event.angleDelta.y > 0 ? -1 : 1);
      event.accepted = true;
    }
  }

  Repeater {
    model: 10

    Rectangle {
      required property int index
      readonly property int workspaceId: index + 1
      readonly property var workspace: root.workspaceFor(workspaceId)
      readonly property var toplevel: workspace && workspace.toplevels.values.length > 0
        ? workspace.toplevels.values[0] : null
      readonly property bool occupied: toplevel !== null
      readonly property bool isFocused: workspaceId === Hyprland.focusedWorkspace?.id

      width: 22
      height: 22
      radius: Appearance.radius(height / 2)
      scale: isFocused ? 1.1 : workspaceHover.hovered ? 1.05 : 1
      color: isFocused ? Appearance.m3colors.m3primaryContainer
        : workspaceHover.hovered ? Appearance.m3colors.m3surfaceContainerHighest
        : Appearance.m3colors.m3surfaceContainerHigh

      Behavior on width { NumberAnimation { duration: 140 } }
      Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
      Behavior on color { ColorAnimation { duration: 220 } }

      Item {
        anchors.centerIn: parent
        visible: parent.occupied
        width: 14
        height: 14

        Image {
          id: appIcon
          anchors.fill: parent
          width: 14
          height: 14
          source: root.iconRevision >= 0 && parent.parent.occupied
            ? Quickshell.iconPath(root.iconFor(parent.parent.toplevel), "application-x-executable") : ""
          sourceSize: Qt.size(14, 14)
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: appIcon.status === Image.Error || appIcon.source.toString().length === 0
          text: "◆"
          color: Appearance.m3colors.m3onSurface
          font.pixelSize: 10
        }
      }

      Rectangle {
        anchors.centerIn: parent
        visible: !parent.occupied
        width: parent.isFocused ? 7 : 5
        height: width
        radius: width / 2
        color: parent.isFocused ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
      }

      HoverHandler { id: workspaceHover }
      TapHandler {
        onTapped: Hyprland.dispatch("hl.dsp.focus({ workspace = '" + parent.workspaceId + "' })")
      }
    }
  }
}
