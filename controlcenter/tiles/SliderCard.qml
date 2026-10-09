import QtQuick
import qs.components
import qs.controlcenter
import qs.services
import qs.state
import qs.theme

// Sound / Display card: wide (label + "more" + slider) or vertical 1×n (slider only).
Rectangle {
    id: root
    property string cid
    readonly property bool vertical: height > width
    readonly property bool showLabel: !vertical && width >= GridLayoutModel.span(4)
    readonly property bool isSound: cid === "sound"
    readonly property bool available: isSound ? Audio.sink !== null : Brightness.focused !== null
    radius: 20
    color: Theme.panel

    readonly property real value: isSound ? (Audio.muted ? 0 : Audio.volume) : Brightness.focusedValue / 100
    function apply(v: real): void {
        if (isSound) Audio.setVolume(v)
        else Brightness.set(Niri.focusedOutput, v * 100)
    }

    Txt {
        visible: root.showLabel
        x: 14; y: 7
        px: 13; weight: Font.DemiBold
        text: root.isSound ? "Sound" : "Display"
    }
    Rectangle {
        visible: !root.vertical
        x: root.width - 37; y: 4
        width: 22; height: 22; radius: 11
        color: Theme.mix(Theme.card, Theme.chip, more.containsMouse ? 1 : 0)
        Icon { anchors.centerIn: parent; name: "chevron_right"; size: 11; color: Theme.textSecondary }
        MouseArea {
            id: more
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Island.ccPage = root.isSound ? "sound" : "display"
        }
    }
    Slider {
        x: 9
        y: root.vertical ? 9 : 29
        width: root.width - 18
        height: root.vertical ? root.height - 18 : 22
        vertical: root.vertical
        enabled: root.available
        opacity: root.available ? 1 : 0.4
        value: root.value
        icon: root.isSound ? Audio.volumeIcon : "light_mode"
        onMoved: v => { if (root.isSound) Audio.touch(); root.apply(v) }
    }
}
