import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme

SubPage {
    id: root
    title: "Wi-Fi"
    hasSwitch: true
    switchOn: Network.wifiEnabled
    onSwitchToggled: on => Network.setEnabled(on)

    // Connected network card.
    Item {
        width: root.contentWidth
        height: Network.active ? 65 + Metrics.sectionGap : 0
        visible: Network.active !== null
        Rectangle {
            width: parent.width
            height: 65
            radius: Metrics.rowRadius
            color: Theme.card
            Rectangle {
                id: badge
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38; radius: 19
                color: Theme.accent
                Icon {
                    anchors.centerIn: parent
                    name: Network.active ? Network.strengthIcon(Network.active.signalStrength) : "wifi"
                    size: Metrics.iconSm
                    color: Theme.onAccent
                }
            }
            Column {
                x: badge.x + badge.width + 14
                anchors.verticalCenter: parent.verticalCenter
                width: disconnect.x - x - 10
                spacing: 2
                Txt { width: parent.width; px: 14; weight: Font.DemiBold; text: Network.active?.name ?? "" }
                Txt {
                    width: parent.width
                    px: 10.5
                    color: Theme.textSecondary
                    text: Network.active ? ["Connected", Network.securityLabel(Network.active),
                                            Math.round(Network.active.signalStrength * 100) + "% signal"]
                                           .filter(s => s !== "").join("  ·  ") : ""
                }
            }
            PillButton {
                id: disconnect
                x: parent.width - width - 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Disconnect"
                accentText: false
                busy: Network.active?.stateChanging ?? false
                onClicked: Network.disconnect(Network.active)
            }
        }
    }

    SectionLabel {
        visible: Network.wifiEnabled
        text: "Networks"
        scanning: Network.scannerOn
    }
    Item { width: 1; height: Metrics.sectionGap; visible: Network.wifiEnabled }

    Column {
        width: root.contentWidth
        spacing: Metrics.rowGap
        visible: Network.wifiEnabled
        Repeater {
            model: ScriptModel { values: Network.others }
            NetworkRow {}
        }
    }

    Txt {
        visible: !Network.wifiEnabled
        px: 10.5
        color: Theme.textSecondary
        text: "Wi-Fi is off"
    }
}
