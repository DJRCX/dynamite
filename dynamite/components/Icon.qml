import QtQuick
import qs.theme

Text {
    property string name: ""
    property real size: Metrics.iconSm
    property bool filled: false
    text: name
    color: Theme.text
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 500, "opsz": 20 })
    renderType: Text.NativeRendering
}
