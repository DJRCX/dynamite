pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    // Use the physical laptop battery instead of UPower's aggregate DisplayDevice.
    // Its percentage is always 0–100; energy/capacity avoids treating a small
    // percentage value as a fractional 0–1 value.
    readonly property var device: UPower.devices.values.find(item => item.isLaptopBattery) ?? null
    readonly property bool available: (device?.isLaptopBattery ?? false) && (device?.ready ?? false)
    readonly property real fraction: {
        if (!available || !device || !device.ready) return 1
        const energy = Number(device.energy)
        const capacity = Number(device.energyCapacity)
        const percentage = Number(device.percentage)
        const value = capacity > 0 && energy >= 0 ? energy / capacity : percentage / 100
        return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 1
    }
    readonly property int percentage: Math.round(fraction * 100)
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: device && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged)
    readonly property real timeLeft: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)
}
