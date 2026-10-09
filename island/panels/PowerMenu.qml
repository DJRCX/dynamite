import QtQuick
import qs.components
import qs.services
import qs.state
import qs.theme

// 514 × 110: five actions. Log Out, Reboot and Power Off need a second press within 3 s.
Item {
    id: root
    width: 514
    height: 110
    focus: true

    readonly property var actions: [
        { label: "Lock", icon: "lock", confirm: false },
        { label: "Suspend", icon: "bedtime", confirm: false },
        { label: "Log Out", icon: "logout", confirm: true },
        { label: "Reboot", icon: "restart_alt", confirm: true },
        { label: "Power Off", icon: "power_settings_new", confirm: true }
    ]
    property int current: 0
    property int armed: -1

    function reset(): void {
        current = 0
        armed = -1
        forceActiveFocus()
    }
    Component.onCompleted: reset()
    Connections {
        target: Island
        function onModeChanged() { if (Island.mode === "power") root.reset() }
    }

    function activate(index: int): void {
        current = index
        if (actions[index].confirm && armed !== index) {
            armed = index
            disarm.restart()
            return
        }
        armed = -1
        Island.close()
        switch (index) {
        case 0: Power.lock(); break
        case 1: Power.suspend(); break
        case 2: Power.logout(); break
        case 3: Power.reboot(); break
        case 4: Power.poweroff(); break
        }
    }
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = -1 }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) Island.close()
        else if (event.key === Qt.Key_Left) { current = (current + 4) % 5; armed = -1 }
        else if (event.key === Qt.Key_Right) { current = (current + 1) % 5; armed = -1 }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activate(current)
        else return
        event.accepted = true
    }

    Repeater {
        model: root.actions
        Rectangle {
            id: tile
            required property var modelData
            required property int index
            property real lit: root.current === index ? 1 : 0
            Behavior on lit { Spring { token: Motion.panel; epsilon: 0.002 } }
            x: [14, 113, 212, 312, 411][index]
            y: 15
            width: 89; height: 82
            radius: Metrics.monitorCardRadius
            color: Theme.mix(Theme.panel, Theme.accent, lit)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20
                name: tile.modelData.icon
                size: Metrics.iconLg
                color: Theme.mix(Theme.text, Theme.onAccent, tile.lit)
            }
            FadeText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 46
                width: implicitWidth
                px: 11.5; weight: Font.DemiBold
                color: Theme.mix(Theme.text, Theme.onAccent, tile.lit)
                text: root.armed === tile.index ? "Confirm?" : tile.modelData.label
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (root.current !== tile.index) { root.current = tile.index; root.armed = -1 }
                onClicked: root.activate(tile.index)
            }
        }
    }
}
