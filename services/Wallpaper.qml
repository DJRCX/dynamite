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
    property bool daemonReady: false
    property var restoreQueue: []
    property var activeRestore: null
    property var seenOutputs: []
    property int retryDelay: 500

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
        if (!daemonReady) {
            probeDaemon()
            return
        }
        enqueue(path, key === "*" ? "" : key)
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
    function enqueue(path: string, output: string): void {
        if (!path) return
        const command = WallpaperCommand.image(path, output, Config.wallpaper.transition,
                                               Config.wallpaper.transitionSeconds)
        restoreQueue = restoreQueue.concat([{ path: path, command: command }])
        runNext()
    }
    function runNext(): void {
        if (!daemonReady || applyProcess.running || !restoreQueue.length) return
        activeRestore = restoreQueue[0]
        applyProcess.exec(activeRestore.command)
    }
    function restoreSaved(): void {
        if (!daemonReady || !Config.startupReady) return
        const saved = Config.wallpaper.current || ({})
        if (saved["*"]) enqueue(saved["*"], "")
        for (const output of Displays.outputs) {
            const path = saved[output.name]
            if (path) enqueue(path, output.name)
        }
        seenOutputs = Displays.outputs.map(output => output.name)
    }
    function probeDaemon(): void {
        if (!daemonReady && !daemonProbe.running) daemonProbe.running = true
    }
    function probeFinished(code: int): void {
        if (code === 0) {
            daemonReady = true
            retryDelay = 500
            root.error = ""
            restoreSaved()
            runNext()
        } else {
            daemonReady = false
            retryDelay = Math.min(8000, retryDelay * 2)
            retryProbe.interval = retryDelay
            retryProbe.restart()
        }
    }
    function restoreNewOutputs(): void {
        if (!daemonReady || !Config.startupReady) return
        const names = Displays.outputs.map(output => output.name)
        for (const output of Displays.outputs) {
            if (seenOutputs.includes(output.name)) continue
            const path = Config.wallpaper.current[output.name] || Config.wallpaper.current["*"] || ""
            if (path) enqueue(path, output.name)
        }
        seenOutputs = names
    }
    Process {
        id: daemonProbe
        command: ["awww", "query"]
        onExited: (code) => root.probeFinished(code)
    }
    Process {
        id: applyProcess
        onExited: (code) => {
            if (root.activeRestore) {
                if (code === 0) {
                    root.error = ""
                } else root.error = "Wallpaper apply failed (awww exit " + code + ")"
            }
            root.activeRestore = null
            root.restoreQueue = root.restoreQueue.slice(1)
            root.runNext()
        }
    }
    Timer { id: retryProbe; interval: 500; onTriggered: root.probeDaemon() }
    Connections {
        target: Config
        function onStartupReadyChanged() {
            if (!Config.startupReady) return
            if (root.daemonReady) root.restoreSaved()
            else root.probeDaemon()
        }
    }
    Connections {
        target: Displays
        function onOutputsChanged() { root.restoreNewOutputs() }
    }
    Component.onCompleted: if (Config.startupReady) probeDaemon()
    Timer {
        interval: Math.max(1, Config.wallpaper.slideshowMinutes) * 60000
        running: Config.wallpaper.slideshowMinutes > 0 && Themes.wallpapers.length > 1
        repeat: true
        onTriggered: root.next()
    }
}
