import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import qs.services
import qs.theme

PanelWindow {
    id: root
    visible: Niri.inOverview && sourceImage.status === Image.Ready
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.window
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "dynamite-overview-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string wallpaperPath: Wallpaper.current[screen.name] || Wallpaper.current["*"] || ""
    Image {
        id: sourceImage
        anchors.fill: parent
        source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: sourceImage
        blurEnabled: true
        blur: 1
        blurMax: 48
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.window, 0.38) }
}
