import QtQuick
import qs.components
import qs.state
import qs.theme

// 280 × 44 pill: icon, level track, percentage.
Item {
    id: root
    readonly property bool brightness: Overlays.osdKind === "brightness"
    readonly property real value: Math.max(0, Math.min(1, Overlays.osdValue))

    Icon {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        name: root.brightness ? "light_mode" : Overlays.osdMuted ? "volume_off" : "volume_up"
        size: Metrics.iconSm
        color: Theme.text
    }
    Rectangle {
        id: track
        x: 41; y: 20
        width: 181; height: 5
        radius: height / 2
        color: Theme.trackOnIsland
        Rectangle {
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            opacity: Overlays.osdMuted ? 0.35 : 1
            width: track.width * (Overlays.osdMuted ? 0 : root.value)
            Behavior on width { Spring { token: Motion.panel } }
        }
    }
    Txt {
        x: 224
        width: 40
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        px: 10.5; weight: Font.Medium
        color: Theme.textSecondary
        text: Overlays.osdMuted ? "Muted" : Math.round(root.value * 100) + "%"
    }
}
