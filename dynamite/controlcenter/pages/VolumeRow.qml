import QtQuick
import qs.components
import qs.services
import qs.theme

// A 25 px volume slider with its percentage on the right (Sound page output/input/app rows).
Item {
    id: root
    property real value: 0
    property string icon: "volume_up"
    property real sliderWidth: 399
    signal moved(real value)
    width: Metrics.pageContentWidth
    height: 25

    Slider {
        id: slider
        width: root.sliderWidth
        height: parent.height
        value: root.value
        icon: root.icon
        onMoved: v => { Audio.touch(); root.moved(v) }
    }
    Txt {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        px: 10.5; weight: Font.Medium
        color: Theme.textSecondary
        text: Math.round(root.value * 100) + "%"
    }
}
