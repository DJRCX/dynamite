import QtQuick
import qs.theme

// Panel content at its final size, centered at the top of the island; the island's clip reveals it.
Item {
    id: root
    property bool shown: false
    property Component content
    property alias item: loader.item
    // Which island edge the content is pinned to while the island grows: -1 left, 0 center, 1 right.
    property int edge: 0
    x: edge < 0 ? 0 : edge > 0 ? parent.width - width : Math.round((parent.width - width) / 2)
    y: 0
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96
    transformOrigin: Item.Top
    visible: opacity > 0.01
    Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
    Behavior on scale { Spring { token: Motion.panel; epsilon: 0.001 } }

    Loader {
        id: loader
        anchors.fill: parent
        active: root.shown || root.visible
        sourceComponent: root.content
    }
}
