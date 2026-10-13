pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "WallpaperCommand.js" as WallpaperCommand

Singleton {
    id: root
    property string error: ""
    property string lastAction: ""
    property var current: Config.wallpaper.current

    function migrateStoredPaths(): void {
        if (!Themes.wallpapers.length) return
        const migrated = Object.assign({}, Config.wallpaper.current)
        let changed = false
        for (const output of Object.keys(migrated)) {
            const path = migrated[output]
            if (!path || Themes.wallpapers.some(file => file.path === path)) continue
            const filename = path.substring(path.lastIndexOf("/") + 1)
            const replacement = Themes.wallpapers.find(file => file.name === filename)
            if (replacement) { migrated[output] = replacement.path; changed = true }
        }
        if (changed) Config.wallpaper.current = migrated
    }

    Connections {
        target: Themes
        function onWallpapersChanged() { root.migrateStoredPaths() }
    }

    function set(path: string, output: string): void {
        const key = output || "*"
        Config.wallpaper.current = Object.assign({}, Config.wallpaper.current, ({ [key]: path }))
        lastAction = path
        if (Quickshell.env("DYNAMITE_DEV") === "1") {
            console.info("[Dynamite] dev wallpaper apply", key, path)
            return
        }
        root.error = ""
        applyProcess.exec(WallpaperCommand.image(path, key, Config.wallpaper.transition,
                                                Config.wallpaper.transitionSeconds))
    }
    function next(): void { step(1) }
    function prev(): void { step(-1) }
    function random(): void {
        const files = Themes.wallpapers
        if (files.length) set(files[Math.floor(Math.random() * files.length)].path, "")
    }
    function randomForTheme(themeName: string): void {
        // Themes with no assigned images fall back to the complete library.
        const path = WallpaperCommand.randomWallpaper(
            Themes.wallpapers, themeName, Config.wallpaper.current["*"] || "", Math.random())
        if (path) set(path, "")
    }
    function step(delta: int): void {
        const files = Themes.wallpapers
        if (!files.length) return
        const currentPath = Config.wallpaper.current["*"] || ""
        let index = -1
        for (let i = 0; i < files.length; ++i) if (files[i].path === currentPath) { index = i; break }
        const nextIndex = ((index + delta) % files.length + files.length) % files.length
        set(files[nextIndex].path, "")
    }
    Process {
        id: applyProcess
        command: ["awww", "query"]
        onExited: (code) => { root.error = code === 0 ? "" : "Wallpaper apply failed (awww exit " + code + ")" }
    }
    Timer {
        interval: Math.max(1, Config.wallpaper.slideshowMinutes) * 60000
        running: Config.wallpaper.slideshowMinutes > 0 && Themes.wallpapers.length > 1
        repeat: true
        onTriggered: root.next()
    }
}
