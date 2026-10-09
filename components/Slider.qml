import QtQuick
import qs.theme

// A pill slider. `value` is 0–1; `moved(v)` fires while dragging and on wheel steps.
Item {
    id: root
    property real value: 0
    property bool vertical: false
    property string icon: ""
    property color trackColor: Theme.track
    property color fillColor: Theme.accent
    property real step: 0.05
    readonly property bool dragging: drag.pressed
    signal moved(real value)
    signal released()

    readonly property real thickness: vertical ? width : height
    readonly property real length: vertical ? height : width
    property real shown: dragging ? drag.dragValue : value
    Behavior on shown { enabled: !root.dragging; Spring { token: Motion.panel; epsilon: 0.001 } }
    readonly property real fillLength: thickness + Math.max(0, Math.min(1, shown)) * (length - thickness)

    Rectangle {
        anchors.fill: parent
        radius: root.thickness / 2
        color: root.trackColor
    }
    Rectangle {
        x: 0
        y: root.vertical ? root.height - height : 0
        width: root.vertical ? root.width : root.fillLength
        height: root.vertical ? root.fillLength : root.height
        radius: root.thickness / 2
        color: root.fillColor

        Icon {
            visible: root.icon !== ""
            name: root.icon
            size: Math.min(13, root.thickness * 0.6)
            color: Theme.onAccent
            filled: true
            x: root.vertical ? (parent.width - width) / 2 : root.thickness / 2 - width / 2 + 2
            y: root.vertical ? parent.height - root.thickness / 2 - height / 2 : (parent.height - height) / 2
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        property real dragValue: 0
        function valueAt(mx: real, my: real): real {
            const pos = root.vertical ? root.height - my : mx
            return Math.max(0, Math.min(1, (pos - root.thickness / 2) / (root.length - root.thickness)))
        }
        onPressed: mouse => { dragValue = valueAt(mouse.x, mouse.y); root.moved(dragValue) }
        onPositionChanged: mouse => { if (pressed) { dragValue = valueAt(mouse.x, mouse.y); root.moved(dragValue) } }
        onReleased: root.released()
        onWheel: wheel => {
            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
            if (delta === 0) return
            root.moved(Math.max(0, Math.min(1, root.value + (delta > 0 ? root.step : -root.step))))
        }
    }
}
