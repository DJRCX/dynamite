pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme

Singleton {
    id: root
    property string kittyTemplate: ""
    property string footTemplate: ""
    readonly property string overrideDir: Quickshell.env("DYNAMITE_TERMINAL_DIR")
    function render(template, background) {
        return template.replace(/\{\{background\}\}/g, background)
                       .replace(/\{\{text\}\}/g, Theme.text.toString())
                       .replace(/\{\{onAccent\}\}/g, Theme.onAccent.toString())
                       .replace(/\{\{accent\}\}/g, Theme.accent.toString())
                       .replace(/\{\{opacity\}\}/g, String(Config.terminal.opacity))
    }
    function refresh(): void {
        if (Quickshell.env("DYNAMITE_DEV") === "1") {
            console.info("[Dynamite] terminal theme export suppressed in dev")
            return
        }
        if (Config.terminal.kitty && kittyTemplate) kittyCheck.running = true
        if (Config.terminal.foot && footTemplate) footCheck.running = true
    }
    FileView {
        path: Quickshell.shellDir + "/templates/kitty.conf"
        onLoaded: { root.kittyTemplate = text(); root.refresh() }
    }
    FileView {
        path: Quickshell.shellDir + "/templates/foot.ini"
        onLoaded: { root.footTemplate = text(); root.refresh() }
    }
    Connections {
        target: Config.appearance
        function onThemeChanged() { debounce.restart() }
    }
    Connections {
        target: Config.terminal
        function onOpacityChanged() { debounce.restart() }
        function onBackgroundChanged() { debounce.restart() }
        function onKittyChanged() { debounce.restart() }
        function onFootChanged() { debounce.restart() }
    }
    Timer { id: debounce; interval: 300; onTriggered: root.refresh() }
    readonly property string outputDir: overrideDir || (Quickshell.env("HOME") + "/.config")
    readonly property string kittyFilePath: overrideDir ? outputDir + "/current-theme.conf" : outputDir + "/kitty/current-theme.conf"
    readonly property string footFilePath: overrideDir ? outputDir + "/foot-colors.ini" : outputDir + "/foot/colors.ini"
    Process {
        id: kittyCheck
        command: ["test", "-d", root.overrideDir || (Quickshell.env("HOME") + "/.config/kitty")]
        onExited: code => {
            if (code !== 0) return
            kittyFile.path = root.kittyFilePath
            kittyFile.setText(root.render(root.kittyTemplate, Config.terminal.background === "black" ? Theme.island.toString() : Theme.window.toString()))
            if (!root.overrideDir) Quickshell.execDetached(["pkill", "-USR1", "kitty"])
        }
    }
    Process {
        id: footCheck
        command: ["test", "-d", root.overrideDir || (Quickshell.env("HOME") + "/.config/foot")]
        onExited: code => {
            if (code !== 0) return
            footFile.path = root.footFilePath
            footFile.setText(root.render(root.footTemplate, Config.terminal.background === "black" ? Theme.island.toString() : Theme.window.toString()))
        }
    }
    FileView { id: kittyFile; path: root.kittyFilePath; printErrors: false }
    FileView { id: footFile; path: root.footFilePath; printErrors: false }
}
