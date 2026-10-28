pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.theme

// Omarchy-format theme packages are indexed by the shared Python catalog.
Singleton {
    id: root
    // The shared index maps each image to its owning theme folder.
    property var list: []
    property var accentGroups: []
    property var wallpapers: []
    property string pendingWallpaperTheme: ""
    property string lastApplyRequested: ""
    property string queuedApplyName: ""
    readonly property string wallpaperDirectory: Config.wallpaper.dir.replace(/^~/, Quickshell.env("HOME"))
    function refresh(): void {
        reader.exec(["python3", Quickshell.shellDir + "/scripts/theme_catalog.py", "index",
                     "--wallpapers", wallpaperDirectory])
    }
    function apply(name: string, chooseWallpaper = true): void {
        // Set this before the config property so its change signal does not
        // start a duplicate render for an explicit picker selection.
        if (Config.startupReady && Quickshell.env("DYNAMITE_DEV") !== "1")
            lastApplyRequested = name
        Config.appearance.theme = name
        pendingWallpaperTheme = chooseWallpaper ? name : ""
        if (Quickshell.env("DYNAMITE_DEV") === "1") {
            if (chooseWallpaper) Wallpaper.randomForTheme(name)
            return
        }
        if (Config.startupReady) requestAppTheme(name)
    }
    function requestAppTheme(name: string): void {
        if (Quickshell.env("DYNAMITE_DEV") === "1") return
        queuedApplyName = name
        if (!applyProcess.running) runQueuedApply()
    }
    function runQueuedApply(): void {
        if (!queuedApplyName || applyProcess.running) return
        const name = queuedApplyName
        queuedApplyName = ""
        applyProcess.exec(["python3", Quickshell.shellDir + "/scripts/theme_manager.py", "apply", name, "--no-settings"])
    }
    function applyWithoutWallpaper(name: string): void { apply(name, false) }
    function setColorOverride(role: string, value: string): bool {
        const color = String(value).trim().toUpperCase()
        if (!/^#[0-9A-F]{6}$/.test(color)) return false
        const all = Object.assign({}, Config.appearance.colorOverrides || {})
        const current = Object.assign({}, all[Config.appearance.theme] || {})
        current[role] = color
        all[Config.appearance.theme] = current
        Config.appearance.colorOverrides = all
        return true
    }
    function resetColorOverride(role: string): void {
        const all = Object.assign({}, Config.appearance.colorOverrides || {})
        const current = Object.assign({}, all[Config.appearance.theme] || {})
        delete current[role]
        if (Object.keys(current).length) all[Config.appearance.theme] = current
        else delete all[Config.appearance.theme]
        Config.appearance.colorOverrides = all
    }
    function resetThemeOverrides(): void {
        const all = Object.assign({}, Config.appearance.colorOverrides || {})
        delete all[Config.appearance.theme]
        Config.appearance.colorOverrides = all
    }
    function indexOf(name: string, among: var): int { return among.findIndex(t => t.name === name) }

    Process {
        id: reader
        command: ["python3", Quickshell.shellDir + "/scripts/theme_catalog.py", "index",
                  "--wallpapers", root.wallpaperDirectory]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const index = JSON.parse(text)
                    root.list = index.themes || []
                    root.accentGroups = index.accentGroups || []
                    root.wallpapers = index.wallpapers || []
                    if (root.list.length && !root.list.some(theme => theme.name === Config.appearance.theme))
                        root.applyWithoutWallpaper("nord")
                } catch (error) {
                    console.warn("[Dynamite] could not read theme and wallpaper index:", error)
                }
            }
        }
    }

    Timer {
        id: overrideApplyTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (Config.startupReady && Config.appearance.theme !== "wallpaper")
                root.requestAppTheme(Config.appearance.theme)
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/themes/.dynamite-index"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    Process {
        id: applyProcess
        command: ["python3", Quickshell.shellDir + "/scripts/theme_manager.py", "apply", "nord", "--no-settings"]
        onExited: (code) => {
            if (code !== 0) console.warn("[Dynamite] theme config generation failed", code)
            else if (root.pendingWallpaperTheme && root.pendingWallpaperTheme === Config.appearance.theme)
                Wallpaper.randomForTheme(root.pendingWallpaperTheme)
            root.pendingWallpaperTheme = ""
            root.runQueuedApply()
        }
    }

    Connections {
        target: Config
        function onStartupReadyChanged(): void {
            if (!Config.startupReady) return
            if (root.list.length && !root.list.some(theme => theme.name === Config.appearance.theme)) {
                root.applyWithoutWallpaper("nord")
                return
            }
            if (Config.appearance.theme === "wallpaper") {
                root.applyWithoutWallpaper("nord")
                return
            }
            // Always regenerate managed application files from the selected
            // persisted palette, even when Quickshell itself already has a cache.
            root.lastApplyRequested = Config.appearance.theme
            root.requestAppTheme(Config.appearance.theme)
        }
    }
    Connections {
        target: Config.appearance
        function onThemeChanged(): void {
            if (!Config.startupReady || root.lastApplyRequested === Config.appearance.theme) return
            root.lastApplyRequested = Config.appearance.theme
            root.requestAppTheme(Config.appearance.theme)
        }
        function onColorOverridesChanged(): void {
            if (Config.startupReady) overrideApplyTimer.restart()
        }
    }

    Component.onCompleted: {
        refresh()
        if (Config.appearance.theme === "wallpaper") Config.appearance.theme = "nord"
        apply(Config.appearance.theme, false)
    }
    onWallpaperDirectoryChanged: refresh()
}
