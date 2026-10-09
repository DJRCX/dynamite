import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.state

// Live state for one CC control id: icon, title, subtitle, on, and what clicking does.
QtObject {
    id: root
    property string cid

    readonly property string icon: {
        switch (cid) {
        case "wifi": return Network.wifiIcon
        case "bluetooth": return Bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
        case "focus": return "do_not_disturb_on"
        case "gamemode": return "sports_esports"
        case "nightlight": return "dark_mode"
        case "lock": return "lock"
        case "power": return PowerProfile.current === "performance" ? "bolt" : PowerProfile.current === "power-saver" ? "eco" : "balance"
        case "caffeine": return "coffee"
        case "system": return "memory"
        default: return "help"
        }
    }
    readonly property string title: {
        switch (cid) {
        case "wifi": return "Wi-Fi"
        case "bluetooth": return "Bluetooth"
        case "focus": return "Focus"
        case "gamemode": return "Game Mode"
        case "nightlight": return "Night Light"
        case "lock": return "Lock"
        case "power": return "Power"
        case "caffeine": return "Caffeine"
        case "system": return "System"
        default: return cid
        }
    }
    readonly property bool on: {
        switch (cid) {
        case "wifi": return Network.wifiEnabled
        case "bluetooth": return Bluetooth.enabled
        case "focus": return Notifs.dnd
        case "gamemode": return Island.gameMode
        case "caffeine": return Idle.caffeine
        case "nightlight": return NightLight.enabled
        default: return false
        }
    }
    readonly property string subtitle: {
        switch (cid) {
        case "wifi": return !Network.wifiEnabled ? "Off" : Network.active ? Network.active.name : "Not connected"
        case "bluetooth":
            if (!Bluetooth.available) return "Unavailable"
            if (!Bluetooth.enabled) return "Off"
            return Bluetooth.connected.length ? Bluetooth.connected[0].name : "On"
        case "nightlight": return NightLight.enabled ? NightLight.temperature + " K" : "Off"
        case "lock": return "Lock screen"
        case "power": return PowerProfile.current + (Config.power.auto ? " · Auto" : "")
        case "caffeine": return Idle.caffeine ? Idle.subtitle : "Off"
        default: return on ? "On" : "Off"
        }
    }
    // Sub-page opened by clicking the body of a wide tile ("" = the body toggles too).
    readonly property string page: cid === "wifi" ? "wifi" : cid === "bluetooth" ? "bluetooth" : cid === "power" ? "battery" : cid === "system" ? "system" : ""

    function toggle(): void {
        switch (cid) {
        case "wifi": Network.setEnabled(!Network.wifiEnabled); break
        case "bluetooth": Bluetooth.setEnabled(!Bluetooth.enabled); break
        case "focus": Notifs.setDnd(!Notifs.dnd); break
        case "gamemode": Island.setGameMode(!Island.gameMode); break
        case "nightlight": NightLight.setEnabled(!NightLight.enabled); break
        case "lock": Island.close(); Lock.lock(); break
        case "power": PowerProfile.set(PowerProfile.current === "performance" ? "balanced" : PowerProfile.current === "balanced" ? "power-saver" : "performance"); break
        case "caffeine": Idle.toggle(); break
        }
    }
    function activate(): void {
        if (page !== "") Island.ccPage = page
        else toggle()
    }
}
