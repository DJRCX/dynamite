import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.components
import qs.services
import qs.state
import qs.theme

Item {
    id: root
    width: 410
    height: 213

    readonly property var player: Media.activePlayer
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property real length: player?.lengthSupported ? player.length : 0
    readonly property real position: player?.positionSupported ? player.position : 0
    property bool seeking: false
    property real seekFraction: 0
    readonly property real fraction: seeking ? seekFraction : length > 0 ? Math.min(1, position / length) : 0

    function clock(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const ss = String(s % 60).padStart(2, "0")
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    component ControlButton: Item {
        id: control
        property string icon
        property real iconSize: 13
        property bool round: false
        property bool enabledAction: true
        signal activated()
        width: round ? 42 : 30
        height: width
        opacity: enabledAction ? 1 : 0.35
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.ghostButton
            opacity: control.round ? 1 : hover.hovered ? 0.8 : 0
        }
        Icon { anchors.centerIn: parent; name: control.icon; size: control.iconSize; filled: true }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: control.enabledAction; onTapped: control.activated() }
    }

    ClippingRectangle {
        id: card
        x: 14
        y: 14
        width: 382
        height: 185
        radius: Metrics.cardRadius
        color: Theme.panel

        Image {
            id: blurSource
            x: -60
            y: -80
            width: 502
            height: 345
            source: root.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(256, 256)
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: blurSource
            source: blurSource
            visible: blurSource.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 0.1
            autoPaddingEnabled: false
        }
        Rectangle { anchors.fill: parent; color: Theme.mediaTint }
        Rectangle { anchors.fill: parent; color: Theme.mediaShade }

        ClippingRectangle {
            x: 15
            y: 14
            width: 120
            height: 120
            radius: 10
            color: Theme.card
            Image {
                id: albumArt
                anchors.fill: parent
                source: root.art
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(240, 240)
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: 40
                color: Theme.textMuted
                visible: albumArt.status !== Image.Ready
            }
        }

        Txt {
            x: 150; y: 18
            width: card.width - 164
            px: 17; weight: Font.DemiBold
            text: root.player?.trackTitle || "Nothing playing"
        }
        Txt {
            x: 150; y: 41
            width: card.width - 164
            px: 13; opacity: 0.72
            text: root.player?.trackArtist ?? ""
        }
        Txt {
            x: 150; y: 60
            width: card.width - 164
            px: 11.5; opacity: 0.38
            text: root.player?.trackAlbum ?? ""
        }
        Txt {
            x: 150; y: 76
            width: card.width - 164
            px: 11.5; opacity: 0.38
            text: root.player?.identity ?? ""
        }

        Item {
            id: progress
            x: 150; y: 100
            width: 218; height: 16
            Rectangle {
                y: 6
                width: parent.width; height: 4; radius: 2
                color: Theme.trackOnIsland
                Rectangle {
                    width: parent.width * root.fraction
                    height: parent.height; radius: 2
                    color: Theme.accent
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.player?.canSeek ?? false
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function update(mouseX: real): void { root.seekFraction = Math.max(0, Math.min(1, mouseX / width)) }
                onPressed: mouse => { root.seeking = true; update(mouse.x) }
                onPositionChanged: mouse => update(mouse.x)
                onReleased: {
                    if (root.length > 0) root.player.position = root.seekFraction * root.length
                    root.seeking = false
                }
                onCanceled: root.seeking = false
            }
        }
        Txt {
            x: 150; y: 115
            px: 10.5; weight: Font.Medium; opacity: 0.7
            text: root.clock(root.fraction * root.length)
        }
        Txt {
            x: 368 - width; y: 115
            px: 10.5; weight: Font.Medium; opacity: 0.5
            text: root.clock(root.length)
        }

        ControlButton {
            x: 229 - width / 2; y: 150 - height / 2
            icon: "skip_previous"; iconSize: 14
            enabledAction: root.player?.canGoPrevious ?? false
            onActivated: root.player.previous()
        }
        ControlButton {
            x: 281 - width / 2; y: 150 - height / 2
            round: true
            icon: root.player?.isPlaying ? "pause" : "play_arrow"; iconSize: 16
            enabledAction: root.player?.canTogglePlaying ?? false
            onActivated: root.player.togglePlaying()
        }
        ControlButton {
            x: 334 - width / 2; y: 150 - height / 2
            icon: "skip_next"; iconSize: 14
            enabledAction: root.player?.canGoNext ?? false
            onActivated: root.player.next()
        }
    }

    property real wheelAccum: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.wheelAccum += event.angleDelta.y
            if (Math.abs(root.wheelAccum) < 120) return
            Media.cycle(root.wheelAccum > 0 ? -1 : 1)
            root.wheelAccum = 0
        }
    }
}
