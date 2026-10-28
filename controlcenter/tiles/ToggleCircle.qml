import QtQuick
import qs.components
import qs.controlcenter
import qs.state
import qs.theme

// 1×1 icon-only toggle. Lock is momentary.
Rectangle {
    id: root
    property string cid
    ControlState { id: state; cid: root.cid }
    radius: Math.min(width, height) / 2

    property real on: state.on ? 1 : 0
    readonly property bool expanded: width >= GridLayoutModel.span(2) || height >= GridLayoutModel.span(2)
    readonly property bool horizontalLayout: width >= GridLayoutModel.span(2)
    Behavior on on { Spring { token: Motion.panel; epsilon: 0.002 } }
    color: Theme.mix(Theme.mix(Theme.panel, Theme.raised, area.containsMouse ? 0.35 : 0), Theme.accent, on)

    Icon {
        x: root.horizontalLayout ? 12 : (root.width - width) / 2
        y: root.horizontalLayout ? (root.height - height) / 2
                                 : root.expanded ? Math.max(8, root.height / 2 - 40) : (root.height - height) / 2
        name: state.icon
        size: 17
        filled: root.on > 0.5
        color: Theme.mix(Theme.text, Theme.onAccent, root.on)
    }
    Txt {
        visible: root.expanded
        x: root.horizontalLayout ? 48 : 8
        y: root.horizontalLayout ? root.height / 2 - 17 : root.height / 2 - 12
        width: root.horizontalLayout ? root.width - 58 : root.width - 16
        horizontalAlignment: root.horizontalLayout ? Text.AlignLeft : Text.AlignHCenter
        px: 12.5; weight: Font.DemiBold
        text: state.title
    }
    Txt {
        visible: root.expanded
        x: root.horizontalLayout ? 48 : 8
        y: root.horizontalLayout ? root.height / 2 + 1 : root.height / 2 + 5
        width: root.horizontalLayout ? root.width - 58 : root.width - 16
        horizontalAlignment: root.horizontalLayout ? Text.AlignLeft : Text.AlignHCenter
        px: 10
        color: Theme.textSecondary
        text: state.subtitle
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: state.toggle()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: if (root.cid === "nightlight") Island.ccPage = "nightlight"
    }
}
