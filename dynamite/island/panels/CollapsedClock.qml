import QtQuick
import Quickshell
import qs.config
import qs.theme

Text {
    id: root
    anchors.centerIn: parent
    color: Theme.text
    font.family: Theme.fonts.collapsedClock.family
    font.weight: Theme.fonts.collapsedClock.weight
    font.pixelSize: Theme.fonts.collapsedClock.pixelSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    SystemClock { id: clock; precision: SystemClock.Minutes }
    text: Qt.formatTime(clock.date, Config.clock.use24h ? "HH:mm" : "h:mm")
}
