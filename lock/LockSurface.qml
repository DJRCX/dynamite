import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

// One lock surface. Positions follow the 1920 × 1080 reference: the clock block hangs from the top edge,
// the avatar block from the bottom edge.
Item {
    id: root
    focus: true

    // 0 → 1 as the lock comes in, back to 0 while unlocking.
    property real appear: 0
    Behavior on appear { Spring { token: Motion.fade; epsilon: 0.002 } }
    Component.onCompleted: {
        appear = Qt.binding(() => Lock.unlocking ? 0 : 1)
        keyTarget.forceActiveFocus()
    }

    property real passwordness: Lock.stage === "password" ? 1 : 0
    Behavior on passwordness { Spring { token: Motion.fade; epsilon: 0.002 } }

    readonly property real bottomEdge: height

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.appear

        Image {
            id: wallpaper
            x: -Metrics.lockOverscan; y: -Metrics.lockOverscan
            width: parent.width + 2 * Metrics.lockOverscan
            height: parent.height + 2 * Metrics.lockOverscan
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(width, height)
            source: Config.appearance.wallpaper ? "file://" + Config.appearance.wallpaper : ""
            visible: false
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.window
            visible: wallpaper.status !== Image.Ready
        }
        MultiEffect {
            anchors.fill: wallpaper
            source: wallpaper
            visible: wallpaper.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Math.min(1, Config.lock.blur / 64)
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.lockDim
        }

        // Status, top-right.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 12
            height: 20
            spacing: 10
            Item {
                visible: Battery.available
                width: 28; height: 20
                Rectangle {
                    id: shell
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 12
                    radius: 3.5
                    color: "transparent"
                    border.width: 1.2
                    border.color: Theme.text
                    Rectangle {
                        x: 2; y: 2
                        height: parent.height - 4
                        width: (parent.width - 4) * Math.max(0.08, Battery.fraction)
                        radius: 2
                        color: Battery.fraction <= 0.15 && !Battery.charging ? Theme.danger : Theme.accent
                    }
                    Txt {
                        anchors.centerIn: parent
                        px: 7.5; weight: Font.Bold
                        color: Theme.onAccent
                        text: Math.round(Battery.fraction * 100)
                    }
                }
                Rectangle {
                    anchors.left: shell.right
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2; height: 5
                    radius: 1
                    color: Theme.text
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Network.wifiIcon
                size: Metrics.iconSm
                color: Theme.text
            }
        }

        // Date and time slide down 12 px as they appear.
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (Config.weather.onLockScreen ? 98 : 124) - Metrics.lockSlide * (1 - root.appear)
            px: 24; weight: Font.Medium
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 130 - Metrics.lockSlide * (1 - root.appear)
            visible: Config.weather.onLockScreen
            spacing: 5
            Icon { anchors.verticalCenter: parent.verticalCenter; name: Weather.icon(Weather.code, Weather.isDay); size: 16; color: Qt.alpha(Theme.text, 0.6) }
            Txt { px: 12; color: Qt.alpha(Theme.text, 0.6); text: Math.round(Weather.temperature) + "° · " + Weather.description(Weather.code) }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (Config.weather.onLockScreen ? 158 : 139) - Metrics.lockSlide * (1 - root.appear)
            px: 150; weight: Font.DemiBold
            text: Qt.formatTime(clock.date, Config.clock.use24h ? "H:mm" : "h:mm")
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bottomEdge - 245
            width: Metrics.lockAvatar; height: width
            radius: width / 2
            color: Theme.lockAvatar
            border.width: 1
            border.color: Theme.lockAvatarRing
            clip: true
            Image {
                id: face
                anchors.fill: parent
                source: Lock.hasFace ? "file://" + Lock.facePath : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width * 2, height * 2)
                visible: false
            }
            MultiEffect {
                anchors.fill: face
                source: face
                visible: face.status === Image.Ready
                maskEnabled: true
                maskSource: faceMask
            }
            Rectangle {
                id: faceMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            Icon {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                name: "person"
                filled: true
                size: Metrics.lockAvatarIcon
                color: Theme.text
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bottomEdge - 163
            px: 15; weight: Font.DemiBold
            text: Quickshell.env("USER") ?? ""
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bottomEdge - 114
            px: 12
            color: Theme.textSecondary
            text: "Press Any Key to Enter Password"
            opacity: 1 - root.passwordness
            visible: opacity > 0.01
        }

        Rectangle {
            id: pill
            property real shake: 0
            property bool shakeSprung: true
            Behavior on shake { enabled: pill.shakeSprung; Spring { token: Motion.island } }
            x: (parent.width - width) / 2 + shake
            y: root.bottomEdge - 122
            width: 197; height: 30
            radius: height / 2
            color: Theme.lockGlass
            opacity: root.passwordness
            visible: opacity > 0.01
            clip: true

            Row {
                id: dots
                x: Math.min(15, pill.width - 15 - width - caret.width - 2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: Lock.text.length
                    Rectangle {
                        id: dot
                        width: 10; height: 10
                        radius: 5
                        color: Theme.knob
                        property real shown: 0
                        Behavior on shown { Spring { token: Motion.fade; epsilon: 0.002 } }
                        Component.onCompleted: shown = 1
                        opacity: shown
                        scale: 0.6 + 0.4 * shown
                    }
                }
            }
            Rectangle {
                id: caret
                x: dots.x + dots.width + (Lock.text.length ? 3 : 0)
                anchors.verticalCenter: parent.verticalCenter
                width: 2; height: 16
                color: Theme.text
                visible: !Lock.checking
            }
            Spinner {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                visible: Lock.checking
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bottomEdge - 82
            px: 12
            color: Theme.danger
            text: Lock.error
            opacity: Lock.error !== "" ? 1 : 0
            Behavior on opacity { Spring { token: Motion.fade; epsilon: 0.002 } }
        }
    }

    Connections {
        target: Lock
        function onFailed() {
            pill.shakeSprung = false
            pill.shake = Metrics.shakeOffset
            pill.shakeSprung = true
            pill.shake = 0
        }
    }

    Item {
        id: keyTarget
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) Lock.submit()
            else if (event.key === Qt.Key_Backspace) Lock.backspace()
            else if (event.key === Qt.Key_Escape) { Lock.text = ""; Lock.activity() }
            else if (event.text && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) Lock.type(event.text)
            else Lock.activity()
            event.accepted = true
        }
    }
    MouseArea {
        anchors.fill: parent
        onPressed: {
            keyTarget.forceActiveFocus()
            Lock.activity()
        }
    }
}
