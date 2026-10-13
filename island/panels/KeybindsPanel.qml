import QtQuick
import qs.components
import qs.services
import qs.state
import qs.theme

Item {
    id: root
    width: Metrics.keybindPanelWidth
    height: Metrics.keybindPanelHeight
    property string query: ""

    Rectangle {
        x: Metrics.panelPad; y: Metrics.panelPad; width: parent.width - Metrics.panelPad * 2
        height: Metrics.keybindSearchHeight; radius: Metrics.rowRadius; color: Theme.field
        Text {
            x: Metrics.panelPad; anchors.verticalCenter: parent.verticalCenter
            visible: search.text.length === 0; text: "Search shortcuts…"
            color: Theme.textMuted; font.family: "Inter"; font.pointSize: Theme.pt(12)
        }
        TextInput {
            id: search
            anchors { fill: parent; leftMargin: Metrics.panelPad; rightMargin: Metrics.panelPad }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text; selectionColor: Theme.accent; selectedTextColor: Theme.onAccent
            font.family: "Inter"; font.pointSize: Theme.pt(12)
            selectByMouse: true
            onTextChanged: { root.query = text; results.currentIndex = 0 }
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Island.close()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down && results.count > 0) {
                    results.currentIndex = 0
                    results.forceActiveFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return && results.count > 0) {
                    Keybinds.run(results.model[0])
                    event.accepted = true
                }
            }
        }
    }

    Rectangle {
        x: Metrics.panelPad; y: Metrics.keybindListTop - Metrics.keybindRowGap
        width: parent.width - Metrics.panelPad * 2; height: Metrics.keybindDividerHeight
        color: Theme.divider
    }

    ListView {
        id: results
        x: Metrics.panelPad; y: Metrics.keybindListTop; width: parent.width - Metrics.panelPad * 2
        height: Math.min(parent.height - Metrics.keybindListTop - Metrics.panelPad,
            Metrics.keybindMaxRows * Metrics.keybindRowHeight + (Metrics.keybindMaxRows - 1) * Metrics.keybindRowGap)
        clip: true; spacing: Metrics.keybindRowGap
        model: Keybinds.search(root.query)
        delegate: Rectangle {
            required property int index
            required property var modelData
            width: results.width; height: Metrics.keybindRowHeight; radius: Metrics.rowRadius
            color: ListView.isCurrentItem ? Theme.panel : Qt.alpha(Theme.panel, 0)

            Column {
                x: Metrics.panelPad; anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - keycaps.width - Metrics.panelPad * 3); spacing: 1
                Txt {
                    width: parent.width; px: 12; weight: Font.DemiBold
                    text: modelData.title; elide: Text.ElideRight
                }
                Txt {
                    width: parent.width; px: 9.5; color: Theme.textSecondary
                    text: modelData.category; elide: Text.ElideRight
                }
            }

            Row {
                id: keycaps
                anchors { right: parent.right; rightMargin: Metrics.panelPad; verticalCenter: parent.verticalCenter }
                spacing: Metrics.keybindRowGap
                Repeater {
                    model: Keybinds.keyParts(modelData.key)
                    delegate: Rectangle {
                        required property string modelData
                        width: keyText.implicitWidth + Metrics.keybindKeyPad * 2
                        height: Metrics.keybindKeyHeight; radius: Metrics.keybindKeyRadius; color: Theme.chip
                        Txt {
                            id: keyText; anchors.centerIn: parent; px: 9.5; weight: Font.Medium
                            text: modelData; color: Theme.text
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: results.currentIndex = index
                onClicked: Keybinds.run(modelData)
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Island.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Return && currentIndex >= 0 && currentIndex < count) {
                Keybinds.run(model[currentIndex])
                event.accepted = true
            } else if (count > 0 && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                const step = event.key === Qt.Key_Down ? 1 : -1
                currentIndex = (currentIndex + step + count) % count
                event.accepted = true
            }
        }
    }

    Txt {
        anchors.centerIn: results; visible: results.count === 0
        px: 12; color: Theme.textSecondary; text: root.query ? "No matching shortcuts" : "No shortcuts found"
    }
}
