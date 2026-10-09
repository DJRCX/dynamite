pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property real fraction: {
        if (!available || !device) return 1
        const percentage = Number(device.percentage)
        return Math.max(0, Math.min(1, percentage > 1 ? percentage / 100 : percentage))
    }
    readonly property int percentage: Math.round(fraction * 100)
    readonly property bool charging: device && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged)
    readonly property real timeLeft: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)
}
