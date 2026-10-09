import QtQuick
import Quickshell
import Quickshell
import qs.components
import qs.services as Services
import qs.state
import qs.theme

Item {
    id: root
    readonly property real baseHeight: 370 + Services.WindowMenu.desktopActions.length * (Metrics.rowHeight + 5)
        + (Services.WindowMenu.outputs.length > 1 ? Metrics.rowHeight + 5 : 0)
    readonly property real submenuHeight: Services.WindowMenu.expanded === "workspace" ? Math.min(210, Services.WindowMenu.targetWorkspaces.length * 37)
        : Services.WindowMenu.expanded === "monitor" ? Math.min(148, Services.WindowMenu.outputs.length * 37) : 0
    height: Math.min(650, baseHeight + submenuHeight)
    Behavior on height { Spring { token: Motion.panel } }

    Column {
        x: Metrics.panelPad; y: 12; width: parent.width - Metrics.panelPad * 2; spacing: 5
        Row {
            width: parent.width; height: 45; spacing: 10
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34
                sourceSize.width: width; sourceSize.height: height
                source: Services.WindowMenu.captured ? Quickshell.iconPath(Services.WindowMenu.appEntry?.icon || Services.WindowMenu.captured.app_id || "application-x-executable", true) : ""
            }
            Column {
                width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Txt { width: parent.width; px: 14; weight: Font.DemiBold; text: Services.WindowMenu.captured?.app_id || "No focused window"; elide: Text.ElideRight }
                Txt { width: parent.width; px: 10.5; color: Theme.textSecondary; text: Services.WindowMenu.captured?.title || ""; elide: Text.ElideRight }
            }
        }

        Repeater {
            model: Services.WindowMenu.desktopActions
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: root.width - Metrics.panelPad * 2; height: Metrics.rowHeight; radius: Metrics.rowRadius; color: Theme.panel
                Txt { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; px: 13; text: modelData.name || "Open" }
                MouseArea { anchors.fill: parent; onClicked: { Services.WindowMenu.action("desktop:" + index); Island.close() } }
            }
        }

        Repeater {
            model: [
                { label: "Fullscreen", action: "fullscreen-window" },
                { label: "Maximize column", action: "maximize-column" },
                { label: Services.WindowMenu.captured?.is_floating ? "Tile window" : "Float window", action: "toggle-window-floating" },
                { label: Services.WindowMenu.expanded === "workspace" ? "Move to workspace ▾" : "Move to workspace ▸", action: "expand-workspace" }
            ].concat(Services.WindowMenu.outputs.length > 1 ? [{ label: Services.WindowMenu.expanded === "monitor" ? "Move to monitor ▾" : "Move to monitor ▸", action: "expand-monitor" }] : [])
                .concat([{ label: "Close window", action: "close-window", danger: true },
                         { label: Services.WindowMenu.confirmingForceQuit ? "Confirm force quit?" : "Force quit", action: "force-quit", danger: true }])
            delegate: Rectangle {
                required property var modelData
                width: root.width - Metrics.panelPad * 2; height: Metrics.rowHeight; radius: Metrics.rowRadius; color: Theme.panel
                Txt { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; px: 13; color: modelData.danger ? Theme.danger : Theme.text; text: modelData.label }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.action === "expand-workspace") {
                            Services.WindowMenu.expanded = Services.WindowMenu.expanded === "workspace" ? "" : "workspace"
                            Services.WindowMenu.selectedWorkspaceIndex = 0
                        }
                        else if (modelData.action === "expand-monitor") Services.WindowMenu.expanded = Services.WindowMenu.expanded === "monitor" ? "" : "monitor"
                        else if (modelData.action === "force-quit") {
                            if (Services.WindowMenu.confirmingForceQuit) { Services.WindowMenu.forceQuit(); Island.close() }
                            else Services.WindowMenu.confirmingForceQuit = true
                        } else { Services.WindowMenu.action(modelData.action); Island.close() }
                    }
                }
            }
        }

        Item {
            width: parent.width - Metrics.panelPad * 2
            height: Services.WindowMenu.expanded === "workspace" ? Math.min(210, Services.WindowMenu.targetWorkspaces.length * 37)
                : Services.WindowMenu.expanded === "monitor" ? Math.min(148, Services.WindowMenu.outputs.length * 37) : 0
            clip: true
            Behavior on height { Spring { token: Motion.panel } }
            Column {
                width: parent.width; spacing: 1
                Repeater {
                    model: Services.WindowMenu.expanded === "workspace" ? Services.WindowMenu.targetWorkspaces : Services.WindowMenu.expanded === "monitor" ? Services.WindowMenu.outputs : []
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 36; radius: Metrics.rowRadius
                        color: Services.WindowMenu.expanded === "workspace" && Services.WindowMenu.targetWorkspaces[Services.WindowMenu.selectedWorkspaceIndex]?.id === modelData.id ? Theme.chip : Theme.panel
                        readonly property string targetRef: Services.WindowMenu.expanded === "workspace"
                            ? String(modelData.name || modelData.idx) : String(modelData)
                        Txt {
                            anchors.left: parent.left; anchors.leftMargin: 27; anchors.verticalCenter: parent.verticalCenter
                            px: 12; color: Theme.textSecondary
                            text: Services.WindowMenu.expanded === "workspace" ? "Workspace " + (modelData.name || modelData.idx) : String(modelData)
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

    Keys.onReturnPressed: {
        if (Services.WindowMenu.expanded === "workspace" && Services.WindowMenu.targetWorkspaces.length) {
            const ws = Services.WindowMenu.targetWorkspaces[Services.WindowMenu.selectedWorkspaceIndex]
            Services.WindowMenu.action("workspace:" + String(ws.name || ws.idx))
            Island.close()
        }
    }
}
