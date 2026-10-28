pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real inputVolume: source?.audio?.volume ?? 0
    readonly property bool inputMuted: source?.audio?.muted ?? false

    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputs: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => n.audio && !n.isSink && !n.isStream)
    // App playback streams (Quickshell types these as AudioOutStream, which carries the Sink flag).
    readonly property var streams: nodes.filter(n => n.audio && n.type === PwNodeType.AudioOutStream)
    property var cards: []
    readonly property bool dryRun: Quickshell.env("DYNAMITE_DEV") === "1"

    // True while a CC/Sound slider is moving (and briefly after), so the OSD stays quiet.
    property bool adjusting: false
    signal osdRequested(string kind)
    function touch(): void { adjusting = true; settle.restart() }
    Timer { id: settle; interval: 400; onTriggered: root.adjusting = false }

    function nodeName(node: PwNode): string {
        return node?.properties?.["application.name"] || label(node)
    }
    function iconFor(node: PwNode): string {
        if (!node) return "volume_up"
        if (!node.isSink) return "mic"
        const text = ((node.description || "") + " " + (node.name || "")).toLowerCase()
        if (text.includes("headphone") || text.includes("headset") || text.includes("bluez")) return "headphones"
        if (text.includes("hdmi") || text.includes("displayport")) return "desktop_windows"
        return "speaker"
    }

    readonly property string volumeIcon: muted || volume <= 0.001 ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"

    function setVolume(value: real): void {
        if (!sink?.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, value))
        if (value > 0 && sink.audio.muted) sink.audio.muted = false
    }
    function setInputVolume(value: real): void {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, value))
    }
    function setNodeVolume(node: PwNode, value: real): void {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, value))
    }
    function toggleMute(): void { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
    function setDefault(node: PwNode): void {
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function refreshCards(): void { if (!cardReader.running) cardReader.running = true }
    function setCardProfile(card: string, profile: string): void {
        if (!card || !profile) return
        if (dryRun) {
            console.info("[Dynamite] audio profile (dry run)", card, profile)
            return
        }
        profileWriter.exec(["pactl", "set-card-profile", card, profile])
        profileRefresh.restart()
    }
    function label(node: PwNode): string {
        return node?.description || node?.nickname || node?.name || "Unknown"
    }

    PwObjectTracker { objects: [root.sink, root.source] }

    Process {
        id: cardReader
        command: ["pactl", "--format=json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.cards = data.map(card => ({
                        id: card.name,
                        name: card.properties?.["device.description"] || card.name,
                        profiles: Object.keys(card.profiles || {}).map(profile => ({
                            name: profile,
                            description: card.profiles[profile].description || profile,
                            available: card.profiles[profile].available === true,
                            sinks: Number(card.profiles[profile].sinks || 0),
                            sources: Number(card.profiles[profile].sources || 0)
                        })).filter(profile => profile.available && (profile.sinks || profile.sources)),
                        activeProfile: card.active_profile || ""
                    }))
                } catch (error) {
                    root.cards = []
                    console.warn("[Dynamite] could not read audio card profiles:", error)
                }
            }
        }
    }
    Process { id: profileWriter }
    Timer { id: profileRefresh; interval: 650; onTriggered: root.refreshCards() }

    // Only real volume/mute changes raise the OSD: not the initial values, nor a switch of the default sink.
    property bool armed: false
    Timer { running: true; interval: 1500; onTriggered: { root.reportedSink = root.sink; root.armed = true } }
    property PwNode reportedSink: null
    onSinkChanged: touch()
    function report(): void {
        if (!armed || !sink?.ready) return
        if (sink !== reportedSink) { reportedSink = sink; return }
        if (!adjusting) osdRequested("volume")
    }
    onVolumeChanged: report()
    onMutedChanged: report()
}
