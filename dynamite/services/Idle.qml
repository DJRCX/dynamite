pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.state

Singleton {
    id: root
    readonly property bool manualCaffeine: Config.caffeine.until === -1 || Config.caffeine.until > Date.now()
    readonly property bool caffeine: manualCaffeine || (Config.caffeine.whilePlaying && (Media.activePlayer?.isPlaying ?? false)) || (Config.caffeine.inGameMode && Island.gameMode)
    readonly property string subtitle: {
        clockTick
        if (Config.caffeine.until === -1) return "Until off"
        if (Config.caffeine.until > Date.now()) return Math.ceil((Config.caffeine.until - Date.now()) / 60000) + " min"
        if (Config.caffeine.whilePlaying && (Media.activePlayer?.isPlaying ?? false)) return "While playing"
        if (Config.caffeine.inGameMode && Island.gameMode) return "Game mode"
        return "Off"
    }
    property int clockTick: 0
    function toggle(): void { Config.caffeine.until = manualCaffeine ? 0 : -1 }
    function forMinutes(minutes: int): void { Config.caffeine.until = Date.now() + minutes * 60000 }
    function cycleDuration(): void {
        if (Config.caffeine.until === -1) { Config.caffeine.until = 0; return }
        const remaining = Config.caffeine.until - Date.now()
        if (remaining <= 0) forMinutes(30)
        else if (remaining <= 30 * 60000) forMinutes(60)
        else if (remaining <= 60 * 60000) forMinutes(120)
        else Config.caffeine.until = -1
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: {
            root.clockTick += 1
            if (Config.caffeine.until > 0 && Config.caffeine.until <= Date.now()) Config.caffeine.until = 0
        }
    }
    Process {
        running: Config.caffeine.blockSleep && root.caffeine
        command: ["systemd-inhibit", "--what=sleep:handle-lid-switch", "--who=dynamite", "--why=Caffeine", "sleep", "infinity"]
    }
    IdleMonitor {
        enabled: Config.idle.lockAfter > 0
        timeout: Config.idle.lockAfter
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        enabled: Config.idle.screenOffAfter > 0
        timeout: Config.idle.screenOffAfter
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
    }
}
