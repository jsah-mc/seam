pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string filePath: Quickshell.env("HOME") + "/.config/seam/config.toml"
    readonly property string legacyFilePath: Quickshell.env("HOME") + "/.config/seam/config.json"
    property var data: defaultData()
    property bool loading: true

    readonly property bool enabled: data.dock.enabled
    readonly property bool autoHide: data.dock.autoHide
    readonly property string side: ["left", "right", "bottom"].includes(data.dock.side) ? data.dock.side : "bottom"
    readonly property var pins: Object.keys(data.dock.pins).sort((a, b) => data.dock.pins[a] - data.dock.pins[b])
    readonly property string themeMode: ["light", "dark"].includes(data.theme.mode) ? data.theme.mode : "dark"
    readonly property string themeScheme: data.theme.scheme
    readonly property string aiProvider: ["openai", "gemini", "groq", "openrouter", "chatgpt"].includes(data.ai.provider) ? data.ai.provider : "chatgpt"
    readonly property string aiModel: ["fast", "balanced", "smart", "coding"].includes(data.ai.model) ? data.ai.model : "balanced"
    readonly property var allBarWidgets: [
        { id: "launcher", name: "App / AI" },
        { id: "workspaces", name: "Workspaces" },
        { id: "currentWindow", name: "Current window" },
        { id: "visualizer", name: "Music visualizer" },
        { id: "clock", name: "Clock" },
        { id: "battery", name: "Battery" },
        { id: "connectivity", name: "Connectivity" },
        { id: "systemTray", name: "System tray" },
        { id: "wallpaper", name: "Wallpaper" },
        { id: "settings", name: "Settings" },
        { id: "lock", name: "Lock" },
        { id: "power", name: "Power" }
    ]

    function defaultData() {
        return {
            theme: { mode: "dark", scheme: "auto" },
            ai: { provider: "chatgpt", model: "balanced" },
            dock: {
                enabled: true,
                autoHide: true,
                side: "bottom",
                pins: { "org.kde.dolphin": 0, "kitty": 1 }
            },
            bar: {
                widgets: {
                    launcher: { area: "left", index: 0 },
                    workspaces: { area: "left", index: 1 },
                    currentWindow: { area: "center", index: 0 },
                    visualizer: { area: "center", index: 1 },
                    clock: { area: "center", index: 2 },
                    battery: { area: "right", index: 0 },
                    connectivity: { area: "right", index: 1 },
                    systemTray: { area: "right", index: 2 },
                    wallpaper: { area: "right", index: 3 },
                    settings: { area: "right", index: 4 },
                    lock: { area: "right", index: 5 },
                    power: { area: "right", index: 6 }
                }
            }
        }
    }

    function normalized(value) {
        const defaults = defaultData()
        const theme = value?.theme ?? {}
        const ai = value?.ai ?? {}
        const dock = value?.dock ?? {}
        const bar = value?.bar ?? {}
        return {
            theme: {
                mode: ["light", "dark"].includes(theme.mode) ? theme.mode : defaults.theme.mode,
                scheme: typeof theme.scheme === "string" ? theme.scheme : defaults.theme.scheme
            },
            ai: {
                provider: ["openai", "gemini", "groq", "openrouter", "chatgpt"].includes(ai.provider) ? ai.provider : defaults.ai.provider,
                model: ["fast", "balanced", "smart", "coding"].includes(ai.model) ? ai.model : defaults.ai.model
            },
            dock: {
                enabled: typeof dock.enabled === "boolean" ? dock.enabled : defaults.dock.enabled,
                autoHide: typeof dock.autoHide === "boolean" ? dock.autoHide : defaults.dock.autoHide,
                side: ["left", "right", "bottom"].includes(dock.side) ? dock.side : defaults.dock.side,
                pins: dock.pins && typeof dock.pins === "object" ? dock.pins : defaults.dock.pins
            },
            bar: {
                widgets: bar.widgets && typeof bar.widgets === "object" ? bar.widgets : defaults.bar.widgets
            }
        }
    }

    function update(mutator) {
        const value = normalized(data)
        mutator(value)
        data = value
        if (!loading)
            writeTimer.restart()
    }

    function tomlString(value) {
        return JSON.stringify(String(value))
    }

    function serializeToml(value) {
        const config = normalized(value)
        const lines = [
            "# Seam configuration",
            "# This file is watched and updated live.",
            "",
            "[theme]",
            "mode = " + tomlString(config.theme.mode),
            "scheme = " + tomlString(config.theme.scheme),
            "",
            "[ai]",
            "provider = " + tomlString(config.ai.provider),
            "model = " + tomlString(config.ai.model),
            "",
            "[dock]",
            "enabled = " + config.dock.enabled,
            "autoHide = " + config.dock.autoHide,
            "side = " + tomlString(config.dock.side),
            "",
            "[dock.pins]"
        ]

        Object.keys(config.dock.pins)
            .sort((a, b) => config.dock.pins[a] - config.dock.pins[b])
            .forEach(id => lines.push(tomlString(id) + " = " + Number(config.dock.pins[id])))

        Object.keys(config.bar.widgets).forEach(id => {
            const widget = config.bar.widgets[id]
            lines.push("", "[bar.widgets." + tomlString(id) + "]")
            lines.push("area = " + tomlString(widget.area ?? "right"))
            lines.push("index = " + Number(widget.index ?? 999))
        })

        return lines.join("\n") + "\n"
    }

    function setPins(orderedPins) {
        update(value => {
            const pins = {}
            orderedPins.forEach((id, index) => pins[id] = index)
            value.dock.pins = pins
        })
    }

    function setEnabled(value) { update(config => config.dock.enabled = value) }
    function setAutoHide(value) { update(config => config.dock.autoHide = value) }
    function setSide(value) {
        if (["left", "right", "bottom"].includes(value))
            update(config => config.dock.side = value)
    }
    function setThemeMode(value) {
        if (["light", "dark"].includes(value))
            update(config => config.theme.mode = value)
    }
    function setThemeScheme(value) { update(config => config.theme.scheme = value) }
    function setAiProvider(value) {
        if (["openai", "gemini", "groq", "openrouter", "chatgpt"].includes(value))
            update(config => config.ai.provider = value)
    }
    function setAiModel(value) {
        if (["fast", "balanced", "smart", "coding"].includes(value))
            update(config => config.ai.model = value)
    }

    function widgetsFor(area) {
        const layout = data.bar.widgets
        return allBarWidgets
            .filter(widget => (layout[widget.id]?.area ?? "right") === area)
            .sort((a, b) => (layout[a.id]?.index ?? 999) - (layout[b.id]?.index ?? 999))
    }

    function widgetArea(widgetId) { return data.bar.widgets[widgetId]?.area ?? "right" }
    function widgetIndex(widgetId) { return widgetsFor(widgetArea(widgetId)).findIndex(widget => widget.id === widgetId) }
    function setWidgetArea(widgetId, area) { placeWidget(widgetId, area, "") }

    function placeWidget(widgetId, area, beforeId) {
        if (!["left", "center", "right"].includes(area)) return
        const groups = { left: [], center: [], right: [] }
        for (const candidateArea of ["left", "center", "right"])
            groups[candidateArea] = widgetsFor(candidateArea).map(widget => widget.id).filter(id => id !== widgetId)

        let insertIndex = beforeId ? groups[area].indexOf(beforeId) : -1
        if (insertIndex < 0) insertIndex = groups[area].length
        groups[area].splice(insertIndex, 0, widgetId)

        update(value => {
            const widgets = {}
            for (const candidateArea of ["left", "center", "right"])
                groups[candidateArea].forEach((id, index) => widgets[id] = { area: candidateArea, index: index })
            value.bar.widgets = widgets
        })
    }

    function moveWidget(widgetId, direction) {
        const area = widgetArea(widgetId)
        const ordered = widgetsFor(area).map(widget => widget.id)
        const index = ordered.indexOf(widgetId)
        const target = index + direction
        if (index < 0 || target < 0 || target >= ordered.length) return
        const swap = ordered[target]
        update(value => {
            value.bar.widgets[widgetId] = { area: area, index: target }
            value.bar.widgets[swap] = { area: area, index: index }
        })
    }

    function normalizeWidgetOrder() {
        update(value => {
            for (const area of ["left", "center", "right"])
                widgetsFor(area).forEach((widget, index) => value.bar.widgets[widget.id] = { area: area, index: index })
        })
    }

    function togglePin(appId) {
        const orderedPins = Array.from(pins)
        const index = orderedPins.indexOf(appId)
        if (index >= 0) orderedPins.splice(index, 1)
        else orderedPins.push(appId)
        setPins(orderedPins)
    }

    function movePin(sourceId, targetId) {
        const orderedPins = Array.from(pins)
        const sourceIndex = orderedPins.indexOf(sourceId)
        const targetIndex = orderedPins.indexOf(targetId)
        if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex) return
        orderedPins.splice(sourceIndex, 1)
        orderedPins.splice(targetIndex, 0, sourceId)
        setPins(orderedPins)
    }

    Timer {
        id: writeTimer
        interval: 100
        onTriggered: tomlFile.setText(root.serializeToml(root.data))
    }

    Timer {
        id: reloadTimer
        interval: 120
        onTriggered: parseProcess.running = true
    }

    FileView {
        id: tomlFile
        path: root.filePath
        watchChanges: true
        onLoaded: reloadTimer.restart()
        onFileChanged: reloadTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                migrationProcess.running = true
        }
    }

    Process {
        id: migrationProcess
        command: ["bash", "-c", `
            set -e
            toml="$1"
            json="$2"
            mkdir -p -- "$(dirname -- "$toml")"
            if [[ ! -e "$toml" && -f "$json" ]]; then
                tmp="$toml.tmp.$$"
                yq -p json -o toml '.' "$json" > "$tmp"
                mv -- "$tmp" "$toml"
                mv -- "$json" "$json.bak"
            elif [[ ! -e "$toml" ]]; then
                printf '# Seam configuration\n' > "$toml"
            fi
        `, "seam-config-migrate", root.filePath, root.legacyFilePath]
        onExited: exitCode => {
            if (exitCode === 0) {
                tomlFile.reload()
                parseProcess.running = true
            } else {
                console.warn("[DockPins] Failed to migrate config.json to config.toml")
                root.loading = false
            }
        }
    }

    Process {
        id: parseProcess
        command: ["yq", "-p", "toml", "-o", "json", ".", root.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = text.trim().length ? JSON.parse(text) : null
                    root.data = root.normalized(parsed)
                    root.loading = false
                    if (!parsed)
                        writeTimer.restart()
                } catch (error) {
                    console.warn("[DockPins] Invalid config.toml:", error)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length)
                    console.warn("[DockPins] TOML parse error:", text.trim())
            }
        }
    }

    Component.onCompleted: tomlFile.reload()
}
