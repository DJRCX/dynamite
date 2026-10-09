pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    property bool visible: false
    property real cpu: 0
    property real memory: 0
    property real temperature: 0
    property var history: []
    property var memoryHistory: []
    property var temperatureHistory: []
    property var topProcesses: []
    property var previous: []
    property var zoneTypes: []
    property var zoneTemps: []
    readonly property var sensors: ["auto"].concat(zoneTypes.filter((v, i) => v && zoneTemps[i] !== undefined))
    readonly property string tempSensorName: {
        if (Config.sysmon.tempSensor !== "auto" && zoneTypes.includes(Config.sysmon.tempSensor)) return Config.sysmon.tempSensor
        for (const type of ["x86_pkg_temp", "coretemp", "k10temp", "zenpower", "acpitz"]) {
            const index = zoneTypes.indexOf(type)
            if (index >= 0 && zoneTemps[index] !== undefined) return type
        }
        return zoneTypes.find((v, i) => v && zoneTemps[i] !== undefined) || "Unavailable"
    }
    function refresh(): void {
        if (!visible) return
        stat.reload(); mem.reload()
        for (let i = 0; i < 9; ++i) zoneReaders.objectAt(i)?.reload()
        processes.running = true
    }
    function updateCpu(text: string): void {
        const row=text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
        const idle=row[3]+row[4], total=row.reduce((a,b)=>a+b,0)
        if (previous.length) { const dt=total-previous[1], di=idle-previous[0]; cpu=dt>0?100*(dt-di)/dt:0 }
        previous=[idle,total]; history=history.concat([cpu]).slice(-60)
    }
    FileView { id: stat; path: "/proc/stat"; onLoaded: root.updateCpu(text()) }
    FileView { id: mem; path: "/proc/meminfo"; onLoaded: {
        const total=Number((text().match(/MemTotal:\s+(\d+)/)||[])[1]||0), avail=Number((text().match(/MemAvailable:\s+(\d+)/)||[])[1]||0)
        root.memory=total?100*(total-avail)/total:0
        root.memoryHistory=root.memoryHistory.concat([root.memory]).slice(-60)
    } }
    function updateTemperature(): void {
        const index = zoneTypes.indexOf(tempSensorName)
        if (index >= 0 && zoneTemps[index] !== undefined) {
            temperature = zoneTemps[index]
            temperatureHistory = temperatureHistory.concat([temperature]).slice(-60)
        }
    }
    Instantiator {
        id: zoneReaders
        model: 9
        delegate: Item {
            id: zoneEntry
            required property int index
            readonly property int zoneIndex: index
            function reload(): void { typeFile.reload(); tempFile.reload() }
            FileView {
                id: typeFile
                path: "/sys/class/thermal/thermal_zone" + zoneEntry.zoneIndex + "/type"
                printErrors: false
                onLoaded: {
                    const next = root.zoneTypes.slice(); next[zoneEntry.zoneIndex] = text().trim(); root.zoneTypes = next
                    root.updateTemperature()
                }
            }
            FileView {
                id: tempFile
                path: "/sys/class/thermal/thermal_zone" + zoneEntry.zoneIndex + "/temp"
                printErrors: false
                onLoaded: {
                    const next = root.zoneTemps.slice(); next[zoneEntry.zoneIndex] = Number(text().trim()) / 1000; root.zoneTemps = next
                    root.updateTemperature()
                }
            }
        }
    }
    Connections { target: Config.sysmon; function onTempSensorChanged() { root.updateTemperature() } }
    Process {
        id: processes
        command: ["ps", "-eo", "pid,comm,%cpu,%mem", "--sort=-%cpu"]
        stdout: StdioCollector {
            onStreamFinished: root.topProcesses = text.trim().split("\n").slice(1, 6).map(line => {
                const cols = line.trim().split(/\s+/)
                return { pid:Number(cols[0]), name:cols[1] || "?", cpu:Number(cols[2] || 0), memory:Number(cols[3] || 0) }
            })
        }
    }
    Process { id: endProcess; command: ["/usr/bin/kill", "-TERM", "0"] }
    function end(pid: int): void { endProcess.command = ["/usr/bin/kill", "-TERM", String(pid)]; endProcess.running = true }
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.refresh() }
}
