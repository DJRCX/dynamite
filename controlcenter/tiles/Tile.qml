import QtQuick
import qs.components
import qs.controlcenter
import qs.services
import qs.theme

// Wide tile (2–4 × 1): the icon circle toggles, the rest opens the sub-page (or toggles).
Rectangle {
    id: root
    property string cid
    ControlState { id: state; cid: root.cid }
    radius: height / 2
    color: Theme.mix(Theme.panel, Theme.raised, body.containsMouse ? 0.35 : 0)

    property real on: state.on ? 1 : 0
    Behavior on on { Spring { token: Motion.panel; epsilon: 0.002 } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: state.activate()
    }
    Rectangle {
        x: 8
        y: (root.height - height) / 2
        width: 42
        height: 42
        radius: 21
        color: Theme.mix(Theme.mix(Theme.raised, Theme.chip, iconArea.containsMouse ? 1 : 0), Theme.accent, root.on)
        Icon {
            anchors.centerIn: parent
            name: state.icon
            size: 15
            color: Theme.mix(Theme.text, Theme.onAccent, root.on)
        }
        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: state.toggle()
        }
    }
    Txt {
        x: 60; y: 15
        width: root.width - 72
        px: 14; weight: Font.DemiBold
        text: state.title
    }
    Txt {
        x: 60; y: 33
        width: root.width - 72
        px: 10.5
        color: Theme.textSecondary
        text: state.subtitle
    }
    MouseArea {
        visible: root.cid === "caffeine"
        x: 60; y: 31; width: root.width - 72; height: 20
        cursorShape: Qt.PointingHandCursor
        onClicked: Idle.cycleDuration()
    }
}
