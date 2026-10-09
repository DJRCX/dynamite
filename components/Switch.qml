import QtQuick
import qs.theme

Item {
    id: root
    property bool checked: false
    signal toggled(bool checked)
    width: 40
    height: 22

    property real on: checked ? 1 : 0
    Behavior on on { Spring { token: Motion.panel; epsilon: 0.002 } }

    Rectangle {
        anchors.fill: parent
        radius: 11
        color: Theme.mix(Theme.switchOff, Theme.accent, root.on)
    }
    Rectangle {
        x: 3 + 18 * root.on
        y: 3
        width: 16
        height: 16
        radius: 8
        color: Theme.mix(Theme.textSecondary, Theme.onAccent, root.on)
    }
    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: root.toggled(!root.checked)
    }
}
