import QtQuick
import qs.theme

// Single-line text that crossfades (panel spring) whenever its string changes.
Item {
    id: root
    property string text
    property real px: 13
    property int weight: Font.Normal
    property color color: Theme.text
    implicitWidth: Math.max(a.implicitWidth, b.implicitWidth)
    implicitHeight: a.implicitHeight

    property string textA
    property string textB
    property bool showA: true
    property real fadeA: showA ? 1 : 0
    Behavior on fadeA { Spring { token: Motion.panel; epsilon: 0.002 } }

    Component.onCompleted: textA = text
    onTextChanged: {
        if (showA) {
            if (text === textA) return
            textB = text
            showA = false
        } else {
            if (text === textB) return
            textA = text
            showA = true
        }
    }

    Txt {
        id: a
        width: root.width
        px: root.px; weight: root.weight; color: root.color
        text: root.textA
        opacity: root.fadeA
    }
    Txt {
        id: b
        width: root.width
        px: root.px; weight: root.weight; color: root.color
        text: root.textB
        opacity: 1 - root.fadeA
    }
}
