pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as QsBluetooth

Singleton {
    id: root
    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: preview || adapter !== null
    readonly property bool enabled: preview || (adapter?.enabled ?? false)
    readonly property bool discovering: preview ? discover : (adapter?.discovering ?? false)
    readonly property var devices: preview ? previewDevices.filter(d => d.present) : (adapter?.devices.values ?? [])
    readonly property var saved: devices.filter(d => d.paired || d.bonded)
    readonly property var nearby: devices.filter(d => !(d.paired || d.bonded) && d.name && d.name.length > 0)
    readonly property var connected: saved.filter(d => d.connected)

    // Set by the Bluetooth page while it's open. Only stops discovery that Dynamite started.
    property bool discover: false
    property bool startedDiscovery: false
    onDiscoverChanged: syncDiscovery()
    onEnabledChanged: syncDiscovery()
    function syncDiscovery(): void {
        if (preview || !adapter || !adapter.enabled) return
        if (discover && !adapter.discovering) {
            adapter.discovering = true
            startedDiscovery = true
        } else if (!discover && startedDiscovery) {
            adapter.discovering = false
            startedDiscovery = false
        }
    }

    function setEnabled(on: bool): void { if (adapter && !preview) adapter.enabled = on }
    function busy(device: var): bool {
        return device.pairing || device.state === QsBluetooth.BluetoothDeviceState.Connecting
            || device.state === QsBluetooth.BluetoothDeviceState.Disconnecting
    }
    function statusText(device: var): string {
        if (device.pairing) return "Pairing…"
        if (device.state === QsBluetooth.BluetoothDeviceState.Connecting) return "Connecting…"
        if (device.state === QsBluetooth.BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (device.connected)
            return device.batteryAvailable ? "Connected · " + Math.round(device.battery * 100) + "%" : "Connected"
        return device.paired || device.bonded ? "Saved" : "Not paired"
    }
    function iconFor(device: var): string {
        const icon = device.icon || ""
        if (icon.startsWith("audio-head")) return "headphones"
        if (icon.startsWith("audio")) return "speaker"
        if (icon === "input-keyboard") return "keyboard"
        if (icon === "input-mouse") return "mouse"
        if (icon === "input-gaming") return "sports_esports"
        if (icon.startsWith("phone")) return "smartphone"
        if (icon.startsWith("computer")) return "computer"
        return "bluetooth"
    }
    function toggleConnection(device: var): void {
        if (device.connected) device.disconnect()
        else device.connect()
    }
    function pairAndConnect(device: var): void {
        device.pair()
        pairWatch.target = device
    }

    Connections {
        id: pairWatch
        target: null
        ignoreUnknownSignals: true
        function onPairedChanged() {
            if (!target?.paired) return
            target.trusted = true
            target.connect()
            pairWatch.target = null
        }
    }

    // --- Dev-only preview: fake devices so the page can be exercised without touching real hardware. ---
    readonly property bool devMode: Quickshell.env("DYNAMITE_DEV") === "1"
    property bool preview: false
    property bool previewFound: false
    Timer { interval: 2500; running: root.preview && root.discover; onTriggered: root.previewFound = true }

    component PreviewDevice: QtObject {
        id: dev
        property string name
        property string icon: "audio-headphones"
        property bool paired: true
        property bool bonded: paired
        property bool trusted: paired
        property bool connected: false
        property bool pairing: false
        property int state: QsBluetooth.BluetoothDeviceState.Disconnected
        property bool batteryAvailable: true
        property real battery: 0.8
        property bool present: true
        property Timer settle: Timer { interval: 1600; onTriggered: dev.land() }
        function connect() { state = QsBluetooth.BluetoothDeviceState.Connecting; settle.restart() }
        function disconnect() { state = QsBluetooth.BluetoothDeviceState.Disconnecting; settle.restart() }
        function pair() { pairing = true; settle.restart() }
        function land() {
            if (pairing) { pairing = false; paired = true; return }
            connected = state === QsBluetooth.BluetoothDeviceState.Connecting
            state = connected ? QsBluetooth.BluetoothDeviceState.Connected : QsBluetooth.BluetoothDeviceState.Disconnected
        }
    }
    readonly property list<QtObject> previewDevices: [
        PreviewDevice { name: "Sane's AirPods Pro" },
        PreviewDevice { name: "WF-1000XM5" },
        PreviewDevice { name: "51-AB-9F-6B-4F-2E"; icon: ""; paired: false; present: root.previewFound },
        PreviewDevice { name: "A8-51-AB-95-05-E2"; icon: ""; paired: false; present: root.previewFound }
    ]

    IpcHandler {
        target: "bluetooth"
        function preview(on: bool): void {
            if (!root.devMode) return
            root.previewFound = false
            root.preview = on
        }
    }
}
