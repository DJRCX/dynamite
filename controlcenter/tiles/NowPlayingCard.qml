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

    ClippingRectangle {
        x: 10; y: 10
        width: 72; height: 72
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
        x: 91; y: 11
        width: parent.width - 101
        px: 11.5; weight: Font.DemiBold
        text: root.player?.trackTitle || "Nothing playing"
        elide: Text.ElideRight
        maximumLineCount: 2
    }
    Txt {
        x: 91; y: 39
        width: parent.width - 101
        px: 9.5
        color: Theme.textSecondary
        text: root.player?.trackArtist ?? ""
        elide: Text.ElideRight
    }

    Row {
        x: 88; y: 76
        width: parent.width - 96
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
