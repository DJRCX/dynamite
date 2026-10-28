import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

Rectangle {
    id: root
    radius: Metrics.cardRadius
    color: Theme.panel
    readonly property var player: Media.activePlayer
    readonly property string artwork: player?.trackArtUrl ?? ""
    readonly property int artworkSize: Math.max(52, Math.min(72, height - 20))

    ClippingRectangle {
        x: 10; y: 10
        width: root.artworkSize; height: root.artworkSize
        radius: 12
        color: Theme.card
        Image {
            id: art
            anchors.fill: parent
            source: root.artwork
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(144, 144)
            asynchronous: true
            visible: status === Image.Ready
        }
        Icon {
            anchors.centerIn: parent
            name: "music_note"
            size: Metrics.iconLg
            color: Theme.textMuted
            visible: !art.visible
        }
    }

    Txt {
        x: root.artworkSize + 19; y: 11
        width: parent.width - x - 10
        px: 11.5; weight: Font.DemiBold
        text: root.player?.trackTitle || "Nothing playing"
        elide: Text.ElideRight
        maximumLineCount: 2
    }
    Txt {
        x: root.artworkSize + 19; y: 39
        width: parent.width - x - 10
        px: 9.5
        color: Theme.textSecondary
        text: root.player?.trackArtist ?? ""
        elide: Text.ElideRight
    }

    Row {
        x: root.artworkSize + 16; y: parent.height - 44
        width: parent.width - x - 8
        height: 34
        spacing: 8
        Item {
            width: 30; height: 30
            opacity: root.player?.canGoPrevious ? 1 : 0.4
            Icon { anchors.centerIn: parent; name: "skip_previous"; size: Metrics.iconSm }
            MouseArea { anchors.fill: parent; enabled: root.player?.canGoPrevious ?? false; onClicked: root.player.previous() }
        }
        Item {
            width: 30; height: 30
            opacity: root.player?.canTogglePlaying ? 1 : 0.4
            Icon { anchors.centerIn: parent; name: root.player?.isPlaying ? "pause" : "play_arrow"; size: Metrics.iconMd; filled: true }
            MouseArea { anchors.fill: parent; enabled: root.player?.canTogglePlaying ?? false; onClicked: root.player.togglePlaying() }
        }
        Item {
            width: 30; height: 30
            opacity: root.player?.canGoNext ? 1 : 0.4
            Icon { anchors.centerIn: parent; name: "skip_next"; size: Metrics.iconSm }
            MouseArea { anchors.fill: parent; enabled: root.player?.canGoNext ?? false; onClicked: root.player.next() }
        }
    }
}
