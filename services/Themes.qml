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
    readonly property string wallpaperDirectory: Config.wallpaper.dir.replace(/^~/, Quickshell.env("HOME"))
    function refresh(): void {
        reader.exec(["python3", Quickshell.shellDir + "/scripts/theme_catalog.py", "index",
                     "--wallpapers", wallpaperDirectory])
    }
    function apply(name: string, chooseWallpaper = true): void {
        Config.appearance.theme = name
        pendingWallpaperTheme = chooseWallpaper ? name : ""
        if (Quickshell.env("DYNAMITE_DEV") === "1") {
            if (chooseWallpaper) Wallpaper.randomForTheme(name)
            return
        }
        applyProcess.exec(["python3", Quickshell.shellDir + "/scripts/theme_manager.py", "apply", name, "--no-settings"])
    }
    function applyWithoutWallpaper(name: string): void { apply(name, false) }
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
        }
    }

    Component.onCompleted: {
        refresh()
        if (Config.appearance.theme === "wallpaper") Config.appearance.theme = "nord"
        apply(Config.appearance.theme, false)
    }
    onWallpaperDirectoryChanged: refresh()
}
