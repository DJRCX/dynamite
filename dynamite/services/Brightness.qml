pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Smooth brightness: each output's `current` springs toward `target`; a coalescing writer pushes it to hardware.
Singleton {
    id: root
    // In the nested dev session, log writes instead of touching the real panel (DYNAMITE_REAL_BRIGHTNESS=1 overrides).
    readonly property bool dryRun: Quickshell.env("DYNAMITE_DEV") === "1" && Quickshell.env("DYNAMITE_REAL_BRIGHTNESS") !== "1"
    property var channels: ({})
    property string backlightDevice: ""
    signal osdRequested(string kind)

    function channelFor(output: string): var {
        if (channels[output]) return channels[output]
        if (output.startsWith("eDP") || output.startsWith("LVDS") || output === "winit") return channels["@internal"] ?? null
        return null
    }
    readonly property var focused: channelFor(Niri.focusedOutput)
    readonly property real focusedValue: focused ? focused.target : 0

    function set(output: string, percent: real): void {
        const channel = channelFor(output)
        if (channel) channel.target = Math.max(1, Math.min(100, percent))
    }
    function step(delta: real): void {
        const channel = focused
        if (!channel) return
        channel.target = Math.max(1, Math.min(100, Math.round(channel.target + delta)))
        osdRequested("brightness")
    }

    component Channel: Scope {
        id: channel
        property string output
        property string kind
        property string device
        property string bus
        property bool ready: false
        property real target: 50
        property real current: target
        property int lastWritten: -1
        Behavior on current {
            enabled: channel.ready
            SpringAnimation { spring: Motion.fade.spring; damping: Motion.fade.damping; epsilon: 0.05 }
        }

        function write(value: int): void {
            lastWritten = value
            if (root.dryRun) { console.info("[Dynamite] brightness (dry run)", output, value); return }
            writer.command = kind === "backlight"
                ? ["brightnessctl", "-q", "-d", device, "set", value + "%"]
                : ["ddcutil", "--bus", bus, "--noverify", "--sleep-multiplier", "0.2", "setvcp", "10", String(value)]
            writer.running = true
        }

        Timer {
            interval: 16
            repeat: true
            running: channel.ready && Math.round(channel.current) !== channel.lastWritten
            onTriggered: if (!writer.running) channel.write(Math.max(1, Math.round(channel.current)))
        }
        Process { id: writer }
        Process {
            id: reader
            running: true
            command: channel.kind === "backlight" ? ["brightnessctl", "-m", "-d", channel.device]
                                                  : ["ddcutil", "--bus", channel.bus, "getvcp", "10", "--terse"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let value = NaN
                    if (channel.kind === "backlight") value = parseFloat(text.trim().split(",")[3])
                    else {
                        const parts = text.trim().split(/\s+/)
                        value = 100 * parseFloat(parts[3]) / parseFloat(parts[4])
                    }
                    if (isNaN(value)) {
                        console.warn("[Dynamite] brightness: could not read", channel.output, text.trim())
                        return
                    }
                    channel.target = value
                    channel.lastWritten = Math.round(value)
                    channel.ready = true
                }
            }
        }
    }
    Component { id: channelComponent; Channel {} }

    function addChannel(key: string, props: var): void {
        const next = Object.assign({}, channels)
        next[key] = channelComponent.createObject(root, props)
        channels = next
    }

    Process {
        running: true
        command: ["brightnessctl", "-l", "-c", "backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const first = text.trim().split("\n")[0]
                if (!first) return
                root.backlightDevice = first.split(",")[0]
                root.addChannel("@internal", { output: "@internal", kind: "backlight", device: root.backlightDevice })
            }
        }
    }
    Process {
        running: true
        command: ["ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                let bus = ""
                let valid = false
                for (const line of text.split("\n")) {
                    if (/^Display \d+/.test(line)) { valid = true; bus = "" }
                    else if (/^\S/.test(line)) { valid = false; bus = "" }
                    const busMatch = line.match(/I2C bus:\s+\/dev\/i2c-(\d+)/)
                    if (busMatch) bus = busMatch[1]
                    const drm = line.match(/DRM connector:\s+card\d+-(\S+)/)
                    if (drm && bus && valid && !/^(eDP|LVDS)/.test(drm[1]))
                        root.addChannel(drm[1], { output: drm[1], kind: "ddc", bus: bus })
                }
            }
        }
    }
}
