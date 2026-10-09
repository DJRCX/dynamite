pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// wlsunset with low/high one kelvin apart = a constant temperature.
// Slider drags only move `temperature`; the config write and the wlsunset restart happen 250 ms after the last change.
Singleton {
    id: root
    readonly property bool enabled: Config.display.nightLight
    property int pending: -1
    readonly property int temperature: pending >= 0 ? pending : Config.display.nightLightTemp
    property int applied: Config.display.nightLightTemp
    readonly property int minTemp: 2500
    readonly property int maxTemp: 6500

    function setEnabled(on: bool): void { Config.display.nightLight = on }
    function setTemperature(kelvin: int): void {
        pending = Math.round(Math.max(minTemp, Math.min(maxTemp, kelvin)) / 50) * 50
        debounce.restart()
    }
    // Hand edits of settings.json restart wlsunset too.
    onTemperatureChanged: if (pending < 0) debounce.restart()

    Timer {
        id: debounce
        interval: 250
        onTriggered: {
            if (root.pending >= 0) Config.display.nightLightTemp = root.pending
            root.pending = -1
            if (root.applied === Config.display.nightLightTemp) return
            root.applied = Config.display.nightLightTemp
            if (sunset.running) { sunset.running = false; restart.start() }
        }
    }
    Timer { id: restart; interval: 50; onTriggered: sunset.running = root.enabled }

    Process {
        id: sunset
        running: root.enabled
        command: ["wlsunset", "-t", String(root.applied), "-T", String(root.applied + 1), "-S", "06:00", "-s", "18:00"]
    }
}
