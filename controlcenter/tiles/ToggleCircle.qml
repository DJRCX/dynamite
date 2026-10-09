import QtQuick
import qs.components
import qs.controlcenter
import qs.theme

// 1×1 icon-only toggle. Lock is momentary.
Rectangle {
    id: root
    property string cid
    ControlState { id: state; cid: root.cid }
    radius: Math.min(width, height) / 2

    property real on: state.on ? 1 : 0
    Behavior on on { Spring { token: Motion.panel; epsilon: 0.002 } }
    color: Theme.mix(Theme.mix(Theme.panel, Theme.raised, area.containsMouse ? 0.35 : 0), Theme.accent, on)

    Icon {
        anchors.centerIn: parent
        name: state.icon
        size: 17
        filled: root.on > 0.5
        color: Theme.mix(Theme.text, Theme.onAccent, root.on)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: state.toggle()
    }
}
