pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath

    function reapplyTheme() {
        themeFileView.reload()
        delayedFileRead.restart()
    }

    function applyColors(fileContent) {
        if (!fileContent || fileContent.trim().length === 0)
            return

        try {
            const generated = JSON.parse(fileContent)
            // Seam's Matugen template stores Material colors inside `md3`.
            // Also accept end-4's flat format for compatibility.
            const json = generated.md3 ?? generated

            for (const key in json) {
                if (json.hasOwnProperty(key)) {
                    const camelCaseKey = key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase())
                    const m3Key = `m3${camelCaseKey}`
                    if (Appearance.m3colors[m3Key] !== undefined)
                        Appearance.m3colors[m3Key] = json[key]
                }
            }

            Appearance.m3colors.darkmode = Appearance.m3colors.m3background.hslLightness < 0.5
            console.info(`[MaterialThemeLoader] Applied background ${Appearance.m3colors.m3background}, primary ${Appearance.m3colors.m3primary}`)
        } catch (error) {
            console.warn("Could not load generated Material colors:", error)
        }
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

	FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoaded: root.applyColors(text())
        onLoadFailed: root.resetFilePathNextTime();
    }

    function toggleLightDark() {
        const currentlyDark = Appearance.m3colors.darkmode;
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", currentlyDark ? "light" : "dark", "--noswitch"]);
    }

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"

        onPressed: {
            root.toggleLightDark();
        }
    }

    IpcHandler {
        target: "theme"

        function reload(): void {
            root.reapplyTheme();
        }

        function toggleLightDark(): void {
            root.toggleLightDark();
        }
    }
}
