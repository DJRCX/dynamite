pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.config

Singleton {
    id: root
    property string error: ""
    property string lastAction: ""
    property var current: Config.wallpaper.current
    readonly property string directory: Quickshell.env("DYNAMITE_WALLPAPER_DIR") || Config.wallpaper.dir.replace(/^~/, Quickshell.env("HOME"))
    FolderListModel {
        id: files
        folder: "file://" + root.directory
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name
    }
    function set(path: string, output: string): void {
        const key = output || "*"
        Config.wallpaper.current = Object.assign({}, Config.wallpaper.current, ({ [key]: path }))
        lastAction = path
        if (Config.appearance.theme === "wallpaper") {
            paletteDir.running = true
        }
        if (Quickshell.env("DYNAMITE_DEV") === "1") {
            console.info("[Dynamite] dev wallpaper apply", key, path)
            return
        }
        applyProcess.command = ["awww", "img", path, "-o", key, "--transition-type", Config.wallpaper.transition,
                                "--transition-duration", String(Config.wallpaper.transitionSeconds)]
        applyProcess.running = true
    }
    function next(): void { step(1) }
    function prev(): void { step(-1) }
    function random(): void { if (files.count) set(files.get(Math.floor(Math.random() * files.count), "filePath"), "") }
    function step(delta: int): void {
        if (!files.count) return
        const currentPath = Config.wallpaper.current["*"] || ""
        let index = -1
        for (let i = 0; i < files.count; ++i) if (files.get(i, "filePath") === currentPath) { index = i; break }
        const nextIndex = ((index + delta) % files.count + files.count) % files.count
        set(files.get(nextIndex, "filePath"), "")
    }
    Process { id: applyProcess; command: ["awww", "query"]; onExited: (code) => { if (code !== 0) root.error = "awww unavailable" } }
    Process { id: paletteDir; command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/dynamite/themes"]
        onExited: (code) => {
            if (code !== 0) { root.error = "Could not create theme cache"; return }
            palette.command=["python3",Quickshell.shellDir+"/scripts/palette.py",root.lastAction,"--mode",Config.appearance.wallpaperMode,"--output",Quickshell.env("HOME")+"/.local/state/dynamite/themes/wallpaper.json"]
            palette.running=true
        }
    }
    Process { id: palette; command: ["python3",Quickshell.shellDir+"/scripts/palette.py",""]; onExited: (code) => { if(code===0) Themes.refresh(); else root.error="Palette generation failed" } }
    Timer {
        interval: Math.max(1, Config.wallpaper.slideshowMinutes) * 60000
        running: Config.wallpaper.slideshowMinutes > 0 && files.count > 1
        repeat: true
        onTriggered: root.next()
    }
}
