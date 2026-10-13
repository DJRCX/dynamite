import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root
    width: Metrics.circle
    height: Metrics.circle
    readonly property real ring: Metrics.ringWidth
    readonly property real r: (width - 2 * Config.island.innerPadding) / 2 - ring / 2
    property real sweep: 360 * Battery.fraction
    Behavior on sweep { Spring { token: Motion.panel } }
    property real glowOpacity: 0
    Behavior on glowOpacity { Spring { token: Motion.fade; epsilon: 0.002 } }

    function syncChargingGlow(): void {
        if (Battery.charging && Battery.available) {
            glowOpacity = 0.48
            glowPulse.restart()
        } else {
            glowPulse.stop()
            glowOpacity = 0
        }
    }
    Component.onCompleted: syncChargingGlow()
    Connections {
        target: Battery
        function onChargingChanged() { root.syncChargingGlow() }
        function onAvailableChanged() { root.syncChargingGlow() }
    }
    Timer {
        id: glowPulse
        interval: 1800
        repeat: true
        running: false
        onTriggered: root.glowOpacity = root.glowOpacity > 0.3 ? 0.12 : 0.48
    }

    Shape {
        id: glowSource
        anchors.fill: parent
        visible: false
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.accent
            strokeWidth: Metrics.batteryGlowWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: -90 - root.sweep / 2; sweepAngle: root.sweep
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: glowSource
        visible: Battery.available && Battery.charging && root.glowOpacity > 0.01
        opacity: root.glowOpacity
        blurEnabled: true
        blur: 1
        blurMax: Metrics.batteryGlowBlur
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: Battery.available
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.batteryTrack
            strokeWidth: root.ring
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.ring
            capStyle: ShapePath.RoundCap
            strokeColor: Battery.charging ? Theme.accent : (Battery.fraction < 0.15 ? Theme.danger : Theme.text)
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: -90 - root.sweep / 2; sweepAngle: root.sweep
            }
        }
    }

    Icon { anchors.centerIn: parent; name: Network.wifiIcon; size: Metrics.iconXs }
}
