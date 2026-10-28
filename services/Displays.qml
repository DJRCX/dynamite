pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Niri output state and runtime configuration. Arrangements are persisted in
// Dynamite settings and reapplied once the compositor and settings are ready.
Singleton {
    id: root
    property var outputs: []
    property string outputSignature: ""
    property var commandQueue: []
    property string useOnlyPending: ""
    property bool startupApplied: false
    readonly property bool dryRun: Quickshell.env("DYNAMITE_DEV") === "1"
    property string message: ""

    function refresh(): void {
        if (!reader.running) reader.running = true
    }
    function scaleLabel(scale: real): string {
        return (Number.isInteger(scale) ? scale.toFixed(1) : String(scale)) + "×"
    }
    function modeLabel(mode: var): string {
        return mode ? mode.width + "×" + mode.height + " @ " + Math.round(mode.refresh / 1000) + " Hz" : ""
    }
    function summary(output: var): string {
        return output.width + "×" + output.height + "  ·  " + Math.round(output.refresh / 1000) + " Hz  ·  " + scaleLabel(output.scale)
    }
    function layout(): var { return Config.display.outputLayout || ({}) }
    function saveRecord(name: string, patch: var): void {
        const records = Object.assign({}, layout())
        records[name] = Object.assign({}, records[name] || ({}), patch)
        Config.display.outputLayout = records
    }
    function queue(command: var): void {
        if (dryRun) {
            console.info("[Dynamite] display configuration (dry run)", JSON.stringify(command))
            return
        }
        commandQueue = commandQueue.concat([command])
        runNext()
    }
    function runNext(): void {
        if (runner.running || !commandQueue.length) {
            if (!commandQueue.length) settle.restart()
            return
        }
        runner.exec(commandQueue[0])
    }
    function setScale(name: string, scale: real): void {
        queue(["niri", "msg", "output", name, "scale", String(scale)])
    }
    function setMode(name: string, mode: var): void {
        queue(["niri", "msg", "output", name, "mode",
               mode.width + "x" + mode.height + "@" + (mode.refresh / 1000).toFixed(3)])
    }
    function setPosition(name: string, x: real, y: real): bool {
        const target = outputs.find(output => output.name === name)
        if (!target) return false
        const nx = Math.round(x), ny = Math.round(y)
        for (const other of outputs) {
            if (other.name === name || !other.enabled) continue
            const overlap = nx < other.x + other.width && nx + target.width > other.x
                && ny < other.y + other.height && ny + target.height > other.y
            if (overlap) {
                message = "Displays cannot overlap. Move this display clear of the others."
                return false
            }
        }
        message = ""
        saveRecord(name, { x: nx, y: ny })
        queue(["niri", "msg", "output", name, "position", "set", String(nx), String(ny)])
        return true
    }
    function setEnabled(name: string, enabled: bool): bool {
        const target = outputs.find(output => output.name === name)
        if (!target || target.enabled === enabled) return true
        if (!enabled && outputs.filter(output => output.enabled).length <= 1) {
            message = "At least one display must remain enabled."
            return false
        }
        message = ""
        saveRecord(name, { enabled: enabled })
        queue(["niri", "msg", "output", name, enabled ? "on" : "off"])
        const saved = layout()[name]
        if (enabled && saved?.x !== undefined && saved?.y !== undefined)
            queue(["niri", "msg", "output", name, "position", "set", String(saved.x), String(saved.y)])
        return true
    }
    function extendAll(): void {
        message = ""
        for (const output of outputs) {
            if (!output.enabled) setEnabled(output.name, true)
            else saveRecord(output.name, { enabled: true })
        }
    }
    function disableOtherOutputs(name: string): void {
        saveRecord(name, { enabled: true })
        for (const output of outputs) {
            if (output.name === name) continue
            saveRecord(output.name, { enabled: false })
            if (output.enabled) queue(["niri", "msg", "output", output.name, "off"])
        }
    }
    function useOnly(name: string): void {
        if (useOnlyPending) return
        const target = outputs.find(output => output.name === name)
        if (!target) return
        message = ""
        if (target.enabled) {
            disableOtherOutputs(name)
            return
        }
        useOnlyPending = name
        if (!setEnabled(name, true)) {
            useOnlyPending = ""
            return
        }
        if (dryRun) {
            useOnlyPending = ""
            disableOtherOutputs(name)
        }
    }
    function prioritize(name: string): void {
        Config.display.startupFocusOutput = name
        const output = outputs.find(item => item.name === name)
        if (output && !output.enabled) setEnabled(name, true)
        queue(["niri", "msg", "action", "focus-monitor", name])
    }
    function applySaved(): void {
        if (startupApplied || !Config.startupReady || !outputs.length) return
        startupApplied = true
        const records = layout()
        const on = [], positions = [], off = []
        for (const output of outputs) {
            const saved = records[output.name]
            if (!saved) continue
            if (saved.enabled === true && !output.enabled)
                on.push(["niri", "msg", "output", output.name, "on"])
            if ((saved.enabled !== false || output.enabled) && saved.x !== undefined && saved.y !== undefined)
                positions.push(["niri", "msg", "output", output.name, "position", "set", String(saved.x), String(saved.y)])
            if (saved.enabled === false && output.enabled) off.push(["niri", "msg", "output", output.name, "off"])
        }
        const activeAfter = outputs.filter(output => records[output.name]?.enabled !== false).length
        if (activeAfter === 0 && off.length) off.pop()
        for (const command of on.concat(positions, off)) queue(command)
        if (Config.display.startupFocusOutput)
            queue(["niri", "msg", "action", "focus-monitor", Config.display.startupFocusOutput])
    }

    Process {
        id: reader
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = {}
                try { data = JSON.parse(text) }
                catch (error) { console.warn("[Dynamite] niri outputs:", error); return }
                const saved = root.layout(), list = []
                for (const name of Object.keys(data).sort()) {
                    const o = data[name]
                    const modes = (o.modes || []).map((m, index) => ({
                        width: m.width, height: m.height, refresh: m.refresh_rate,
                        index: index, preferred: !!m.is_preferred
                    }))
                    const enabled = o.current_mode !== null && o.current_mode !== undefined && !!o.logical
                    if (!enabled && name.startsWith("Virtual-")) continue
                    const record = saved[name] || ({})
                    const selected = enabled ? modes[o.current_mode]
                        : (modes.find(mode => mode.preferred) || modes[0])
                    if (!selected) continue
                    const scale = enabled ? o.logical.scale : (Number(record.scale) || 1)
                    list.push({
                        name: name, make: o.make, model: o.model, enabled: enabled,
                        width: enabled ? o.logical.width : selected.width / scale,
                        height: enabled ? o.logical.height : selected.height / scale,
                        x: enabled ? o.logical.x : Number(record.x || 0),
                        y: enabled ? o.logical.y : Number(record.y || 0),
                        scale: scale, transform: enabled ? o.logical.transform : "Normal",
                        refresh: enabled ? selected.refresh : selected.refresh,
                        modes: modes, current: enabled ? o.current_mode : -1
                    })
                }
                const signature = JSON.stringify(list)
                if (signature !== root.outputSignature) {
                    root.outputSignature = signature
                    root.outputs = list
                }
                root.applySaved()
            }
        }
    }
    Process {
        id: runner
        onExited: (code) => {
            const command = root.commandQueue[0]
            if (code !== 0) root.message = "Niri could not apply a display change. Check the output and try again."
            if (root.useOnlyPending && command && command[3] === root.useOnlyPending && command[4] === "on") {
                const name = root.useOnlyPending
                root.useOnlyPending = ""
                if (code === 0) root.disableOtherOutputs(name)
                else root.saveRecord(name, { enabled: false })
            }
            root.commandQueue = root.commandQueue.slice(1)
            root.runNext()
        }
    }
    Timer { id: settle; interval: 500; onTriggered: root.refresh() }
    Timer { interval: 4000; repeat: true; running: true; onTriggered: root.refresh() }
    Connections {
        target: Config
        function onStartupReadyChanged() { root.applySaved() }
    }
}
