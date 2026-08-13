pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common

PanelWindow {
    id: root
    required property var controller

    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "seam:screenshot"

    // The surface must be visible before ScreencopyView can receive a frame on
    // current Quickshell; gating the window on hasContent deadlocks capture.
    visible: true
    ScreencopyView {
        id: screencopy
        captureSource: root.screen
        anchors.fill: parent
        paintCursor: false
    }

    Process {
        id: captureCommand
        running: false
        onExited: exitCode => {
            notificationCommand.command = exitCode === 0
                ? ["notify-send", "Screenshot saved", "Saved to ~/Pictures/Screenshots and copied to the clipboard"]
                : ["notify-send", "Screenshot failed", "The selected area could not be captured"];
            notificationCommand.running = true;
        }
    }
    Timer {
        id: captureDelay
        interval: 50
        repeat: false
        onTriggered: captureCommand.running = true
    }
    Process {
        id: notificationCommand
        command: ["notify-send", "Screenshot saved", "Saved to ~/Pictures/Screenshots and copied to the clipboard"]
        running: false
        onExited: root.controller.isOpen = false
    }

    function captureSelection() {
        const width = Math.floor(root.right - root.left);
        const height = Math.floor(root.bottom - root.top);
        if (width <= 4 || height <= 4 || captureCommand.running)
            return;

        root.captureGeometry(root.left, root.top, width, height);
    }

    function captureGeometry(localX, localY, width, height) {
        if (width <= 0 || height <= 0 || captureCommand.running || root.capturing)
            return;
        const screenX = root.screen?.x ?? 0;
        const screenY = root.screen?.y ?? 0;
        const x = Math.ceil(screenX + localX);
        const y = Math.ceil(screenY + localY);
        const geometry = `${x},${y} ${Math.floor(width)}x${Math.floor(height)}`;
        captureCommand.command = ["bash", "-c",
            'mkdir -p -- "$HOME/Pictures/Screenshots"; screenshot_path="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; grim -g "$1" "$screenshot_path" && wl-copy < "$screenshot_path"',
            "seam-screenshot", geometry];
        root.capturing = true;
        captureDelay.start();
    }

    function captureFullscreen() {
        root.captureGeometry(0, 0, root.width, root.height);
    }

    function captureWindowAt(localX, localY) {
        if (captureCommand.running || root.capturing)
            return;
        const x = Math.floor((root.screen?.x ?? 0) + localX);
        const y = Math.floor((root.screen?.y ?? 0) + localY);
        captureCommand.command = ["bash", "-c", String.raw`
            set -euo pipefail
            geometry="$(hyprctl clients -j | jq -r --argjson x "$1" --argjson y "$2" '
                [.[] | select(.mapped != false)
                  | select(.at[0] <= $x and .at[1] <= $y)
                  | select((.at[0] + .size[0]) > $x and (.at[1] + .size[1]) > $y)]
                | sort_by(if .floating then 1 else 0 end)
                | last
                | if . == null then empty else "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" end
            ')"
            test -n "$geometry"
            mkdir -p -- "$HOME/Pictures/Screenshots"
            screenshot_path="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
            grim -g "$geometry" "$screenshot_path"
            wl-copy < "$screenshot_path"
        `, "seam-window-screenshot", `${x}`, `${y}`];
        root.capturing = true;
        captureDelay.start();
    }

    contentItem {
        focus: true
        Keys.onEscapePressed: root.controller.isOpen = false
        Keys.onReturnPressed: {
            if (root.controller.mode === "region") root.captureSelection();
            else if (root.controller.mode === "fullscreen") root.captureFullscreen();
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_R) root.controller.mode = "region";
            else if (event.key === Qt.Key_W) root.controller.mode = "window";
            else if (event.key === Qt.Key_F) root.controller.mode = "fullscreen";
            else return;
            event.accepted = true;
        }
    }

    property real left: 0
    property real top: 0
    property real right: 0
    property real bottom: 0
    property real dragOriginX: 0
    property real dragOriginY: 0
    property bool capturing: false
    readonly property real selectionRadius: Appearance.radius(24)
    readonly property bool hasSelection: right - left > 4 && bottom - top > 4

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: !root.capturing
        function roundedPath(context, x, y, width, height, radius) {
            const r = Math.min(radius, width / 2, height / 2);
            context.beginPath();
            context.moveTo(x + r, y);
            context.lineTo(x + width - r, y);
            context.quadraticCurveTo(x + width, y, x + width, y + r);
            context.lineTo(x + width, y + height - r);
            context.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
            context.lineTo(x + r, y + height);
            context.quadraticCurveTo(x, y + height, x, y + height - r);
            context.lineTo(x, y + r);
            context.quadraticCurveTo(x, y, x + r, y);
            context.closePath();
        }

        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.fillStyle = root.controller.mode === "region" ? "#99000000" : "#44000000";
            context.fillRect(0, 0, root.width, root.height);
            if (root.controller.mode !== "region" || !root.hasSelection)
                return;

            const selectionWidth = root.right - root.left;
            const selectionHeight = root.bottom - root.top;
            roundedPath(context, root.left, root.top, selectionWidth, selectionHeight, root.selectionRadius);
            context.globalCompositeOperation = "destination-out";
            context.fillStyle = "#ffffffff";
            context.fill();

            context.globalCompositeOperation = "source-over";
            roundedPath(context, root.left, root.top, selectionWidth, selectionHeight, root.selectionRadius);
            context.strokeStyle = Appearance.m3colors.m3primary.toString();
            context.lineWidth = 4;
            context.stroke();
        }
    }

    Rope {
        id: topLeftRope
        anchors.fill: parent
        start: Qt.vector2d(0, 0)
        end: Qt.vector2d(root.left, root.top)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing && root.controller.mode === "region"
    }
    Rope {
        id: topRightRope
        anchors.fill: parent
        start: Qt.vector2d(root.width, 0)
        end: Qt.vector2d(root.right, root.top)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing && root.controller.mode === "region"
    }
    Rope {
        id: bottomRightRope
        anchors.fill: parent
        start: Qt.vector2d(root.width, root.height)
        end: Qt.vector2d(root.right, root.bottom)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing && root.controller.mode === "region"
    }
    Rope {
        id: bottomLeftRope
        anchors.fill: parent
        start: Qt.vector2d(0, root.height)
        end: Qt.vector2d(root.left, root.bottom)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing && root.controller.mode === "region"
    }

    component SelectionHandle: Rectangle {
        width: 22
        height: 22
        radius: 11
        visible: root.controller.mode === "region" && root.hasSelection && !root.capturing
        color: Appearance.m3colors.m3primary
        border.width: 4
        border.color: Appearance.m3colors.m3onPrimary
    }

    SelectionHandle { x: root.left - width / 2; y: root.top - height / 2 }
    SelectionHandle { x: root.right - width / 2; y: root.top - height / 2 }
    SelectionHandle { x: root.right - width / 2; y: root.bottom - height / 2 }
    SelectionHandle { x: root.left - width / 2; y: root.bottom - height / 2 }

    Rectangle {
        id: modePill
        z: 20
        visible: !root.capturing
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
        width: modeRow.implicitWidth + 16
        height: 52
        radius: Appearance.radius(26)
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant

        Row {
            id: modeRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: [
                    { mode: "region", icon: "screenshot_region", label: "Region" },
                    { mode: "window", icon: "select_window", label: "Window" },
                    { mode: "fullscreen", icon: "screenshot_monitor", label: "Full screen" }
                ]

                delegate: Rectangle {
                    id: modeButton
                    required property var modelData
                    readonly property bool selected: root.controller.mode === modelData.mode
                    width: buttonContent.implicitWidth + 20
                    height: 38
                    radius: Appearance.radius(19)
                    color: selected ? Appearance.m3colors.m3primaryContainer
                        : modeHover.hovered ? Appearance.m3colors.m3surfaceContainerHighest : "transparent"

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: buttonContent
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            text: modeButton.modelData.icon
                            color: modeButton.selected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurfaceVariant
                            font.family: Appearance.font.family.iconMaterial
                            font.pixelSize: 18
                        }
                        Text {
                            text: modeButton.modelData.label
                            color: modeButton.selected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                            font.family: Appearance.font.family.main
                            font.pixelSize: 13
                        }
                    }
                    HoverHandler { id: modeHover }
                    TapHandler {
                        onTapped: {
                            root.controller.mode = modeButton.modelData.mode;
                            if (modeButton.modelData.mode === "fullscreen")
                                Qt.callLater(() => root.captureFullscreen());
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        z: 19
        visible: !root.capturing
        anchors { horizontalCenter: parent.horizontalCenter; bottom: modePill.top; bottomMargin: 10 }
        width: instructionText.implicitWidth + 24
        height: 32
        radius: Appearance.radius(16)
        color: Appearance.m3colors.m3surfaceContainer
        Text {
            id: instructionText
            anchors.centerIn: parent
            text: root.controller.mode === "region" ? "Drag and release to capture  •  R"
                : root.controller.mode === "window" ? "Click a window to capture  •  W"
                : "Capturing this screen  •  F"
            color: Appearance.m3colors.m3onSurfaceVariant
            font.family: Appearance.font.family.main
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.capturing
        onPressed: event => {
            if (root.controller.mode === "window")
                return;
            if (root.controller.mode !== "region")
                return;
            root.dragOriginX = event.x;
            root.dragOriginY = event.y;
            root.left = root.dragOriginX;
            root.top = root.dragOriginY;
            root.right = root.dragOriginX;
            root.bottom = root.dragOriginY;
        }
        onPositionChanged: event => {
            if (!pressed || root.controller.mode !== "region")
                return;
            root.left = Math.min(root.dragOriginX, event.x);
            root.top = Math.min(root.dragOriginY, event.y);
            root.right = Math.max(root.dragOriginX, event.x);
            root.bottom = Math.max(root.dragOriginY, event.y);
        }
        onReleased: event => {
            if (root.controller.mode === "region")
                root.captureSelection();
            else if (root.controller.mode === "window")
                root.captureWindowAt(event.x, event.y);
        }
    }

    onLeftChanged: {
        canvas.requestPaint();
    }
    onTopChanged: {
        canvas.requestPaint();
    }
    onRightChanged: {
        canvas.requestPaint();
    }
    onBottomChanged: {
        canvas.requestPaint();
    }
    Connections {
        target: root.controller
        function onModeChanged() { canvas.requestPaint(); }
    }
    onWidthChanged: {
        left = width / 2;
        right = width / 2;
    }
    onHeightChanged: {
        top = height / 2;
        bottom = height / 2;
    }
}
