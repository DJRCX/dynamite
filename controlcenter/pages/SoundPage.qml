import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.services
import qs.theme

SubPage {
    id: root
    title: "Sound"

    PwObjectTracker { objects: Audio.streams }

    component NodeRow: DeviceRow {
        id: row
        required property var modelData
        readonly property bool isDefault: modelData.id === (modelData.isSink ? Audio.sink?.id : Audio.source?.id)
        rowHeight: Metrics.compactRowHeight
        iconSize: 28
        iconX: 6
        icon: Audio.iconFor(modelData)
        highlighted: isDefault
        title: Audio.label(modelData)
        titlePx: 12.5
        titleWeight: Font.Medium
        clickable: !isDefault
        onClicked: Audio.setDefault(modelData)
        Item {
            width: 20; height: Metrics.pillHeight
            Icon {
                anchors.centerIn: parent
                name: "check"
                size: Metrics.iconSm
                color: Theme.accent
                opacity: row.isDefault ? 1 : 0
                Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
            }
        }
    }

    SectionLabel { text: "Output" }
    Item { width: 1; height: Metrics.sectionGap }
    Column {
        width: root.contentWidth
        spacing: Metrics.rowGap
        Repeater {
            model: ScriptModel { values: Audio.outputs; objectProp: "id" }
            NodeRow {}
        }
    }
    Item { width: 1; height: 11 }
    VolumeRow {
        visible: Audio.sink !== null
        value: Audio.muted ? 0 : Audio.volume
        icon: Audio.volumeIcon
        onMoved: v => Audio.setVolume(v)
    }

    Item { width: 1; height: Metrics.sectionGap }
    SectionLabel { text: "Input" }
    Item { width: 1; height: Metrics.sectionGap }
    Column {
        width: root.contentWidth
        spacing: Metrics.rowGap
        Repeater {
            model: ScriptModel { values: Audio.inputs; objectProp: "id" }
            NodeRow {}
        }
    }
    Item { width: 1; height: 11 }
    VolumeRow {
        visible: Audio.source !== null
        value: Audio.inputMuted ? 0 : Audio.inputVolume
        icon: "mic"
        onMoved: v => Audio.setInputVolume(v)
    }

    Item { width: 1; height: Metrics.sectionGap + 1; visible: Audio.streams.length > 0 }
    SectionLabel { text: "Apps"; visible: Audio.streams.length > 0 }
    Item { width: 1; height: Metrics.sectionGap; visible: Audio.streams.length > 0 }
    Column {
        width: root.contentWidth
        spacing: Metrics.rowGap
        Repeater {
            model: ScriptModel { values: Audio.streams; objectProp: "id" }
            Rectangle {
                id: app
                required property var modelData
                width: root.contentWidth
                height: 56
                radius: Metrics.rowRadius
                color: Theme.card
                Txt {
                    x: 12; y: 8
                    width: parent.width - 24
                    px: 13; weight: Font.DemiBold
                    text: Audio.nodeName(app.modelData)
                }
                VolumeRow {
                    x: 11; y: 27
                    width: parent.width - 22
                    height: 22
                    sliderWidth: 378
                    value: app.modelData.audio?.muted ? 0 : (app.modelData.audio?.volume ?? 0)
                    icon: "volume_up"
                    onMoved: v => Audio.setNodeVolume(app.modelData, v)
                }
            }
        }
    }
    Item { width: 1; height: 12 }
}
