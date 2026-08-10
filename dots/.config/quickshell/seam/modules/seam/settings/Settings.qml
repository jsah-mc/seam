import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.wifiNetworks
import qs.modules.ii.sidebarRight.bluetoothDevices

Scope {
    id: root
    property int currentTab: 0

    function applyScheme(scheme) {
        DockPins.setThemeScheme(scheme)
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", DockPins.themeMode, "--type", scheme, "--noswitch"])
    }

    function applyThemeMode(mode) {
        DockPins.setThemeMode(mode)
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", mode, "--type", DockPins.themeScheme, "--noswitch"])
    }

    function placeBarWidget(widgetId, area, beforeId) {
        Config.options.bar.widgets[widgetId] = true
        DockPins.placeWidget(widgetId, area, beforeId ?? "")
    }

    function removeBarWidget(widgetId) {
        Config.options.bar.widgets[widgetId] = false
    }

    component M3Button: Rectangle {
        id: button
        property string text: ""
        property string icon: ""
        property bool selected: false
        signal clicked()
        implicitWidth: labelRow.implicitWidth + 28
        implicitHeight: 42
        radius: Appearance.radius(21)
        color: selected ? Appearance.m3colors.m3secondaryContainer
            : hover.hovered ? Appearance.m3colors.m3surfaceContainerHighest
            : Appearance.m3colors.m3surfaceContainerHigh
        Behavior on color { ColorAnimation { duration: 160 } }
        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 9
            MaterialSymbol { visible: button.icon.length > 0; text: button.icon; iconSize: 19; color: Appearance.m3colors.m3onSurface }
            Text { text: button.text; color: Appearance.m3colors.m3onSurface; font.family: Appearance.font.family.main; font.pixelSize: 14; font.weight: Font.Medium }
        }
        HoverHandler { id: hover }
        TapHandler { onTapped: button.clicked() }
    }

    component SettingToggle: Rectangle {
        id: toggle
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled(bool value)
        implicitHeight: subtitle.length > 0 ? 64 : 52
        radius: Appearance.radius(18)
        color: hover.hovered ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainer
        Behavior on color { ColorAnimation { duration: 150 } }
        Column {
            anchors { left: parent.left; right: switchTrack.left; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 10 }
            spacing: 2
            Text { width: parent.width; text: toggle.title; color: Appearance.m3colors.m3onSurface; elide: Text.ElideRight; font.family: Appearance.font.family.main; font.pixelSize: 14; font.weight: Font.Medium }
            Text { visible: toggle.subtitle.length > 0; width: parent.width; text: toggle.subtitle; color: Appearance.m3colors.m3onSurfaceVariant; elide: Text.ElideRight; font.family: Appearance.font.family.main; font.pixelSize: 11 }
        }
        Rectangle {
            id: switchTrack
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
            width: 44; height: 26; radius: 13
            color: toggle.checked ? Appearance.m3colors.m3primary : Appearance.m3colors.m3surfaceContainerHighest
            border.width: toggle.checked ? 0 : 1
            border.color: Appearance.m3colors.m3outline
            Rectangle {
                width: toggle.checked ? 20 : 16; height: width; radius: width / 2
                x: toggle.checked ? parent.width - width - 3 : 5
                anchors.verticalCenter: parent.verticalCenter
                color: toggle.checked ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3outline
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 180 } }
            }
        }
        HoverHandler { id: hover }
        TapHandler { onTapped: toggle.toggled(!toggle.checked) }
    }

    component SectionTitle: Text {
        font.family: Appearance.font.family.title
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Appearance.m3colors.m3onSurface
    }

    component WidgetDragChip: Rectangle {
        id: chip
        required property string widgetId
        required property string widgetName
        property var editor: null
        property bool activeWidget: Config.options.bar.widgets[widgetId]
        property string targetArea: ""
        property real dragOriginX: 0
        property real dragOriginY: 0

        implicitWidth: chipRow.implicitWidth + 24
        implicitHeight: 38
        radius: Appearance.radius(19)
        color: dragHandler.active ? Appearance.m3colors.m3primaryContainer
            : activeWidget ? Appearance.m3colors.m3secondaryContainer
            : Appearance.m3colors.m3surfaceContainerHighest
        border.width: dragHandler.active ? 2 : 0
        border.color: Appearance.m3colors.m3primary
        opacity: activeWidget ? 1 : 0.68
        scale: dragHandler.active ? 1.08 : 1
        z: dragHandler.active ? 100 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7
            MaterialSymbol { text: "drag_indicator"; iconSize: 17; color: Appearance.m3colors.m3onSurfaceVariant }
            Text { text: chip.widgetName; color: Appearance.m3colors.m3onSurface; font.family: Appearance.font.family.main; font.pixelSize: 12; font.weight: Font.Medium }
        }

        Drag.active: dragHandler.active
        Drag.source: chip
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.supportedActions: Qt.MoveAction
        DragHandler {
            id: dragHandler
            target: chip
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: {
                if (active) {
                    chip.dragOriginX = chip.x
                    chip.dragOriginY = chip.y
                } else {
                    if (!chip.editor) return
                    const dropPoint = chip.mapToItem(chip.editor, chip.width / 2, chip.height / 2)
                    chip.x = chip.dragOriginX
                    chip.y = chip.dragOriginY
                    chip.editor.completeWidgetDrag(chip.widgetId, dropPoint.x, dropPoint.y)
                }
            }
        }

    }

    component WidgetZone: Rectangle {
        id: zone
        required property string area
        required property string title
        property var editor: null
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: Math.max(170, zoneFlow.implicitHeight + 57)
        radius: Appearance.radius(24)
        color: zoneDrop.containsDrag ? Appearance.m3colors.m3secondaryContainer : Appearance.m3colors.m3surfaceContainer
        border.width: zoneDrop.containsDrag ? 2 : 1
        border.color: zoneDrop.containsDrag ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outlineVariant
        Behavior on color { ColorAnimation { duration: 140 } }

        Column {
            z: 1
            anchors { fill: parent; margins: 12 }
            spacing: 10
            Row {
                spacing: 7
                MaterialSymbol { text: area === "left" ? "align_horizontal_left" : area === "center" ? "align_horizontal_center" : "align_horizontal_right"; iconSize: 19; color: Appearance.m3colors.m3primary }
                Text { text: zone.title; color: Appearance.m3colors.m3onSurface; font.family: Appearance.font.family.main; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            Flow {
                id: zoneFlow
                width: parent.width
                spacing: 7
                Repeater {
                    model: DockPins.widgetsFor(zone.area).filter(widget => Config.options.bar.widgets[widget.id])
                    delegate: WidgetDragChip {
                        required property var modelData
                        widgetId: modelData.id
                        widgetName: modelData.name
                        editor: zone.editor
                        targetArea: zone.area
                    }
                }
            }
        }

        DropArea {
            id: zoneDrop
            anchors.fill: parent
            z: 2
            onDropped: drag => {
                root.placeBarWidget(drag.source.widgetId, zone.area, "")
                drag.accept(Qt.MoveAction)
            }
        }
    }

    FloatingWindow {
        id: window
        visible: GlobalStates.settingsOpen
        color: "transparent"
        implicitWidth: 980
        implicitHeight: 680
        title: "Seam Settings"
        onVisibleChanged: {
            if (!visible)
                GlobalStates.settingsOpen = false
        }

        Rectangle {
                id: card
                anchors.fill: parent
                radius: Appearance.radius(32)
                color: Appearance.m3colors.m3surface
                border.width: 1
                border.color: Appearance.m3colors.m3outlineVariant
                clip: true
                scale: GlobalStates.settingsOpen ? 1 : 0.92
                opacity: GlobalStates.settingsOpen ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                FocusScope {
                    anchors.fill: parent
                    focus: GlobalStates.settingsOpen
                    Keys.onEscapePressed: GlobalStates.settingsOpen = false

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.preferredWidth: 210
                            Layout.fillHeight: true
                            color: Appearance.m3colors.m3surfaceContainerLow
                            ColumnLayout {
                                anchors { fill: parent; margins: 18 }
                                spacing: 10
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 16
                                    MaterialSymbol { text: "tune"; iconSize: 28; color: Appearance.m3colors.m3primary }
                                    Text { text: "Seam Settings"; color: Appearance.m3colors.m3onSurface; font.family: Appearance.font.family.title; font.pixelSize: 19; font.weight: Font.DemiBold }
                                }
                                M3Button { Layout.fillWidth: true; text: "Interface"; icon: "tune"; selected: root.currentTab === 0; onClicked: root.currentTab = 0 }
                                M3Button { Layout.fillWidth: true; text: "Theme"; icon: "palette"; selected: root.currentTab === 1; onClicked: root.currentTab = 1 }
                                M3Button { Layout.fillWidth: true; text: "Network"; icon: Network.materialSymbol; selected: root.currentTab === 2; onClicked: { root.currentTab = 2; Network.rescanWifi() } }
                                M3Button { Layout.fillWidth: true; text: "Bluetooth"; icon: "bluetooth"; selected: root.currentTab === 3; onClicked: root.currentTab = 3 }
                                Item { Layout.fillHeight: true }
                                M3Button { Layout.fillWidth: true; text: "Close"; icon: "close"; onClicked: GlobalStates.settingsOpen = false }
                            }
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: root.currentTab === 0 ? interfacePage
                                : root.currentTab === 1 ? themePage
                                : root.currentTab === 2 ? networkPage : bluetoothPage
                        }
                    }
                }
        }
    }

    Component {
        id: interfacePage
        Flickable {
            id: interfaceRoot
            function containsPoint(item, x, y) {
                const local = item.mapFromItem(interfaceRoot, x, y)
                return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height
            }
            function completeWidgetDrag(widgetId, x, y) {
                if (containsPoint(widgetTray, x, y)) {
                    root.removeBarWidget(widgetId)
                } else if (containsPoint(leftWidgetZone, x, y)) {
                    root.placeBarWidget(widgetId, "left", "")
                } else if (containsPoint(centerWidgetZone, x, y)) {
                    root.placeBarWidget(widgetId, "center", "")
                } else if (containsPoint(rightWidgetZone, x, y)) {
                    root.placeBarWidget(widgetId, "right", "")
                }
            }
            contentWidth: width
            contentHeight: interfaceColumn.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: interfaceColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 14
                SectionTitle { text: "Interface" }
                Text { text: "Bar position"; color: Appearance.m3colors.m3onSurfaceVariant; font.family: Appearance.font.family.main; font.pixelSize: 13; font.weight: Font.Medium }
                RowLayout {
                    M3Button { Layout.fillWidth: true; text: "Top"; icon: "vertical_align_top"; selected: !Config.options.bar.bottom; onClicked: Config.options.bar.bottom = false }
                    M3Button { Layout.fillWidth: true; text: "Bottom"; icon: "vertical_align_bottom"; selected: Config.options.bar.bottom; onClicked: Config.options.bar.bottom = true }
                }

                Text { text: "Bar widgets"; color: Appearance.m3colors.m3onSurfaceVariant; font.family: Appearance.font.family.main; font.pixelSize: 13; font.weight: Font.Medium }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10; rowSpacing: 10
                    SettingToggle { Layout.fillWidth: true; title: "App / AI"; checked: Config.options.bar.widgets.launcher; onToggled: value => Config.options.bar.widgets.launcher = value }
                    SettingToggle { Layout.fillWidth: true; title: "Workspaces"; checked: Config.options.bar.widgets.workspaces; onToggled: value => Config.options.bar.widgets.workspaces = value }
                    SettingToggle { Layout.fillWidth: true; title: "Current window"; checked: Config.options.bar.widgets.currentWindow; onToggled: value => Config.options.bar.widgets.currentWindow = value }
                    SettingToggle { Layout.fillWidth: true; title: "Music visualizer"; checked: Config.options.bar.widgets.visualizer; onToggled: value => Config.options.bar.widgets.visualizer = value }
                    SettingToggle { Layout.fillWidth: true; title: "Clock"; checked: Config.options.bar.widgets.clock; onToggled: value => Config.options.bar.widgets.clock = value }
                    SettingToggle { Layout.fillWidth: true; title: "Battery"; checked: Config.options.bar.widgets.battery; onToggled: value => Config.options.bar.widgets.battery = value }
                    SettingToggle { Layout.fillWidth: true; title: "Connectivity"; checked: Config.options.bar.widgets.connectivity; onToggled: value => Config.options.bar.widgets.connectivity = value }
                    SettingToggle { Layout.fillWidth: true; title: "Wallpaper"; checked: Config.options.bar.widgets.wallpaper; onToggled: value => Config.options.bar.widgets.wallpaper = value }
                    SettingToggle { Layout.fillWidth: true; title: "Settings"; checked: Config.options.bar.widgets.settings; onToggled: value => Config.options.bar.widgets.settings = value }
                    SettingToggle { Layout.fillWidth: true; title: "Lock"; checked: Config.options.bar.widgets.lock; onToggled: value => Config.options.bar.widgets.lock = value }
                    SettingToggle { Layout.fillWidth: true; title: "Power"; checked: Config.options.bar.widgets.power; onToggled: value => Config.options.bar.widgets.power = value }
                }

                Text { text: "Widget positions"; color: Appearance.m3colors.m3onSurfaceVariant; font.family: Appearance.font.family.main; font.pixelSize: 13; font.weight: Font.Medium }
                Text {
                    Layout.fillWidth: true
                    text: "Drag widgets into a pill below. Drag them back into this tray to remove them from the bar."
                    wrapMode: Text.WordWrap
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.family: Appearance.font.family.main
                    font.pixelSize: 12
                }
                Rectangle {
                    id: widgetTray
                    Layout.fillWidth: true
                    implicitHeight: trayFlow.implicitHeight + 24
                    radius: Appearance.radius(24)
                    color: trayDrop.containsDrag ? Appearance.m3colors.m3errorContainer : Appearance.m3colors.m3surfaceContainerLow
                    border.width: trayDrop.containsDrag ? 2 : 1
                    border.color: trayDrop.containsDrag ? Appearance.m3colors.m3error : Appearance.m3colors.m3outlineVariant
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Flow {
                        id: trayFlow
                        z: 1
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 7
                        Repeater {
                            model: DockPins.allBarWidgets
                            delegate: WidgetDragChip {
                                required property var modelData
                                widgetId: modelData.id
                                widgetName: modelData.name
                                editor: interfaceRoot
                                activeWidget: Config.options.bar.widgets[modelData.id]
                            }
                        }
                    }
                    DropArea {
                        id: trayDrop
                        anchors.fill: parent
                        z: 2
                        onDropped: drag => {
                            root.removeBarWidget(drag.source.widgetId)
                            drag.accept(Qt.MoveAction)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    WidgetZone { id: leftWidgetZone; area: "left"; title: "Left pill"; editor: interfaceRoot }
                    WidgetZone { id: centerWidgetZone; area: "center"; title: "Center pill"; editor: interfaceRoot }
                    WidgetZone { id: rightWidgetZone; area: "right"; title: "Right pill"; editor: interfaceRoot }
                }

                Text { text: "Dock"; color: Appearance.m3colors.m3onSurfaceVariant; font.family: Appearance.font.family.main; font.pixelSize: 13; font.weight: Font.Medium }
                SettingToggle { Layout.fillWidth: true; title: "Enable dock"; checked: DockPins.enabled; onToggled: value => DockPins.setEnabled(value) }
                SettingToggle { Layout.fillWidth: true; title: "Auto-hide"; checked: DockPins.autoHide; onToggled: value => DockPins.setAutoHide(value) }
                RowLayout {
                    M3Button { Layout.fillWidth: true; text: "Left"; selected: DockPins.side === "left"; onClicked: DockPins.setSide("left") }
                    M3Button { Layout.fillWidth: true; text: "Bottom"; selected: DockPins.side === "bottom"; onClicked: DockPins.setSide("bottom") }
                    M3Button { Layout.fillWidth: true; text: "Right"; selected: DockPins.side === "right"; onClicked: DockPins.setSide("right") }
                }
                Text { text: "Pinned apps"; color: Appearance.m3colors.m3onSurfaceVariant; font.family: Appearance.font.family.main; font.pixelSize: 13; font.weight: Font.Medium }
                Repeater {
                    model: DockPins.pins
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property var entry: DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)
                        Layout.fillWidth: true; implicitHeight: 52; radius: Appearance.radius(17); color: Appearance.m3colors.m3surfaceContainer
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            Image { Layout.preferredWidth: 28; Layout.preferredHeight: 28; source: Quickshell.iconPath(parent.parent.entry?.icon ?? "application-x-executable", true) }
                            Text { Layout.fillWidth: true; text: parent.parent.entry?.name ?? parent.parent.modelData; elide: Text.ElideRight; color: Appearance.m3colors.m3onSurface; font.family: Appearance.font.family.main; font.pixelSize: 13 }
                            M3Button { text: "↑"; enabled: parent.parent.index > 0; opacity: enabled ? 1 : .4; onClicked: DockPins.movePin(parent.parent.modelData, DockPins.pins[parent.parent.index - 1]) }
                            M3Button { text: "↓"; enabled: parent.parent.index < DockPins.pins.length - 1; opacity: enabled ? 1 : .4; onClicked: DockPins.movePin(parent.parent.modelData, DockPins.pins[parent.parent.index + 1]) }
                            M3Button { icon: "remove"; onClicked: DockPins.togglePin(parent.parent.modelData) }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: pinField
                        Layout.fillWidth: true
                        placeholderText: "Desktop entry ID (for example: kitty)"
                        color: Appearance.m3colors.m3onSurface
                        onAccepted: if (text.trim().length > 0) { DockPins.togglePin(text.trim()); text = "" }
                    }
                    M3Button { text: "Add pin"; icon: "add"; onClicked: if (pinField.text.trim().length > 0) { DockPins.togglePin(pinField.text.trim()); pinField.text = "" } }
                }
            }
        }
    }

    Component {
        id: themePage
        Flickable {
            contentWidth: width
            contentHeight: themeColumn.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: themeColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 14

                SectionTitle { text: "Theme" }
                Text {
                    text: "Color mode"
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.family: Appearance.font.family.main
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                RowLayout {
                    Layout.fillWidth: true
                    M3Button {
                        Layout.fillWidth: true
                        text: "Light"
                        icon: "light_mode"
                        selected: DockPins.themeMode === "light"
                        onClicked: root.applyThemeMode("light")
                    }
                    M3Button {
                        Layout.fillWidth: true
                        text: "Dark"
                        icon: "dark_mode"
                        selected: DockPins.themeMode === "dark"
                        onClicked: root.applyThemeMode("dark")
                    }
                }

                Text {
                    text: "Material color scheme"
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.family: Appearance.font.family.main
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    text: "Schemes are generated from your current wallpaper by set_wall."
                    wrapMode: Text.WordWrap
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.family: Appearance.font.family.main
                    font.pixelSize: 12
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10
                    M3Button { Layout.fillWidth: true; text: "Auto"; icon: "auto_awesome"; selected: DockPins.themeScheme === "auto"; onClicked: root.applyScheme("auto") }
                    M3Button { Layout.fillWidth: true; text: "Content"; icon: "image"; selected: DockPins.themeScheme === "scheme-content"; onClicked: root.applyScheme("scheme-content") }
                    M3Button { Layout.fillWidth: true; text: "Expressive"; icon: "celebration"; selected: DockPins.themeScheme === "scheme-expressive"; onClicked: root.applyScheme("scheme-expressive") }
                    M3Button { Layout.fillWidth: true; text: "Fidelity"; icon: "colorize"; selected: DockPins.themeScheme === "scheme-fidelity"; onClicked: root.applyScheme("scheme-fidelity") }
                    M3Button { Layout.fillWidth: true; text: "Fruit Salad"; icon: "nutrition"; selected: DockPins.themeScheme === "scheme-fruit-salad"; onClicked: root.applyScheme("scheme-fruit-salad") }
                    M3Button { Layout.fillWidth: true; text: "Monochrome"; icon: "monochrome_photos"; selected: DockPins.themeScheme === "scheme-monochrome"; onClicked: root.applyScheme("scheme-monochrome") }
                    M3Button { Layout.fillWidth: true; text: "Neutral"; icon: "contrast"; selected: DockPins.themeScheme === "scheme-neutral"; onClicked: root.applyScheme("scheme-neutral") }
                    M3Button { Layout.fillWidth: true; text: "Rainbow"; icon: "looks"; selected: DockPins.themeScheme === "scheme-rainbow"; onClicked: root.applyScheme("scheme-rainbow") }
                    M3Button { Layout.fillWidth: true; text: "Tonal Spot"; icon: "palette"; selected: DockPins.themeScheme === "scheme-tonal-spot"; onClicked: root.applyScheme("scheme-tonal-spot") }
                }
            }
        }
    }

    Component {
        id: networkPage
        ColumnLayout {
            spacing: 12
            anchors { fill: parent; margins: 24 }
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "Network"; Layout.fillWidth: true }
                M3Button { text: Network.wifiScanning ? "Scanning…" : "Scan"; icon: "refresh"; onClicked: Network.rescanWifi() }
            }
            SettingToggle { Layout.fillWidth: true; title: "Wi-Fi"; subtitle: Network.networkName || Network.wifiStatus; checked: Network.wifiEnabled; onToggled: value => Network.enableWifi(value) }
            Rectangle {
                visible: Network.ethernet
                Layout.fillWidth: true; implicitHeight: 58; radius: Appearance.radius(18); color: Appearance.m3colors.m3primaryContainer
                RowLayout {
                    anchors { fill: parent; margins: 14 }
                    MaterialSymbol { text: "lan"; iconSize: 24; color: Appearance.m3colors.m3onPrimaryContainer }
                    Text { text: "Ethernet connected"; color: Appearance.m3colors.m3onPrimaryContainer; font.family: Appearance.font.family.main; font.pixelSize: 14; font.weight: Font.Medium }
                }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 2
                model: ScriptModel { values: Network.friendlyWifiNetworks }
                delegate: WifiNetworkItem { required property var modelData; wifiNetwork: modelData; width: ListView.view.width }
            }
        }
    }

    Component {
        id: bluetoothPage
        ColumnLayout {
            spacing: 12
            anchors { fill: parent; margins: 24 }
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "Bluetooth"; Layout.fillWidth: true }
                M3Button {
                    text: (Bluetooth.defaultAdapter?.discovering ?? false) ? "Stop scan" : "Scan"
                    icon: "bluetooth_searching"
                    enabled: Bluetooth.defaultAdapter !== null
                    onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                }
            }
            SettingToggle {
                Layout.fillWidth: true
                title: "Bluetooth"
                subtitle: BluetoothStatus.available ? `${BluetoothStatus.activeDeviceCount} connected` : "No adapter found"
                checked: BluetoothStatus.enabled
                onToggled: value => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = value }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 2
                model: ScriptModel { values: BluetoothStatus.friendlyDeviceList }
                delegate: BluetoothDeviceItem { required property var modelData; device: modelData; width: ListView.view.width }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { GlobalStates.settingsOpen = !GlobalStates.settingsOpen }
        function open(): void { GlobalStates.settingsOpen = true }
        function close(): void { GlobalStates.settingsOpen = false }
    }
}
