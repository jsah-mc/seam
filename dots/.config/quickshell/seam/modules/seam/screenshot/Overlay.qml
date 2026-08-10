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
        onExited: notificationCommand.running = true
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

        const screenX = root.screen?.x ?? 0;
        const screenY = root.screen?.y ?? 0;
        const x = Math.ceil(screenX + root.left);
        const y = Math.ceil(screenY + root.top);
        const geometry = `${x},${y} ${width}x${height}`;
        captureCommand.command = ["sh", "-c",
            `mkdir -p "$HOME/Pictures/Screenshots"; screenshot_path="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; grim -g "${geometry}" "$screenshot_path" && wl-copy < "$screenshot_path"`];
        root.capturing = true;
        captureDelay.start();
    }

    contentItem {
        focus: true
        Keys.onEscapePressed: root.controller.isOpen = false
        Keys.onReturnPressed: root.captureSelection()
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
            context.fillStyle = "#99000000";
            context.fillRect(0, 0, root.width, root.height);
            if (!root.hasSelection)
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
        visible: !root.capturing
    }
    Rope {
        id: topRightRope
        anchors.fill: parent
        start: Qt.vector2d(root.width, 0)
        end: Qt.vector2d(root.right, root.top)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing
    }
    Rope {
        id: bottomRightRope
        anchors.fill: parent
        start: Qt.vector2d(root.width, root.height)
        end: Qt.vector2d(root.right, root.bottom)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing
    }
    Rope {
        id: bottomLeftRope
        anchors.fill: parent
        start: Qt.vector2d(0, root.height)
        end: Qt.vector2d(root.left, root.bottom)
        color: Appearance.m3colors.m3primary
        visible: !root.capturing
    }

    component SelectionHandle: Rectangle {
        width: 22
        height: 22
        radius: 11
        visible: root.hasSelection && !root.capturing
        color: Appearance.m3colors.m3primary
        border.width: 4
        border.color: Appearance.m3colors.m3onPrimary
    }

    SelectionHandle { x: root.left - width / 2; y: root.top - height / 2 }
    SelectionHandle { x: root.right - width / 2; y: root.top - height / 2 }
    SelectionHandle { x: root.right - width / 2; y: root.bottom - height / 2 }
    SelectionHandle { x: root.left - width / 2; y: root.bottom - height / 2 }

    Rectangle {
        visible: !root.capturing
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
        width: instructionRow.implicitWidth + 32
        height: 44
        radius: 22
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant

        Row {
            id: instructionRow
            anchors.centerIn: parent
            spacing: 9
            Text {
                text: "screenshot_region"
                color: Appearance.m3colors.m3primary
                font.family: Appearance.font.family.iconMaterial
                font.pixelSize: 20
            }
            Text {
                text: "Drag and release to save  •  Esc to cancel"
                color: Appearance.m3colors.m3onSurface
                font.family: Appearance.font.family.main
                font.pixelSize: 13
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.capturing
        onPressed: event => {
            root.dragOriginX = event.x;
            root.dragOriginY = event.y;
            root.left = root.dragOriginX;
            root.top = root.dragOriginY;
            root.right = root.dragOriginX;
            root.bottom = root.dragOriginY;
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            root.left = Math.min(root.dragOriginX, event.x);
            root.top = Math.min(root.dragOriginY, event.y);
            root.right = Math.max(root.dragOriginX, event.x);
            root.bottom = Math.max(root.dragOriginY, event.y);
        }
        onReleased: root.captureSelection()
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
    onWidthChanged: {
        left = width / 2;
        right = width / 2;
    }
    onHeightChanged: {
        top = height / 2;
        bottom = height / 2;
    }
}
