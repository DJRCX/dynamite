import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

Rectangle {
    id: root
    radius: 20
    color: Theme.panel

    Txt {
        x: 14; y: 12
        px: 10.5
        color: Theme.textSecondary
        text: "Notifications"
    }
    Txt {
        id: clearAll
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 12
        px: 10.5; weight: Font.Medium
        color: clearArea.containsMouse ? Theme.text : Theme.textSecondary
        text: "Clear all"
        visible: Notifs.list.length > 0
        MouseArea {
            id: clearArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.clear()
        }
    }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36 + (root.height - 36) / 2 - height / 2 - 6
        px: 10.5
        color: Theme.textMuted
        text: Notifs.dnd ? "Focus is on — notifications are silenced" : "No notifications"
        visible: Notifs.list.length === 0
    }

    ListView {
        id: list
        x: 9; y: 36
        width: root.width - 18
        height: root.height - 36 - 9
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: Notifs.list }
        delegate: Item {
            id: row
            required property var modelData
            width: list.width
            height: 68

            property real enter: 0
            Component.onCompleted: enter = 1
            Behavior on enter { Spring { token: Motion.panel; epsilon: 0.002 } }
            opacity: enter * (1 - Math.min(1, Math.max(0, card.x) / 200))

            Rectangle {
                id: card
                y: (1 - row.enter) * -14
                width: parent.width
                height: parent.height
                radius: 14
                color: Theme.card
                Behavior on x { enabled: !swipe.active; Spring { token: Motion.panel } }

                DragHandler {
                    id: swipe
                    xAxis.enabled: true
                    yAxis.enabled: false
                    xAxis.minimum: 0
                    onActiveChanged: {
                        if (active) return
                        if (card.x > 120) Notifs.dismiss(row.modelData)
                        else card.x = 0
                    }
                }
                HoverHandler { id: hover }

                ClippingRectangle {
                    x: 12; y: 16
                    width: 36; height: 36; radius: 18
                    color: Theme.subpage
                    IconImage {
                        id: appIcon
                        anchors.centerIn: parent
                        implicitSize: 22
                        source: row.modelData.image || (row.modelData.appIcon ? Quickshell.iconPath(row.modelData.appIcon, true) : "")
                        visible: source != "" && status === Image.Ready
                    }
                    Txt {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        px: 13; weight: Font.Bold
                        color: Theme.accent
                        text: (row.modelData.appName || "?").charAt(0).toUpperCase()
                    }
                }
                Txt {
                    x: 60; y: 9
                    width: card.width - 96
                    px: 10.5
                    color: Theme.textSecondary
                    text: row.modelData.appName
                }
                Txt {
                    x: 60; y: 24
                    width: card.width - 96
                    px: 13; weight: Font.Bold
                    text: row.modelData.summary
                }
                Txt {
                    x: 60; y: 42
                    width: card.width - 80
                    px: 10.5
                    color: Theme.textSecondary
                    text: row.modelData.body
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
                Rectangle {
                    x: card.width - 30; y: 8
                    width: 22; height: 22; radius: 11
                    color: closeArea.containsMouse ? Theme.chip : "transparent"
                    opacity: hover.hovered ? 1 : 0.55
                    Icon { anchors.centerIn: parent; name: "close"; size: 13; color: Theme.textSecondary }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismiss(row.modelData)
                    }
                }
            }
        }
    }
}
