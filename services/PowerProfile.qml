pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// TLP power profile via tlpctl. In the nested dev session writes are only logged.
Singleton {
    id: root
    readonly property bool dryRun: Quickshell.env("DYNAMITE_DEV") === "1"
    property string current: ""
    property bool onBattery: false
    property int percent: 100
    property bool manualOverride: false

    function refresh(): void { reader.running = true }
    function set(profile: string): void { applyProfile(profile, true) }
    function setAutomatic(profile: string): void { applyProfile(profile, false) }
    function applyProfile(profile: string, manual: bool): void {
        if (!["performance", "balanced", "power-saver"].includes(profile)) return
        if (manual) manualOverride = true
        if (dryRun) {
            console.log("[Dynamite] dry run: tlpctl", profile)
            current = profile
            return
        }
        Quickshell.execDetached(["tlpctl", profile])
        current = profile
        refreshLater.restart()
    }
    function automatic(): void { manualOverride = false; choose() }
    function debugBattery(value: int, battery: bool): void {
        if (!dryRun) return
        const changed = battery !== onBattery
        onBattery = battery; percent = Math.max(0, Math.min(100, value))
        if (changed) manualOverride = false
        choose()
    }
    function choose(): void {
        if (!Config.power.auto || manualOverride) return
        if (!onBattery) setAutomatic("performance")
        else if (current === "power-saver" && percent <= Config.power.saverAt + Config.power.hysteresis) return
        else { const wanted = percent <= Config.power.saverAt ? "power-saver" : "balanced"; setAutomatic(wanted); manualOverride = false }
    }

    Component.onCompleted: refresh()

    Process {
        id: reader
        command: ["tlpctl", "get"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.current = text.trim() }
    }
    Timer { id: refreshLater; interval: 1500; onTriggered: root.refresh() }
}
