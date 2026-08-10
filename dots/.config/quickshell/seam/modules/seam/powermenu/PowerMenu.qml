import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.seam.frame

Scope {
    id: root

    property string pendingAction: ""
    property string pendingLabel: ""
    property real revealProgress: GlobalStates.sessionOpen ? 1 : 0

    Behavior on revealProgress {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    function close() {
        pendingAction = ""
        pendingLabel = ""
        GlobalStates.sessionOpen = false
    }

    function requestAction(action, label) {
        pendingAction = action
        pendingLabel = label
    }

    function confirmAction() {
        const action = pendingAction
        close()
        if (action === "lock") Session.lock()
        else if (action === "logout") Session.logout()
        else if (action === "suspend") Session.suspend()
        else if (action === "reboot") Session.reboot()
        else if (action === "poweroff") Session.poweroff()
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
        function open(): void { GlobalStates.sessionOpen = true }
        function close(): void { root.close() }
    }

    PanelWindow {
        id: window
        visible: GlobalStates.sessionOpen || root.revealProgress > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true }
        implicitHeight: screen?.height ?? 1080
        WlrLayershell.namespace: "seam:powermenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { item: GlobalStates.sessionOpen ? backdrop : null }

        MouseArea {
            id: backdrop
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: FrameConfig.thickness
            }
            readonly property real targetWidth: Math.min(620, window.width - 40)
            width: 120 + (targetWidth - 120) * root.revealProgress
            height: 36 + (250 - 36) * root.revealProgress
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Appearance.radius(32)
            bottomRightRadius: Appearance.radius(32)
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            opacity: root.revealProgress
            clip: true

            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Keys.onEscapePressed: root.close()

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

            Column {
                anchors { fill: parent; margins: 22 }
                spacing: 20
                opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Session"
                    color: Appearance.colors.colOnLayer0
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Repeater {
                        model: [
                            { "action": "lock", "label": "Lock", "icon": "lock" },
                            { "action": "logout", "label": "Log out", "icon": "logout" },
                            { "action": "suspend", "label": "Suspend", "icon": "bedtime" },
                            { "action": "reboot", "label": "Restart", "icon": "restart_alt" },
                            { "action": "poweroff", "label": "Shut down", "icon": "power_settings_new" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 96
                            height: 126
                            radius: Appearance.radius(26)
                            color: actionHover.hovered
                                ? (modelData.action === "poweroff" ? Appearance.m3colors.m3errorContainer : Appearance.colors.colLayer2Hover)
                                : Appearance.colors.colLayer1
                            scale: actionTap.pressed ? 0.94 : actionHover.hovered ? 1.04 : 1

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                MaterialSymbol {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    iconSize: 34
                                    color: modelData.action === "poweroff" && actionHover.hovered
                                        ? Appearance.m3colors.m3onErrorContainer : Appearance.colors.colOnLayer1
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: Appearance.colors.colOnLayer1
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                            }

                            HoverHandler { id: actionHover }
                            TapHandler {
                                id: actionTap
                                onTapped: root.requestAction(modelData.action, modelData.label)
                            }
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

        Rectangle {
            id: confirmation
            anchors.centerIn: parent
            width: Math.min(380, parent.width - 40)
            height: 190
            radius: Appearance.radius(30)
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            visible: root.pendingAction.length > 0
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.9

            Column {
                anchors { fill: parent; margins: 22 }
                spacing: 18

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pendingLabel + "?"
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Are you sure you want to continue?"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Rectangle {
                        width: 130; height: 46; radius: 23
                        color: cancelHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Appearance.colors.colOnLayer1; font.family: Appearance.font.family.main }
                        HoverHandler { id: cancelHover }
                        TapHandler { onTapped: { root.pendingAction = ""; root.pendingLabel = "" } }
                    }
                    Rectangle {
                        width: 130; height: 46; radius: 23
                        color: Appearance.m3colors.m3errorContainer
                        Text { anchors.centerIn: parent; text: "Confirm"; color: Appearance.m3colors.m3onErrorContainer; font.family: Appearance.font.family.main; font.weight: Font.DemiBold }
                        TapHandler { onTapped: root.confirmAction() }
                    }
                }
            }
        }
    }
}
