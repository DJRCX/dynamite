import QtQuick
import Quickshell
import qs.components
import qs.controlcenter
import qs.services
import qs.theme

SubPage {
    id: root
    title: "Display"
    // Niri's event stream has no output events, so poll while the page is open.
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: Displays.refresh() }

    Binding {
        target: GridLayoutModel
        property: "displayHeight"
        value: root.naturalHeight
    }

    Repeater {
        model: Displays.outputs
        Item {
            required property var modelData
            width: root.contentWidth
            height: card.height + 17
            MonitorCard { id: card; output: parent.modelData }
        }
    }

    Rectangle {
        width: root.contentWidth
        height: 85
        radius: Metrics.monitorCardRadius
        color: Theme.card
        Rectangle {
            id: moon
            x: 11; y: 13
            width: Metrics.rowIcon; height: Metrics.rowIcon; radius: width / 2
            color: Theme.accent
            Icon { anchors.centerIn: parent; name: "dark_mode"; size: Metrics.iconXs + 2; color: Theme.onAccent; filled: true }
        }
        Column {
            x: 53; y: 10
            Txt { px: 14; weight: Font.DemiBold; text: "Night Light" }
            Txt { px: 10.5; color: Theme.textSecondary; text: NightLight.temperature + " K" }
        }
        Switch {
            x: parent.width - width - 12
            y: moon.y + (moon.height - height) / 2
            checked: NightLight.enabled
            onToggled: on => NightLight.setEnabled(on)
        }
        // Fill grows toward warmer (lower) temperatures.
        Slider {
            x: 11; y: 51
            width: parent.width - 22
            height: 25
            icon: "dark_mode"
            value: (NightLight.maxTemp - NightLight.temperature) / (NightLight.maxTemp - NightLight.minTemp)
            onMoved: v => NightLight.setTemperature(NightLight.maxTemp - v * (NightLight.maxTemp - NightLight.minTemp))
        }
    }
}
