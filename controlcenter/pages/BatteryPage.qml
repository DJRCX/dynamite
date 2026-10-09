import QtQuick
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

Item {
    width: 514; height: 446
    Column { x: 22; y: 20; width: 470; spacing: 12
        Text { text: "‹    Battery"; color: Theme.text; font.pixelSize: 15 }
        Rectangle { width: 470; height: 96; radius: 16; color: Theme.card
            Text { x: 18; y: 12; text: Battery.percentage + "%"; color: Theme.text; font.pixelSize: 28 }
            Text { x: 18; y: 59; text: "Battery status"; color: Theme.textSecondary; font.pixelSize: 11 }
        }
        Row { spacing: 4
            Repeater { model: ["performance","balanced","power-saver"]; delegate: Rectangle { required property string modelData; width: 153; height: 40; radius: 20; color: PowerProfile.current === modelData ? Theme.accent : Theme.control
                Text { anchors.centerIn: parent; text: modelData; color: PowerProfile.current === modelData ? Theme.onAccent : Theme.text; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: PowerProfile.set(modelData) }
            } }
        }
        Text { text: "Automatic profiles  ·  " + (Config.power.auto ? "On" : "Off"); color: Theme.text; font.pixelSize: 12 }
        Slider { width: 470; height: 4; value: (Config.power.saverAt - 20) / 60; onMoved: Config.power.saverAt = Math.round(20 + value * 60) }
    }
}
