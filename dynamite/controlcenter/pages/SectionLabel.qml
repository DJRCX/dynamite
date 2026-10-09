import QtQuick
import qs.components
import qs.theme

// "Saved" / "Nearby" / "Output" label, with an optional pulsing "Scanning" indicator on the right.
Item {
    id: root
    property string text
    property bool scanning: false
    width: Metrics.pageContentWidth
    height: 12

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        px: 10.5
        color: Theme.textMuted
        text: root.text
    }
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        opacity: root.scanning ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
        Rectangle {
            id: dot
            property real phase: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 5; height: 5; radius: 2.5
            color: Theme.accent
            opacity: 0.625 + 0.375 * Math.cos(phase)
            NumberAnimation on phase {
                running: root.scanning
                loops: Animation.Infinite
                from: 0; to: 2 * Math.PI
                duration: 1300
            }
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            px: 10.5; weight: Font.Medium
            color: Theme.textSecondary
            text: "Scanning"
        }
    }
}
