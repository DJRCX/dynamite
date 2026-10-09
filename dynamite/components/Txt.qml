import QtQuick
import qs.theme

// Text in the spec's units: `px` may be fractional (11.5, 10.5), `weight` is a Font.* weight.
Text {
    property real px: 13
    property int weight: Font.Normal
    color: Theme.text
    font.family: "Inter"
    font.weight: weight
    font.pointSize: Theme.pt(px)
    elide: Text.ElideRight
    maximumLineCount: 1
}
