import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.seam.frame

Scope {
    id: root

    component PinnedAppButton: Rectangle {
        id: appButton
        required property var appData
        required property var dockHost
        readonly property string appId: appData.appId
        readonly property bool pinned: appData.pinned
        readonly property var toplevels: appData.toplevels
        readonly property var desktopEntry: DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId)
        property int lastFocused: -1
        property bool previewOpen: false
        onPreviewOpenChanged: {
            if (previewOpen) {
                dockHost.previewHoldCount++
                dockHost.holdOpen()
            } else {
                dockHost.previewHoldCount = Math.max(0, dockHost.previewHoldCount - 1)
                dockHost.releaseLater()
            }
        }

        width: 46
        height: 46
        radius: Appearance.radius(16)
        color: appHover.hovered ? Appearance.colors.colLayer2Hover : "transparent"
        scale: reorderDrag.active ? 1.12 : appTap.pressed ? 0.92 : appHover.hovered ? 1.06 : 1
        z: reorderDrag.active ? 10 : 0

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Drag.active: reorderDrag.active
        Drag.source: appButton
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Image {
            anchors.centerIn: parent
            width: 34
            height: 34
            source: Quickshell.iconPath(appButton.desktopEntry?.icon ?? AppSearch.guessIcon(appButton.appId), true)
            sourceSize.width: 34
            sourceSize.height: 34
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
            visible: appButton.toplevels.length > 0
            spacing: 2

            Repeater {
                model: Math.min(3, appButton.toplevels.length)
                delegate: Rectangle {
                    required property int index
                    width: appButton.toplevels.length > 3 ? 4 : 8
                    height: 4
                    radius: 2
                    color: appButton.toplevels[index]?.activated
                        ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                    opacity: appButton.toplevels[index]?.activated ? 1 : 0.55
                }
            }
        }

        HoverHandler {
            id: appHover
            onHoveredChanged: {
                if (hovered) {
                    appButton.dockHost.holdOpen()
                    previewCloseTimer.stop()
                    if (appButton.toplevels.length > 0)
                        previewOpenTimer.restart()
                } else {
                    appButton.dockHost.releaseLater()
                    previewOpenTimer.stop()
                    previewCloseTimer.restart()
                }
            }
        }
        Timer { id: previewOpenTimer; interval: 220; onTriggered: appButton.previewOpen = true }
        Timer {
            id: previewCloseTimer
            interval: 320
            onTriggered: {
                appButton.previewOpen = false
                appButton.dockHost.releaseLater()
            }
        }
        TapHandler {
            id: appTap
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (appButton.toplevels.length > 0)
                {
                    appButton.lastFocused = (appButton.lastFocused + 1) % appButton.toplevels.length
                    appButton.toplevels[appButton.lastFocused].activate()
                }
                else
                    appButton.desktopEntry?.execute()
            }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: DockPins.togglePin(appButton.appId)
        }
        DragHandler {
            id: reorderDrag
            target: null
            enabled: appButton.pinned
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.CanTakeOverFromItems
        }
        DropArea {
            anchors.fill: parent
            onEntered: drag => {
                const sourceId = drag.source?.appId
                if (sourceId) DockPins.movePin(sourceId, appButton.appId)
            }
        }

        Loader {
            active: appButton.previewOpen && appButton.toplevels.length > 0
            sourceComponent: PopupWindow {
                id: previewPopup
                visible: true
                color: "transparent"
                implicitWidth: Math.min(680, previewRow.implicitWidth + 20)
                implicitHeight: 190

                anchor {
                    window: appButton.QsWindow.window
                    item: appButton
                    edges: appButton.dockHost.effectiveSide === "bottom" ? Edges.Top
                        : appButton.dockHost.effectiveSide === "top" ? Edges.Bottom
                        : appButton.dockHost.effectiveSide === "left" ? Edges.Right : Edges.Left
                    gravity: appButton.dockHost.effectiveSide === "bottom" ? Edges.Top
                        : appButton.dockHost.effectiveSide === "top" ? Edges.Bottom
                        : appButton.dockHost.effectiveSide === "left" ? Edges.Right : Edges.Left
                }

                Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        previewCloseTimer.stop()
                        appButton.dockHost.holdOpen()
                    }
                    onExited: {
                        previewCloseTimer.restart()
                        appButton.dockHost.releaseLater()
                    }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: previewRow.implicitWidth
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: previewRow
                        spacing: 6

                        Repeater {
                            model: appButton.toplevels
                            delegate: Rectangle {
                                id: previewCard
                                required property var modelData
                                width: 210
                                height: 166
                                radius: Appearance.rounding.small
                                color: previewHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1
                                clip: true

                                Behavior on color { ColorAnimation { duration: 140 } }

                                Text {
                                    anchors { left: parent.left; right: closePreview.left; top: parent.top; margins: 8 }
                                    text: previewCard.modelData?.title ?? appButton.desktopEntry?.name ?? appButton.appId
                                    color: Appearance.colors.colOnLayer1
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    id: closePreview
                                    anchors { top: parent.top; right: parent.right; margins: 7 }
                                    text: "close"
                                    iconSize: 17
                                    color: Appearance.colors.colOnLayer1
                                    TapHandler { onTapped: previewCard.modelData?.close() }
                                }

                                ScreencopyView {
                                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 6; topMargin: 34 }
                                    captureSource: previewCard.modelData
                                    live: previewPopup.visible
                                    paintCursor: true
                                }

                                HoverHandler {
                                    id: previewHover
                                    onHoveredChanged: {
                                        if (hovered) {
                                            previewCloseTimer.stop()
                                            appButton.dockHost.holdOpen()
                                        } else {
                                            previewCloseTimer.restart()
                                            appButton.dockHost.releaseLater()
                                        }
                                    }
                                }
                                TapHandler { onTapped: { previewCard.modelData?.activate(); appButton.previewOpen = false } }
                            }
                        }
                    }
                }
                }
            }
        }
    }

    component AppsButton: Rectangle {
        width: 46
        height: 46
        radius: Appearance.radius(16)
        color: appsHover.hovered ? Appearance.m3colors.m3primaryContainer : Appearance.colors.colLayer1
        scale: appsTap.pressed ? 0.92 : appsHover.hovered ? 1.06 : 1

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "apps"
            iconSize: 25
            color: Appearance.colors.colOnLayer1
        }
        HoverHandler { id: appsHover }
        TapHandler {
            id: appsTap
            onTapped: GlobalStates.searchOpen = !GlobalStates.searchOpen
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow
            required property var modelData
            readonly property string effectiveSide: DockPins.side === "bottom" && Config.options.bar.bottom ? "top" : DockPins.side
            readonly property bool vertical: effectiveSide === "left" || effectiveSide === "right"
            property bool hoverHeld: false
            property int previewHoldCount: 0
            readonly property bool previewHeld: previewHoldCount > 0
            readonly property bool reveal: !DockPins.autoHide || hoverHeld || previewHeld || GlobalStates.searchOpen
            function holdOpen() {
                hideDelay.stop()
                hoverHeld = true
            }
            function releaseLater() {
                hideDelay.restart()
            }
            screen: modelData
            visible: DockPins.enabled && !GlobalStates.screenLocked
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:dock"

            anchors {
                top: dockWindow.vertical || dockWindow.effectiveSide === "top"
                bottom: dockWindow.vertical || dockWindow.effectiveSide === "bottom"
                left: dockWindow.effectiveSide === "left" || !dockWindow.vertical
                right: dockWindow.effectiveSide === "right" || !dockWindow.vertical
            }
            implicitWidth: dockWindow.vertical ? 72 : 0
            implicitHeight: dockWindow.vertical ? 0 : 72
            // While hidden, only the thin strip sitting directly on Seam's
            // frame accepts pointer input. Expand the input region only after
            // the dock has been revealed so its apps and previews stay usable.
            mask: Region { item: dockWindow.reveal ? edgeSensor : revealSensor }

            HoverHandler {
                id: dockHover
                onHoveredChanged: {
                    if (hovered) {
                        dockWindow.holdOpen()
                    } else {
                        dockWindow.releaseLater()
                    }
                }
            }

            Timer {
                id: hideDelay
                interval: 280
                onTriggered: {
                    // Moving from the edge sensor onto the animated card emits an
                    // edge exit after the app has already requested a hold. Only
                    // hide once every surface is genuinely clear of the pointer.
                    if (dockWindow.previewHeld || dockHover.hovered || cardHover.hovered
                            || edgeSensor.containsMouse || revealSensor.containsMouse) {
                        dockWindow.hoverHeld = true
                        return
                    }
                    dockWindow.hoverHeld = false
                }
            }

            MouseArea {
                id: edgeSensor
                z: -1
                hoverEnabled: true
                width: dockWindow.vertical ? parent.width : Math.max(180, dockCard.width)
                height: dockWindow.vertical ? Math.max(180, dockCard.height) : parent.height
                anchors {
                    horizontalCenter: !dockWindow.vertical ? parent.horizontalCenter : undefined
                    verticalCenter: dockWindow.vertical ? parent.verticalCenter : undefined
                    top: dockWindow.effectiveSide === "top" ? parent.top : undefined
                    bottom: dockWindow.effectiveSide === "bottom" ? parent.bottom : undefined
                    left: dockWindow.effectiveSide === "left" ? parent.left : undefined
                    right: dockWindow.effectiveSide === "right" ? parent.right : undefined
                }
            }

            MouseArea {
                id: revealSensor
                z: 100
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                width: dockWindow.vertical ? 4 : Math.max(180, dockCard.width)
                height: dockWindow.vertical ? Math.max(180, dockCard.height) : 4
                anchors {
                    horizontalCenter: !dockWindow.vertical ? parent.horizontalCenter : undefined
                    verticalCenter: dockWindow.vertical ? parent.verticalCenter : undefined
                    top: dockWindow.effectiveSide === "top" ? parent.top : undefined
                    bottom: dockWindow.effectiveSide === "bottom" ? parent.bottom : undefined
                    left: dockWindow.effectiveSide === "left" ? parent.left : undefined
                    right: dockWindow.effectiveSide === "right" ? parent.right : undefined
                }
                onEntered: {
                    dockWindow.holdOpen()
                }
                onExited: dockWindow.releaseLater()
            }

            StyledRectangularShadow {
                target: dockCard
                opacity: dockWindow.reveal ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                id: dockCard
                anchors {
                    horizontalCenter: !dockWindow.vertical ? parent.horizontalCenter : undefined
                    verticalCenter: dockWindow.vertical ? parent.verticalCenter : undefined
                    top: dockWindow.effectiveSide === "top" ? parent.top : undefined
                    bottom: dockWindow.effectiveSide === "bottom" ? parent.bottom : undefined
                    left: dockWindow.effectiveSide === "left" ? parent.left : undefined
                    right: dockWindow.effectiveSide === "right" ? parent.right : undefined
                    topMargin: dockWindow.effectiveSide === "top" ? FrameConfig.thickness : 0
                    bottomMargin: dockWindow.effectiveSide === "bottom" ? FrameConfig.thickness : 0
                    leftMargin: dockWindow.effectiveSide === "left" ? FrameConfig.thickness : 0
                    rightMargin: dockWindow.effectiveSide === "right" ? FrameConfig.thickness : 0
                }
                width: dockWindow.vertical ? 58 : horizontalContent.implicitWidth + 12
                height: dockWindow.vertical ? verticalContent.implicitHeight + 12 : 58
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                opacity: dockWindow.reveal ? 1 : 0
                topLeftRadius: dockWindow.effectiveSide === "left" || dockWindow.effectiveSide === "top" ? 0 : Appearance.rounding.large
                bottomLeftRadius: dockWindow.effectiveSide === "left" || dockWindow.effectiveSide === "bottom" ? 0 : Appearance.rounding.large
                topRightRadius: dockWindow.effectiveSide === "right" || dockWindow.effectiveSide === "top" ? 0 : Appearance.rounding.large
                bottomRightRadius: dockWindow.effectiveSide === "right" || dockWindow.effectiveSide === "bottom" ? 0 : Appearance.rounding.large
                transform: Translate {
                    x: !dockWindow.reveal && dockWindow.effectiveSide === "left" ? -dockCard.width
                        : !dockWindow.reveal && dockWindow.effectiveSide === "right" ? dockCard.width : 0
                    y: !dockWindow.reveal && dockWindow.effectiveSide === "bottom" ? dockCard.height + FrameConfig.thickness
                        : !dockWindow.reveal && dockWindow.effectiveSide === "top" ? -dockCard.height - FrameConfig.thickness : 0

                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                HoverHandler {
                    id: cardHover
                    onHoveredChanged: {
                        if (hovered) {
                            dockWindow.holdOpen()
                        } else {
                            dockWindow.releaseLater()
                        }
                    }
                }

                RoundCorner {
                    visible: dockWindow.effectiveSide === "bottom"
                    anchors { bottom: parent.bottom; right: parent.left; rightMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.BottomRight
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "bottom"
                    anchors { bottom: parent.bottom; left: parent.right; leftMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.BottomLeft
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "top"
                    anchors { top: parent.top; right: parent.left; rightMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.TopRight
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "top"
                    anchors { top: parent.top; left: parent.right; leftMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.TopLeft
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "left"
                    anchors { bottom: parent.top; left: parent.left; bottomMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.BottomLeft
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "left"
                    anchors { top: parent.bottom; left: parent.left; topMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.TopLeft
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "right"
                    anchors { bottom: parent.top; right: parent.right; bottomMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.BottomRight
                }
                RoundCorner {
                    visible: dockWindow.effectiveSide === "right"
                    anchors { top: parent.bottom; right: parent.right; topMargin: -1 }
                    implicitSize: Appearance.radius(16)
                    color: dockCard.color
                    corner: RoundCorner.CornerEnum.TopRight
                }

                Row {
                    id: horizontalContent
                    visible: !dockWindow.vertical
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: TaskbarApps.apps.filter(app => app.appId !== "SEPARATOR")
                        delegate: PinnedAppButton { required property var modelData; appData: modelData; dockHost: dockWindow }
                    }
                    Rectangle { width: 1; height: 32; anchors.verticalCenter: parent.verticalCenter; color: Appearance.colors.colOutlineVariant }
                    AppsButton {}
                }

                Column {
                    id: verticalContent
                    visible: dockWindow.vertical
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: TaskbarApps.apps.filter(app => app.appId !== "SEPARATOR")
                        delegate: PinnedAppButton { required property var modelData; appData: modelData; dockHost: dockWindow }
                    }
                    Rectangle { width: 32; height: 1; anchors.horizontalCenter: parent.horizontalCenter; color: Appearance.colors.colOutlineVariant }
                    AppsButton {}
                }
            }
        }
    }
}
