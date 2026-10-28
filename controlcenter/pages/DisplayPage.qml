import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.controlcenter
import qs.services
import qs.theme

SubPage {
    id: root
    title: "Display"
    readonly property real minX: Displays.outputs.length ? Math.min(...Displays.outputs.map(o => o.x)) : 0
    readonly property real minY: Displays.outputs.length ? Math.min(...Displays.outputs.map(o => o.y)) : 0
    readonly property real layoutWidth: Displays.outputs.length
        ? Math.max(...Displays.outputs.map(o => o.x + o.width)) - minX : 1
    readonly property real layoutHeight: Displays.outputs.length
        ? Math.max(...Displays.outputs.map(o => o.y + o.height)) - minY : 1

    Binding {
        target: GridLayoutModel
        property: "displayHeight"
        value: root.naturalHeight
    }

    Rectangle {
        width: root.contentWidth
        height: Metrics.ccDisplayLayoutHeight
        radius: Metrics.monitorCardRadius
        color: Theme.card

        Row {
            x: Metrics.ccDisplayPanelInset; y: Metrics.ccDisplayHeaderTop
            spacing: 8
            Txt { px: 13; weight: Font.DemiBold; text: "Display layout" }
            PillButton { text: "Extend"; onClicked: Displays.extendAll() }
        }

        Item {
            id: canvas
            x: Metrics.ccDisplayPanelInset; y: Metrics.ccDisplayCanvasTop
            width: parent.width - 2 * Metrics.ccDisplayPanelInset; height: Metrics.ccDisplayCanvasHeight
            readonly property real fitScale: Math.min((width - 2 * Metrics.ccDisplayCanvasInset) / Math.max(1, root.layoutWidth),
                                                       (height - 2 * Metrics.ccDisplayCanvasInset) / Math.max(1, root.layoutHeight))

            Repeater {
                model: Displays.outputs
                Rectangle {
                    id: outputTile
                    required property var modelData
                    readonly property real scaleFactor: canvas.fitScale
                    x: Metrics.ccDisplayCanvasInset + (modelData.x - root.minX) * scaleFactor
                    y: Metrics.ccDisplayCanvasInset + (modelData.y - root.minY) * scaleFactor
                    width: Math.max(Metrics.ccLayoutTileMinWidth, modelData.width * scaleFactor)
                    height: Math.max(Metrics.ccLayoutTileMinHeight, modelData.height * scaleFactor)
                    radius: Metrics.ccLayoutTileRadius
                    color: modelData.enabled ? Theme.mix(Theme.chip, Theme.accent, 0.5) : Theme.raised
                    border.width: modelData.enabled ? 1 : 0
                    border.color: Theme.accent
                    opacity: modelData.enabled ? 1 : 0.6

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; px: 10; weight: Font.DemiBold; text: outputTile.modelData.name }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; px: 9; color: Theme.textSecondary; text: outputTile.modelData.enabled ? "drag to arrange" : "disabled" }
                    }
                    MouseArea {
                        id: dragger
                        anchors.fill: parent
                        enabled: outputTile.modelData.enabled
                        cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor
                        drag.target: outputTile
                        drag.axis: Drag.XAndYAxis
                        onReleased: {
                            const px = root.minX + (outputTile.x - Metrics.ccDisplayCanvasInset) / outputTile.scaleFactor
                            const py = root.minY + (outputTile.y - Metrics.ccDisplayCanvasInset) / outputTile.scaleFactor
                            if (!Displays.setPosition(outputTile.modelData.name, px, py)) {
                                outputTile.x = Metrics.ccDisplayCanvasInset + (outputTile.modelData.x - root.minX) * outputTile.scaleFactor
                                outputTile.y = Metrics.ccDisplayCanvasInset + (outputTile.modelData.y - root.minY) * outputTile.scaleFactor
                            }
                        }
                    }
                }
            }
        }
        Txt {
            x: Metrics.ccDisplayPanelInset; y: Metrics.ccDisplayHintTop
            width: parent.width - 2 * Metrics.ccDisplayPanelInset
            height: Metrics.ccDisplayHintHeight
            px: 9.5; color: Theme.textMuted
            text: Displays.message || "Startup priority: " + (Config.display.startupFocusOutput || "not set") + " · No native mirror; wl-mirror displays a source in a fullscreen window."
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: Displays.outputs
        Item {
            required property var modelData
            width: root.contentWidth
            height: card.height + 12
            MonitorCard { id: card; output: parent.modelData }
        }
    }

    Rectangle {
        width: root.contentWidth
        height: 85
        radius: Metrics.monitorCardRadius
        color: Theme.card
        Rectangle {
            id: moon
            x: 11; y: 13
            width: Metrics.rowIcon; height: Metrics.rowIcon; radius: width / 2
            color: Theme.accent
            Icon { anchors.centerIn: parent; name: "dark_mode"; size: Metrics.iconXs + 2; color: Theme.onAccent; filled: true }
        }
        Column {
            x: 53; y: 10
            Txt { px: 14; weight: Font.DemiBold; text: "Night Light" }
            Txt { px: 10.5; color: Theme.textSecondary; text: NightLight.temperature + " K" }
        }
        Switch {
            x: parent.width - width - 12
            y: moon.y + (moon.height - height) / 2
            checked: NightLight.enabled
            onToggled: on => NightLight.setEnabled(on)
        }
        Slider {
            x: 11; y: 51
            width: parent.width - 22
            height: 25
            icon: "dark_mode"
            value: (NightLight.maxTemp - NightLight.temperature) / (NightLight.maxTemp - NightLight.minTemp)
            onMoved: v => NightLight.setTemperature(NightLight.maxTemp - v * (NightLight.maxTemp - NightLight.minTemp))
        }
    }
}
