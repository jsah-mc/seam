import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
  id: root

  property bool opened: false
  property real revealProgress: 0
  readonly property var flow: PolkitService.flow

  function openDialog() {
    opened = true;
    revealProgress = 1;
    Qt.callLater(() => passwordField.forceActiveFocus());
  }

  function closeDialog() {
    opened = false;
    revealProgress = 0;
    passwordField.clear();
  }

  function submit() {
    if (!flow || !flow.isResponseRequired || passwordField.text.length === 0)
      return;
    PolkitService.submit(passwordField.text);
    passwordField.clear();
  }

  Connections {
    target: PolkitService
    function onActiveChanged() {
      if (PolkitService.active) root.openDialog()
      else root.closeDialog()
    }
    function onFlowChanged() {
      if (PolkitService.active && PolkitService.flow) root.openDialog()
    }
  }

  Component.onCompleted: {
    if (PolkitService.active) root.openDialog()
  }

  Connections {
    target: root.flow
    enabled: root.flow !== null
    ignoreUnknownSignals: true

    function onIsCompletedChanged() {
      if (root.flow?.isCompleted)
        root.closeDialog();
    }

    function onIsCancelledChanged() {
      if (root.flow?.isCancelled)
        root.closeDialog();
    }

    function onIsResponseRequiredChanged() {
      if (root.flow?.isResponseRequired)
        Qt.callLater(() => passwordField.forceActiveFocus());
    }
  }

  Behavior on revealProgress {
    NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
  }

  PanelWindow {
    visible: root.opened || root.revealProgress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "seam-polkit-agent"

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    mask: Region { item: authPanel }

    Shortcut {
      sequence: "Escape"
      enabled: root.opened
      onActivated: {
        if (root.flow)
          PolkitService.cancel();
        root.closeDialog();
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Appearance.m3colors.m3scrim
      opacity: 0.16 * root.revealProgress
    }

    Rectangle {
      id: authPanel
      anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: 10
      }

      width: 120 + 400 * root.revealProgress
      height: 36 + 224 * root.revealProgress
      opacity: root.revealProgress
      radius: Appearance.radius(18 + 6 * root.revealProgress)
      topLeftRadius: 0
      topRightRadius: 0
      color: Appearance.colors.colLayer0
      clip: true

      Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

        Row {
          width: parent.width
          spacing: 12

          Rectangle {
            width: 42
            height: 42
            radius: Appearance.radius(21)
            color: Appearance.colors.colLayer1

            MaterialSymbol {
              anchors.centerIn: parent
              text: "admin_panel_settings"
              color: Appearance.colors.colOnPrimaryContainer
              iconSize: 22
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 94
            spacing: 2

            Text {
              width: parent.width
              text: "Authentication required"
              color: Appearance.colors.colOnSurface
              font.family: Appearance.font.family.title
              font.pixelSize: 18
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: PolkitService.cleanMessage || "An application is requesting administrator privileges"
              color: Appearance.colors.colOnSurfaceVariant
              font.family: Appearance.font.family.main
              font.pixelSize: 11
              maximumLineCount: 2
              wrapMode: Text.Wrap
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: cancelHover.hovered ? Appearance.colors.colErrorContainer : Appearance.colors.colSurfaceContainerHigh
            MaterialSymbol { anchors.centerIn: parent; text: "close"; color: cancelHover.hovered ? Appearance.m3colors.m3onErrorContainer : Appearance.colors.colOnSurface; iconSize: 20 }
            HoverHandler { id: cancelHover }
            TapHandler {
              onTapped: {
                if (root.flow)
                  PolkitService.cancel();
                root.closeDialog();
              }
            }
          }
        }

        TextField {
          id: passwordField
          width: parent.width
          height: 46
          enabled: root.flow?.isResponseRequired ?? false
          placeholderText: PolkitService.cleanPrompt
          echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
          color: Appearance.colors.colOnSurface
          placeholderTextColor: Appearance.colors.colOnSurfaceVariant
          selectionColor: Appearance.m3colors.m3primary
          selectedTextColor: Appearance.m3colors.m3onPrimary
          font.family: Appearance.font.family.main
          leftPadding: 18
          rightPadding: 18
          Keys.onReturnPressed: root.submit()
          Keys.onEnterPressed: root.submit()
          background: Rectangle {
            radius: Appearance.radius(23)
            color: Appearance.m3colors.m3surfaceContainerHigh
          }
        }

        Text {
          width: parent.width
          height: 18
          text: root.flow?.supplementaryMessage || ""
          color: root.flow?.supplementaryIsError ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
          font.family: Appearance.font.family.main
          font.pixelSize: 11
          elide: Text.ElideRight
        }

        Row {
          anchors.right: parent.right
          spacing: 8

          Rectangle {
            width: 92
            height: 38
            radius: Appearance.radius(19)
            color: cancelButtonHover.hovered ? Appearance.m3colors.m3surfaceContainerHighest : Appearance.colors.colSurfaceContainerHigh
            Text { anchors.centerIn: parent; text: "Cancel"; color: Appearance.colors.colOnSurface; font.family: Appearance.font.family.main; font.pixelSize: 12; font.bold: true }
            HoverHandler { id: cancelButtonHover }
            TapHandler {
              onTapped: {
                if (root.flow)
                  PolkitService.cancel();
                root.closeDialog();
              }
            }
          }

          Rectangle {
            width: 108
            height: 38
            radius: Appearance.radius(19)
            color: passwordField.text.length ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest
            Text {
              anchors.centerIn: parent
              text: "Authenticate"
              color: passwordField.text.length ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
              font.family: Appearance.font.family.main
              font.pixelSize: 12
              font.bold: true
            }
            TapHandler { enabled: passwordField.text.length > 0; onTapped: root.submit() }
          }
        }
      }

    }

    RoundCorner {
      anchors { top: authPanel.top; right: authPanel.left; rightMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.colors.colLayer0
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      anchors { top: authPanel.top; left: authPanel.right; leftMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Appearance.colors.colLayer0
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopLeft
    }
  }
}
