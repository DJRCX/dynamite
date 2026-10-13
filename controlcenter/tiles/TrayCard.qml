import QtQuick
import Quickshell.Services.SystemTray
import qs.components
import qs.theme

Rectangle {
    id: root
    radius: 20
    color: Theme.panel

    Txt {
        x: 14; y: 7
        px: 10.5
        color: Theme.textSecondary
        text: "Background apps"
    }
    Txt {
        x: 14; y: 30
        px: 10.5
        color: Theme.textMuted
        text: "No tray apps"
        visible: SystemTray.items.count === 0
    }

    ListView {
        id: trayList
        x: 12; y: 27
        width: root.width - 24
        height: 28
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        model: SystemTray.items
        delegate: Rectangle {
            id: trayButton
            required property var modelData
            width: 28; height: 28
            radius: 8
            color: hover.hovered ? Theme.card : "transparent"
            Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
            Accessible.role: Accessible.Button

            Image {
                id: trayIcon
                anchors.centerIn: parent
                width: 20; height: 20
                source: trayButton.modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                name: "apps"
                size: Metrics.iconMd
                color: Theme.textSecondary
                visible: trayIcon.status !== Image.Ready
            }
            HoverHandler { id: hover }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: trayButton.modelData.activate()
            }
        }
    }
}
