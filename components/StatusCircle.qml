import QtQuick
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
