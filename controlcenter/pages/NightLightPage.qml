import QtQuick
import Quickshell.Widgets
import qs.components
import qs.controlcenter.pages
import qs.services
import qs.state
import qs.theme

SubPage {
    id: root
    title: "Night Light"
    hasSwitch: true
    switchOn: NightLight.enabled
    onSwitchToggled: on => NightLight.setEnabled(on)

    Rectangle {
        width: root.contentWidth
        height: 148
        radius: Metrics.monitorCardRadius
        color: Theme.card

        ClippingRectangle {
            x: 13; y: 13
            width: 30; height: 30
            radius: width / 2
            color: Theme.accent
            Icon { anchors.centerIn: parent; name: "dark_mode"; size: Metrics.iconSm; color: Theme.onAccent }
        }
        Column {
            x: 54; y: 11; spacing: 2
            Txt { px: 14; weight: Font.DemiBold; text: "Night Light intensity" }
            Txt { px: 10.5; color: Theme.textSecondary; text: "Adjust how warm the screen appears" }
        }
        Txt {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 47
            px: 11; weight: Font.Medium
            color: Theme.textSecondary
            text: NightLight.temperature + " K"
        }
        Slider {
            x: 12; y: 78
            width: parent.width - 24
            height: 25
            icon: "dark_mode"
            value: (NightLight.maxTemp - NightLight.temperature) / (NightLight.maxTemp - NightLight.minTemp)
            onMoved: value => NightLight.setTemperature(NightLight.maxTemp - value * (NightLight.maxTemp - NightLight.minTemp))
        }
        Row {
            x: 12; y: 112
            width: parent.width - 24
            spacing: 0
            Txt { px: 9.5; color: Theme.textMuted; text: "Cool" }
            Item { width: parent.width - 52; height: 1 }
            Txt { px: 9.5; color: Theme.textMuted; text: "Warm" }
        }
    }
}
