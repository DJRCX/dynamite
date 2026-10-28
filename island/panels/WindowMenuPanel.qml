import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services as Services
import qs.state
import qs.theme

Item {
    id: root
    height: parent.height

    readonly property var actions: Services.WindowMenu.desktopActions.map((entry, index) => ({
        label: entry.name || "Open",
        action: "desktop:" + index,
        danger: false
    })).concat([
        { label: "Fullscreen", action: "fullscreen-window", danger: false },
        { label: "Maximize column", action: "maximize-column", danger: false },
        { label: Services.WindowMenu.captured?.is_floating ? "Tile window" : "Float window", action: "toggle-window-floating", danger: false },
        { label: Services.WindowMenu.expanded === "workspace" ? "Move to workspace ▾" : "Move to workspace ▸", action: "expand-workspace", danger: false }
    ]).concat(Services.WindowMenu.outputs.length > 1 ? [
        { label: Services.WindowMenu.expanded === "monitor" ? "Move to monitor ▾" : "Move to monitor ▸", action: "expand-monitor", danger: false }
    ] : []).concat([
        { label: "Close window", action: "close-window", danger: true },
        { label: Services.WindowMenu.confirmingForceQuit ? "Confirm force quit?" : "Force quit", action: "force-quit", danger: true }
    ])

    Row {
        id: header
        x: Metrics.panelPad
        y: 10
        width: parent.width - Metrics.panelPad * 2
        height: 48
        spacing: 10

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            sourceSize: Qt.size(width, height)
            source: Services.WindowMenu.captured
                ? Quickshell.iconPath(Services.WindowMenu.appEntry?.icon || Services.WindowMenu.captured.app_id || "application-x-executable", true)
                : ""
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 44
            spacing: 2
            Txt {
                width: parent.width
                px: 14
                weight: Font.DemiBold
                text: Services.WindowMenu.captured?.app_id || "No focused window"
                elide: Text.ElideRight
            }
            Txt {
                width: parent.width
                px: 10.5
                color: Theme.textSecondary
                text: Services.WindowMenu.captured?.title || ""
                elide: Text.ElideRight
            }
        }
    }

    Flickable {
        id: scroll
        x: Metrics.panelPad
        y: header.y + header.height + 5
        width: parent.width - Metrics.panelPad * 2
        height: parent.height - y - 10
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: scroll.width
            spacing: 8

            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: 6
                rowSpacing: 5

                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Metrics.rowHeight
                        radius: Metrics.rowRadius
                        color: Theme.panel

                        Txt {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            px: 12
                            color: modelData.danger ? Theme.danger : Theme.text
                            text: modelData.label
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const action = modelData.action
                                if (action === "expand-workspace") {
                                    Services.WindowMenu.expanded = Services.WindowMenu.expanded === "workspace" ? "" : "workspace"
                                    Services.WindowMenu.selectedWorkspaceIndex = 0
                                } else if (action === "expand-monitor") {
                                    Services.WindowMenu.expanded = Services.WindowMenu.expanded === "monitor" ? "" : "monitor"
                                } else if (action === "force-quit") {
                                    if (Services.WindowMenu.confirmingForceQuit) {
                                        Services.WindowMenu.forceQuit()
                                        Island.close()
                                    } else {
                                        Services.WindowMenu.confirmingForceQuit = true
                                    }
                                } else {
                                    Services.WindowMenu.action(action)
                                    Island.close()
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2
                visible: Services.WindowMenu.expanded === "workspace" || Services.WindowMenu.expanded === "monitor"

                Repeater {
                    model: Services.WindowMenu.expanded === "workspace"
                        ? Services.WindowMenu.targetWorkspaces
                        : Services.WindowMenu.expanded === "monitor" ? Services.WindowMenu.outputs : []
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 36
                        radius: Metrics.rowRadius
                        color: Services.WindowMenu.expanded === "workspace"
                            && Services.WindowMenu.targetWorkspaces[Services.WindowMenu.selectedWorkspaceIndex]?.id === modelData.id
                            ? Theme.chip : Theme.panel
                        readonly property string targetRef: Services.WindowMenu.expanded === "workspace"
                            ? String(modelData.name || modelData.idx) : String(modelData)

                        Txt {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            verticalAlignment: Text.AlignVCenter
                            px: 12
                            color: Theme.textSecondary
                            text: Services.WindowMenu.expanded === "workspace"
                                ? "Workspace " + (modelData.name || modelData.idx) : String(modelData)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Services.WindowMenu.action((Services.WindowMenu.expanded === "workspace" ? "workspace:" : "monitor:") + parent.targetRef)
                                Island.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
