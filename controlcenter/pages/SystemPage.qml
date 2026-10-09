import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root
    width: 514
    height: 600
    property int confirmPid: -1
    Component.onCompleted: SysStats.visible = true
    Component.onDestruction: SysStats.visible = false
    Column {
        x: 22; y: 18; width: 470; spacing: 8
        Text { text: "‹    System"; color: Theme.text; font.pixelSize: 15 }
        Repeater {
            model: [{name:"CPU",value:SysStats.cpu,history:SysStats.history},{name:"Memory",value:SysStats.memory,history:SysStats.memoryHistory},{name:"Temperature",value:SysStats.temperature,history:SysStats.temperatureHistory}]
            delegate: Rectangle {
                required property var modelData
                width: 470; height: 74; radius: 15; color: Theme.card
                Text { x: 15; y: 12; text: modelData.name; color: Theme.text; font.pixelSize: 12 }
                Text { anchors.right: parent.right; anchors.rightMargin: 15; y: 12; text: modelData.name === "Temperature" ? Math.round(modelData.value)+"°C · "+SysStats.tempSensorName : Math.round(modelData.value)+"%"; color: modelData.name === "Temperature" && modelData.value >= Config.sysmon.warnTemp ? Theme.danger : Theme.accent; font.pixelSize: 11 }
                Rectangle { x: 15; y: 38; width: parent.width-30; height: 4; radius: 2; color: Theme.track }
                Rectangle { x: 15; y: 38; width: (parent.width-30)*Math.max(0,Math.min(1,modelData.name === "Temperature" ? modelData.value/100 : modelData.value/100)); height: 4; radius: 2; color: Theme.accent }
                Row {
                    x: 15; y: 49; width: parent.width - 30; height: 18; spacing: 1
                    Repeater { model: modelData.history || []; delegate: Rectangle { required property real modelData; width: Math.max(1, (parent.width / 60) - 1); height: Math.max(1, 14 * Math.min(1, modelData / 100)); y: parent.height - height; color: Theme.accent; opacity: 0.65 } }
                }
            }
        }
        Item { width: 470; height: 18
            Text { text: "Top processes"; color: Theme.text; font.pixelSize: 11 }
            Text { text: "CPU · MEM"; color: Theme.textMuted; font.pixelSize: 9; anchors.right: parent.right }
        }
        Repeater {
            model: SysStats.topProcesses
            delegate: Rectangle {
                required property var modelData
                width: 470; height: 27; radius: 7; color: Theme.raised
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 238; text: modelData.name; color: Theme.text; font.pixelSize: 10; elide: Text.ElideRight }
                Text { x: 250; anchors.verticalCenter: parent.verticalCenter; width: 72; text: modelData.cpu.toFixed(1) + "%"; color: Theme.textSecondary; font.pixelSize: 9 }
                Text { x: 325; anchors.verticalCenter: parent.verticalCenter; width: 68; text: modelData.memory.toFixed(1) + "%"; color: Theme.textSecondary; font.pixelSize: 9 }
                Rectangle { x: 400; y: 3; width: 62; height: 21; radius: 10; color: root.confirmPid === modelData.pid ? Theme.danger : Theme.control
                    Text { anchors.centerIn: parent; text: root.confirmPid === modelData.pid ? "Confirm" : "End"; color: Theme.text; font.pixelSize: 9 }
                    MouseArea { anchors.fill: parent; onClicked: { if (root.confirmPid === modelData.pid) { SysStats.end(modelData.pid); root.confirmPid = -1 } else root.confirmPid = modelData.pid } }
                }
            }
        }
        Row { spacing: 8
            Text { text: "Open btop"; color: Theme.accent; font.pixelSize: 10 }
            MouseArea { width: 70; height: 20; onClicked: Niri.action(["spawn", "--", Config.system.terminal, "-e", "btop"]) }
            Text { text: "Refreshes while this page is open"; color: Theme.textMuted; font.pixelSize: 9 }
        }
    }
}
