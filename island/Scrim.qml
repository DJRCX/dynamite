import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.state

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    implicitWidth: screen.width
    implicitHeight: screen.height
    color: "transparent"
    // Let other windows receive pointer focus while the captured-window menu stays open.
    visible: Island.interactive && Island.mode !== "window"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    MouseArea {
        anchors.fill: parent
        onClicked: if (Island.mode !== "polkit") Island.close()
    }
}
