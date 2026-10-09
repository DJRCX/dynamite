pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root
    readonly property var wifi: {
        const devices = Networking.devices.values
        return devices.find(device => device.type === DeviceType.Wifi) || null
    }
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var networks: wifi?.networks.values ?? []
    readonly property var active: networks.find(network => network.connected) || null
    readonly property var wired: Networking.devices.values.find(device => device.type === DeviceType.Wired) || null
    readonly property bool wiredLink: wired?.hasLink ?? false

    // Networks other than the active one: one per SSID, saved first, then by signal bars, then by name
    // (raw signal reshuffles the list on every scan).
    function bars(strength: real): int { return Math.min(3, Math.floor(strength * 4)) }
    readonly property var others: {
        const best = {}
        for (const network of networks) {
            if (!network.name || network.connected) continue
            const seen = best[network.name]
            if (!seen || network.signalStrength > seen.signalStrength) best[network.name] = network
        }
        return Object.values(best).sort((a, b) => (b.known - a.known)
            || (bars(b.signalStrength) - bars(a.signalStrength)) || a.name.localeCompare(b.name))
    }

    // Set by the Wi-Fi page while it's open; drives the device's periodic scanner.
    property bool scanning: false
    readonly property bool scannerOn: wifi?.scannerEnabled ?? false
    onScanningChanged: syncScanner()
    onWifiChanged: syncScanner()
    function syncScanner(): void {
        if (wifi && wifi.scannerEnabled !== scanning) wifi.scannerEnabled = scanning
    }

    function strengthIcon(strength: real): string {
        return strength >= 0.75 ? "wifi" : strength >= 0.5 ? "network_wifi_3_bar"
             : strength >= 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
    }
    readonly property string wifiIcon: wiredLink && !active ? "lan"
        : !wifiEnabled ? "wifi_off"
        : active ? strengthIcon(active.signalStrength) : "signal_wifi_statusbar_not_connected"

    function isOpen(network: var): bool {
        return network?.security === WifiSecurityType.Open || network?.security === WifiSecurityType.Owe
    }
    function securityLabel(network: var): string {
        switch (network?.security) {
        case WifiSecurityType.Open: return "Open"
        case WifiSecurityType.Owe: return "OWE"
        case WifiSecurityType.WpaPsk: return "WPA"
        case WifiSecurityType.Wpa2Psk: return "WPA2"
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3"
        case WifiSecurityType.WpaEap: return "Enterprise"
        case WifiSecurityType.Wpa2Eap: return "Enterprise"
        case WifiSecurityType.StaticWep: return "WEP"
        case WifiSecurityType.DynamicWep: return "WEP"
        case WifiSecurityType.Leap: return "LEAP"
        default: return ""
        }
    }

    function setEnabled(on: bool): void { Networking.wifiEnabled = on }
    function connect(network: var, psk: string): void {
        if (psk) network.connectWithPsk(psk)
        else network.connect()
    }
    function disconnect(network: var): void { network?.disconnect() }
}
