import qs
import qs.services
import qs.modules.common
import qs.modules.seam.frame
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property real revealProgress: GlobalStates.sidebarRightOpen ? 1 : 0

    Behavior on revealProgress {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.sidebarRightOpen || root.revealProgress > 0.001

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: sidebarWidth
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        mask: Region { item: GlobalStates.sidebarRightOpen ? sidebarContentLoader : null }

        anchors {
            top: true
            right: true
            bottom: true
        }

        Component.onCompleted: {
            if (GlobalStates.sidebarRightOpen)
                GlobalFocusGrab.addDismissable(panelWindow)
        }

        Connections {
            target: GlobalStates
            function onSidebarRightOpenChanged() {
                if (GlobalStates.sidebarRightOpen)
                    GlobalFocusGrab.addDismissable(panelWindow)
                else
                    GlobalFocusGrab.removeDismissable(panelWindow)
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (GlobalStates.sidebarRightOpen)
                    panelWindow.hide()
            }
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            enabled: GlobalStates.sidebarRightOpen
            onActivated: panelWindow.hide()
        }

        Loader {
            id: sidebarContentLoader
            active: root.revealProgress > 0 || Config?.options.sidebar.keepRightSidebarLoaded
            opacity: root.revealProgress
            scale: 0.97 + root.revealProgress * 0.03
            transform: Translate {
                x: (1 - root.revealProgress) * (root.sidebarWidth * 0.35)
            }
            anchors {
                fill: parent
                leftMargin: FrameConfig.thickness
                rightMargin: FrameConfig.thickness
                bottomMargin: FrameConfig.thickness
                topMargin: FrameConfig.thickness
            }

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                }
            }

            sourceComponent: SidebarRightContent {}
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
