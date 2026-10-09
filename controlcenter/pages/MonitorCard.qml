import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme

// One Niri output: header, brightness (through the smooth ramp), scale chips, and an expandable mode list.
Rectangle {
    id: root
    required property var output
    readonly property bool focused: output.name === Niri.focusedOutput
    readonly property var channel: Brightness.channelFor(output.name)
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    property bool listOpen: false

    readonly property var modes: {
        const seen = {}
        const list = []
        for (const mode of output.modes) {
            const key = mode.width + "x" + mode.height + "@" + Math.round(mode.refresh / 1000)
            if (seen[key]) continue
            seen[key] = true
            list.push(mode)
        }
        return list.sort((a, b) => b.width * b.height - a.width * a.height || b.refresh - a.refresh)
    }
    readonly property real listHeight: Math.min(5, modes.length) * 28 + 8

    width: Metrics.pageContentWidth
    height: 160 + (listOpen ? listHeight : 0)
    Behavior on height { Spring { token: Motion.panel } }
    radius: Metrics.monitorCardRadius
    color: Theme.card
    clip: true

    Rectangle {
        id: badge
        x: 11; y: 12
        width: Metrics.rowIcon; height: Metrics.rowIcon; radius: width / 2
        color: Theme.mix(Theme.chip, Theme.accent, root.focused ? 1 : 0)
        Icon {
            anchors.centerIn: parent
            name: "desktop_windows"
            size: Metrics.iconXs + 2
            color: root.focused ? Theme.onAccent : Theme.text
        }
    }
    Column {
        x: 53; y: 9
        width: focusedLabel.x - x - 8
        Txt { width: parent.width; px: 14; weight: Font.DemiBold; text: root.output.name }
        Txt { width: parent.width; px: 10.5; color: Theme.textSecondary; text: Displays.summary(root.output) }
    }
    Txt {
        id: focusedLabel
        x: root.width - width - 12
        y: badge.y + (badge.height - height) / 2
        visible: root.focused
        px: 11; weight: Font.Medium
        color: Theme.accent
        text: "focused"
    }

    Slider {
        x: 11; y: 53
        width: 378; height: 25
        visible: root.channel !== null
        value: (root.channel?.target ?? 0) / 100
        icon: "light_mode"
        onMoved: v => Brightness.set(root.output.name, v * 100)
    }
    Txt {
        x: root.width - width - 11
        y: 53 + (25 - height) / 2
        px: 10.5; weight: Font.Medium
        color: Theme.textSecondary
        text: root.channel ? Math.round(root.channel.target) + "%" : "Brightness not adjustable"
    }

    Row {
        x: 11; y: 88
        spacing: 5
        Repeater {
            model: root.scales
            Rectangle {
                id: chip
                required property real modelData
                readonly property bool active: Math.abs(root.output.scale - modelData) < 0.01
                property real lit: active ? 1 : 0
                Behavior on lit { Spring { token: Motion.panel; epsilon: 0.002 } }
                width: chipLabel.implicitWidth + 22
                height: 26
                radius: 13
                color: Theme.mix(Theme.mix(Theme.chip, Theme.raised, chipArea.containsMouse ? 1 : 0), Theme.accent, lit)
                Txt {
                    id: chipLabel
                    anchors.centerIn: parent
                    px: 11; weight: Font.Medium
                    color: Theme.mix(Theme.text, Theme.onAccent, chip.lit)
                    text: Displays.scaleLabel(chip.modelData)
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!chip.active) Displays.setScale(root.output.name, chip.modelData)
                }
            }
        }
    }

    Item {
        x: 0; y: 122
        width: root.width; height: 30
        Txt {
            x: 19
            anchors.verticalCenter: parent.verticalCenter
            px: 11
            color: Theme.textMuted
            text: "Resolution"
        }
        Txt {
            anchors.right: chevron.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            px: 11.5; weight: Font.DemiBold
            text: Displays.modeLabel(root.output.modes[root.output.current])
        }
        Icon {
            id: chevron
            x: root.width - width - 12
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Metrics.iconXs
            color: Theme.textMuted
            rotation: root.listOpen ? 90 : 0
            Behavior on rotation { Spring { token: Motion.panel } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.listOpen = !root.listOpen
        }
    }

    Flickable {
        x: 11; y: 158
        width: root.width - 22
        height: root.listHeight - 8
        contentHeight: modeColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: root.listOpen ? 1 : 0
        Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
        Column {
            id: modeColumn
            width: parent.width
            Repeater {
                model: root.modes
                Rectangle {
                    id: modeRow
                    required property var modelData
                    readonly property bool current: modelData.index === root.output.current
                    width: modeColumn.width
                    height: 28
                    radius: 10
                    color: modeArea.containsMouse ? Theme.raised : "transparent"
                    Txt {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        px: 11.5; weight: Font.Medium
                        color: modeRow.current ? Theme.accent : Theme.text
                        text: Displays.modeLabel(modeRow.modelData)
                    }
                    Icon {
                        x: parent.width - width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modeRow.current
                        name: "check"
                        size: Metrics.iconSm
                        color: Theme.accent
                    }
                    MouseArea {
                        id: modeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!modeRow.current) Displays.setMode(root.output.name, modeRow.modelData)
                            root.listOpen = false
                        }
                    }
                }
            }
        }
    }
}
