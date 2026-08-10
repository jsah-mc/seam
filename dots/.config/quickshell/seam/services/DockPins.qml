pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string filePath: Quickshell.env("HOME") + "/.config/seam/config.json"
    readonly property bool enabled: adapter.dock.enabled
    readonly property bool autoHide: adapter.dock.autoHide
    readonly property string side: ["left", "right", "bottom"].indexOf(adapter.dock.side) >= 0 ? adapter.dock.side : "bottom"
    readonly property var pins: Object.keys(adapter.dock.pins).sort((a, b) => adapter.dock.pins[a] - adapter.dock.pins[b])
    readonly property string themeMode: ["light", "dark"].indexOf(adapter.theme.mode) >= 0 ? adapter.theme.mode : "dark"
    readonly property string themeScheme: adapter.theme.scheme
    readonly property var allBarWidgets: [
        { id: "launcher", name: "App / AI" },
        { id: "workspaces", name: "Workspaces" },
        { id: "currentWindow", name: "Current window" },
        { id: "visualizer", name: "Music visualizer" },
        { id: "clock", name: "Clock" },
        { id: "battery", name: "Battery" },
        { id: "connectivity", name: "Connectivity" },
        { id: "wallpaper", name: "Wallpaper" },
        { id: "settings", name: "Settings" },
        { id: "lock", name: "Lock" },
        { id: "power", name: "Power" }
    ]

    function setPins(orderedPins) {
        const value = {};
        orderedPins.forEach((id, index) => value[id] = index);
        adapter.dock.pins = value;
    }

    function setEnabled(value) { adapter.dock.enabled = value }
    function setAutoHide(value) { adapter.dock.autoHide = value }
    function setSide(value) {
        if (["left", "right", "bottom"].indexOf(value) >= 0)
            adapter.dock.side = value
    }

    function setThemeMode(value) {
        if (["light", "dark"].indexOf(value) >= 0)
            adapter.theme.mode = value
    }

    function setThemeScheme(value) { adapter.theme.scheme = value }

    function widgetsFor(area) {
        const layout = adapter.bar.widgets
        return root.allBarWidgets
            .filter(widget => (layout[widget.id]?.area ?? "right") === area)
            .sort((a, b) => (layout[a.id]?.index ?? 999) - (layout[b.id]?.index ?? 999))
    }

    function widgetArea(widgetId) { return adapter.bar.widgets[widgetId]?.area ?? "right" }
    function widgetIndex(widgetId) { return root.widgetsFor(root.widgetArea(widgetId)).findIndex(widget => widget.id === widgetId) }

    function setWidgetArea(widgetId, area) {
        root.placeWidget(widgetId, area, "")
    }

    function placeWidget(widgetId, area, beforeId) {
        if (["left", "center", "right"].indexOf(area) < 0) return
        const groups = { left: [], center: [], right: [] }
        for (const candidateArea of ["left", "center", "right"])
            groups[candidateArea] = root.widgetsFor(candidateArea).map(widget => widget.id).filter(id => id !== widgetId)

        let insertIndex = beforeId ? groups[area].indexOf(beforeId) : -1
        if (insertIndex < 0) insertIndex = groups[area].length
        groups[area].splice(insertIndex, 0, widgetId)

        const value = {}
        for (const candidateArea of ["left", "center", "right"])
            groups[candidateArea].forEach((id, index) => value[id] = { area: candidateArea, index: index })
        adapter.bar.widgets = value
    }

    function moveWidget(widgetId, direction) {
        const layout = adapter.bar.widgets
        const area = layout[widgetId]?.area ?? "right"
        const ordered = root.widgetsFor(area).map(widget => widget.id)
        const index = ordered.indexOf(widgetId)
        const target = index + direction
        if (index < 0 || target < 0 || target >= ordered.length) return
        const swap = ordered[target]
        const value = Object.assign({}, layout)
        value[widgetId] = { area: area, index: target }
        value[swap] = { area: area, index: index }
        adapter.bar.widgets = value
    }

    function normalizeWidgetOrder() {
        const value = Object.assign({}, adapter.bar.widgets)
        for (const area of ["left", "center", "right"])
            root.widgetsFor(area).forEach((widget, index) => value[widget.id] = { area: area, index: index })
        adapter.bar.widgets = value
    }

    function togglePin(appId) {
        const orderedPins = Array.from(root.pins);
        const index = orderedPins.indexOf(appId);
        if (index >= 0) orderedPins.splice(index, 1);
        else orderedPins.push(appId);
        root.setPins(orderedPins);
    }

    function movePin(sourceId, targetId) {
        const orderedPins = Array.from(root.pins);
        const sourceIndex = orderedPins.indexOf(sourceId);
        const targetIndex = orderedPins.indexOf(targetId);
        if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex) return;
        orderedPins.splice(sourceIndex, 1);
        orderedPins.splice(targetIndex, 0, sourceId);
        root.setPins(orderedPins);
    }

    Timer {
        id: reloadTimer
        interval: 80
        onTriggered: pinsFile.reload()
    }

    Timer {
        id: writeTimer
        interval: 80
        onTriggered: pinsFile.writeAdapter()
    }

    FileView {
        id: pinsFile
        path: root.filePath
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeTimer.restart()
        }

        JsonAdapter {
            id: adapter
            property JsonObject theme: JsonObject {
                property string mode: "dark"
                property string scheme: "auto"
            }
            property JsonObject dock: JsonObject {
                property bool enabled: true
                property bool autoHide: true
                property string side: "bottom"
                property var pins: ({
                    "org.kde.dolphin": 0,
                    "kitty": 1
                })
            }
            property JsonObject bar: JsonObject {
                property var widgets: ({
                    "launcher": { "area": "left", "index": 0 },
                    "workspaces": { "area": "left", "index": 1 },
                    "currentWindow": { "area": "center", "index": 0 },
                    "visualizer": { "area": "center", "index": 1 },
                    "clock": { "area": "center", "index": 2 },
                    "battery": { "area": "right", "index": 0 },
                    "connectivity": { "area": "right", "index": 1 },
                    "wallpaper": { "area": "right", "index": 2 },
                    "settings": { "area": "right", "index": 3 },
                    "lock": { "area": "right", "index": 4 },
                    "power": { "area": "right", "index": 5 }
                })
            }
        }
    }
}
