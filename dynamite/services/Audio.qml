pragma Singleton
import QtQuick
import Quickshell
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
    function label(node: PwNode): string {
        return node?.description || node?.nickname || node?.name || "Unknown"
    }

    PwObjectTracker { objects: [root.sink, root.source] }

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
