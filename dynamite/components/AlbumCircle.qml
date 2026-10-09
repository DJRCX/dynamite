import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

ClippingRectangle {
    id: root
    width: Metrics.circle
    height: Metrics.circle
    radius: width / 2
    color: Theme.panel

    Image {
        id: albumImage
        anchors.fill: parent
        source: Media.activePlayer?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }
    Icon { anchors.centerIn: parent; name: "music_note"; size: Metrics.iconMd; visible: !Media.activePlayer || albumImage.status !== Image.Ready }
}
