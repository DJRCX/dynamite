pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Niri outputs (`niri msg -j outputs`). Scale/mode changes are runtime-only; Dynamite never edits the Niri config.
Singleton {
    id: root
    // [{ name, make, model, width, height, refresh (mHz), scale, modes: [{ width, height, refresh, index }], current }]
    property var outputs: []

    function refresh(): void { reader.running = true }

    function scaleLabel(scale: real): string {
        return (Number.isInteger(scale) ? scale.toFixed(1) : String(scale)) + "×"
    }
    function modeLabel(mode: var): string {
        return mode ? mode.width + "×" + mode.height + " @ " + Math.round(mode.refresh / 1000) + " Hz" : ""
    }
    function summary(output: var): string {
        return output.width + "×" + output.height + "  ·  " + Math.round(output.refresh / 1000) + " Hz  ·  " + scaleLabel(output.scale)
    }

    function setScale(name: string, scale: real): void {
        run(["niri", "msg", "output", name, "scale", String(scale)])
    }
    function setMode(name: string, mode: var): void {
        run(["niri", "msg", "output", name, "mode",
             mode.width + "x" + mode.height + "@" + (mode.refresh / 1000).toFixed(3)])
    }
    function run(command: var): void {
        Quickshell.execDetached(command)
        settle.restart()
    }
    Timer { id: settle; interval: 400; onTriggered: root.refresh() }

    Process {
        id: reader
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = {}
                try { data = JSON.parse(text) } catch (error) { console.warn("[Dynamite] niri outputs:", error); return }
                const list = []
                for (const name of Object.keys(data).sort()) {
                    const o = data[name]
                    if (o.current_mode === null || o.current_mode === undefined || !o.logical) continue
                    const modes = o.modes.map((m, index) => ({ width: m.width, height: m.height, refresh: m.refresh_rate, index: index }))
                    const current = modes[o.current_mode]
                    list.push({
                        name: name, make: o.make, model: o.model,
                        width: current.width, height: current.height, refresh: current.refresh,
                        scale: o.logical.scale, modes: modes, current: o.current_mode
                    })
                }
                root.outputs = list
            }
        }
    }
}
