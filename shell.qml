import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.island
import qs.lock
import qs.services
import qs.settings
import qs.state

ShellRoot {
    // Singletons start lazily; touch the ones that must run from startup (servers, IPC, watchers).
        Component.onCompleted: [Niri.focusedOutput, Notifs.dnd, Brightness.dryRun, NightLight.enabled, Audio.volume, Bluetooth.enabled, Idle.caffeine, TerminalThemes.kittyTemplate,
                            Polkit.registered, Overlays.osdKind, Lock.locked, PowerProfile.current]

    LockScreen {}
    SettingsWindow { id: settingsWindow }

    Variants {
        model: Quickshell.screens
        IslandWindow { required property var modelData; screen: modelData }
    }
    Variants {
        model: Quickshell.screens
        Scrim { required property var modelData; screen: modelData }
    }

    IpcHandler {
        target: "island"
        function open(mode: string): void { Island.open(mode) }
        function close(): void { Island.close() }
        function toggle(mode: string): void { Island.toggle(mode) }
    }
    IpcHandler {
        target: "cc"
        function page(name: string): void {
            if (Island.mode !== "cc") Island.open("cc")
            Island.ccPage = name
        }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.step(5) }
        function down(): void { Brightness.step(-5) }
        function set(percent: int): void { Brightness.set(Niri.focusedOutput, percent) }
    }
    // Compatibility targets: the user's existing Niri binds call the legacy shell's IPC names.
    IpcHandler {
        target: "launcher"
        function toggle(): void { Island.toggle("launcher") }
    }
    IpcHandler {
        target: "powermenu"
        function toggle(): void { Island.toggle("power") }
    }
    IpcHandler {
        target: "gamemode"
        function toggle(): void { Island.setGameMode(!Island.gameMode) }
        function isOn(): bool { return Island.gameMode }
    }
    IpcHandler {
        target: "bar"
        function prevWorkspace(): void {}
        function nextWorkspace(): void {}
    }
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false) }
    }
    IpcHandler {
        target: "settings"
        function open(page: string): void { settingsWindow.page = page; settingsWindow.visible = true }
    }
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Wallpaper.set(path, "") }
        function random(): void { Wallpaper.random() }
        function next(): void { Wallpaper.next() }
        function prev(): void { Wallpaper.prev() }
    }
    IpcHandler { target: "clipboard"; function toggle(): void { Island.toggle("clipboard") } }
    IpcHandler { target: "cheatsheet"; function toggle(): void { Island.toggle("keybinds") } }
    IpcHandler {
        target: "power"
        function profile(name: string): void { PowerProfile.set(name) }
        function auto(): void { PowerProfile.automatic() }
        function debugBattery(percent: int, onBattery: bool): void { if (Quickshell.env("DYNAMITE_DEV") === "1") PowerProfile.debugBattery(percent, onBattery) }
    }
    IpcHandler {
        target: "caffeine"
        function toggle(): void { Idle.toggle() }
        function forMinutes(minutes: int): void { Idle.forMinutes(minutes) }
    }

    // Development-only settings hook for exercising live config reload and persistence.
    IpcHandler {
        target: "dev"
        function setConfig(path: string, value: string): void {
            if (!Config.setValue(path, value))
                console.warn("[Dynamite] dev.setConfig could not update config path", path)
        }
    }
}
