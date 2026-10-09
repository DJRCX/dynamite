import QtQuick
import qs.services
import qs.theme

Item {
    id: root
    width: 514; height: 500
    property string query: ""
    TextInput { x: 16; y: 12; width: 480; height: 28; color: Theme.text; font.pixelSize: 14; onTextChanged: root.query=text }
    ListView { x: 14; y: 52; width: 486; height: 430; clip: true; model: Keybinds.binds.filter(b => !root.query || (b.key+b.action+b.args).toLowerCase().includes(root.query.toLowerCase()))
        delegate: Rectangle { required property var modelData; width: 486; height: 42; color: "transparent"
            Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.action; color: Theme.text; font.pixelSize: 13 }
            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.key; color: Theme.accent; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; onClicked: Keybinds.run(modelData) }
        }
    }
}
