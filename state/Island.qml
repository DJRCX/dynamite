pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root
    // collapsed | clock | calendar | media | cc | launcher | power | osd | toast | polkit | themes
    property string mode: "collapsed"
    property string ccPage: "main"
    // Output the panel is open on; "" means every output.
    property string screenName: ""
    property alias gameMode: game.on
    property bool editing: false

    // Survives config reloads, so the saved DND state and profile are still restored on exit.
    PersistentProperties {
        id: game
        reloadableId: "dynamite-gamemode"
        property bool on: false
        property bool previousDnd: false
        property string previousProfile: ""
    }
    // Set by the launcher as its result count changes (83 + 47 · n).
    property real launcherHeight: 366
    property real clipboardHeight: 380

    readonly property var modes: ["clock", "calendar", "media", "cc", "launcher", "power", "osd", "toast", "polkit", "themes", "wallpapers", "clipboard", "keybinds", "window"]
    readonly property bool interactive: ["calendar", "media", "cc", "launcher", "power", "polkit", "themes", "wallpapers", "clipboard", "keybinds", "window"].includes(mode)
    readonly property bool wantsKeyboard: ["launcher", "power", "polkit", "themes", "wallpapers", "clipboard", "keybinds", "window", "cc", "calendar", "media"].includes(mode)
    readonly property bool exclusiveKeyboard: ["launcher", "power", "polkit", "themes", "wallpapers", "clipboard", "keybinds", "window"].includes(mode)

    // Text fields inside a panel call this when they give up focus, so Esc/Backspace reach the island again.
    signal focusRequested()
    function returnFocus() { focusRequested() }

    function modeOn(name: string): string {
        return screenName === "" || screenName === name ? mode : "collapsed"
    }

    function open(nextMode, onScreen) {
        if (!modes.includes(nextMode)) return
        if (mode === "polkit" && nextMode !== "polkit") return
        if (nextMode === "window") WindowMenu.capture()
        screenName = onScreen ? onScreen : Niri.focusedOutput
        if (nextMode !== "cc") ccPage = "main"
        mode = nextMode
    }
    function close() { mode = "collapsed"; ccPage = "main" }
    function setGameMode(on: bool): void {
        if (on === game.on) return
        if (on) {
            game.previousDnd = Notifs.dnd
            Notifs.setDnd(true)
            PowerProfile.setAutomatic("performance")
        } else {
            Notifs.setDnd(game.previousDnd)
            PowerProfile.automatic()
        }
        game.on = on
    }
    function toggle(nextMode, onScreen) {
        mode === nextMode ? close() : open(nextMode, onScreen)
    }
}
