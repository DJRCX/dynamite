import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme

SubPage {
    id: root
    title: "Bluetooth"
    hasSwitch: Bluetooth.available
    switchOn: Bluetooth.enabled
    onSwitchToggled: on => Bluetooth.setEnabled(on)

    component BtRow: DeviceRow {
        id: row
        required property var modelData
        readonly property var device: modelData
        readonly property bool saved: device.paired || device.bonded
        icon: Bluetooth.iconFor(device)
        highlighted: device.connected
        title: device.name
        subtitle: Bluetooth.statusText(device)
        PillButton {
            text: !row.saved ? "Pair" : row.device.connected ? "Disconnect" : "Connect"
            accentText: !row.device.connected
            busy: Bluetooth.busy(row.device)
            onClicked: row.saved ? Bluetooth.toggleConnection(row.device) : Bluetooth.pairAndConnect(row.device)
        }
    }

    Txt {
        visible: !Bluetooth.enabled
        px: 10.5
        color: Theme.textSecondary
        text: Bluetooth.available ? "Bluetooth is off" : "No Bluetooth adapter found"
    }

    SectionLabel { visible: Bluetooth.enabled && Bluetooth.saved.length > 0; text: "Saved" }
    Item { width: 1; height: Metrics.sectionGap - 1; visible: Bluetooth.enabled && Bluetooth.saved.length > 0 }
    Column {
        width: root.contentWidth
        spacing: Metrics.rowGap
        visible: Bluetooth.enabled
        Repeater {
            model: ScriptModel { values: Bluetooth.saved }
            BtRow {}
        }
    }
    Item { width: 1; height: 13; visible: Bluetooth.enabled && Bluetooth.saved.length > 0 }

    SectionLabel { visible: Bluetooth.enabled; text: "Nearby"; scanning: Bluetooth.discovering }
    Item { width: 1; height: Metrics.sectionGap - 1; visible: Bluetooth.enabled }
    Column {
        width: root.contentWidth
        spacing: Metrics.rowGap
        visible: Bluetooth.enabled
        Repeater {
            model: ScriptModel { values: Bluetooth.nearby }
            BtRow {}
        }
    }
    Txt {
        visible: Bluetooth.enabled && Bluetooth.nearby.length === 0
        topPadding: 4
        px: 13
        color: Theme.textSecondary
        text: "Looking for devices…  put the device in pairing mode"
    }
}
