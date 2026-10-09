import QtQuick
import qs.components
import qs.theme

// Action pill (Connect / Disconnect / Pair): raised, sized to its label. `busy` swaps the label for a spinner.
Rectangle {
    id: root
    property string text
    property bool accentText: true
    property bool busy: false
    signal clicked()
    width: Math.max(Metrics.pillHeight + 14, label.implicitWidth + 22)
    height: Metrics.pillHeight
    radius: height / 2
    color: Theme.mix(Theme.raised, Theme.chip, area.containsMouse && !busy ? 1 : 0)
    Behavior on width { Spring { token: Motion.panel } }

    property real busyness: busy ? 1 : 0
    Behavior on busyness { Spring { token: Motion.panel; epsilon: 0.002 } }
    property real accentness: accentText ? 1 : 0
    Behavior on accentness { Spring { token: Motion.panel; epsilon: 0.002 } }

    Txt {
        id: label
        anchors.centerIn: parent
        px: 11.5; weight: Font.DemiBold
        color: Theme.mix(Theme.text, Theme.accent, root.accentness)
        text: root.text
        opacity: 1 - root.busyness
    }
    Spinner {
        anchors.centerIn: parent
        opacity: root.busyness
        visible: opacity > 0.01
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.busy
        onClicked: root.clicked()
    }
}
