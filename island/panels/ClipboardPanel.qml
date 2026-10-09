import QtQuick
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

Item {
    id: root
    width: 514
    property string query: ""
    property string activeFilter: "All"
    property string expandedId: ""
    readonly property var rows: Clipboard.visibleEntries(query, activeFilter)
    readonly property int visibleCount: Math.max(1, Math.min(6, rows.length))
    height: 83 + 47 * visibleCount + (expandedId ? 113 : 0)
    Binding { target: Island; property: "clipboardHeight"; value: root.height }
    Component.onCompleted: if (Island.mode === "clipboard") { Clipboard.refresh(); focusTimer.start() }
    Connections {
        target: Island
        function onModeChanged() {
            if (Island.mode === "clipboard") {
                Clipboard.refresh()
                focusTimer.start()
            }
        }
    }
    Timer { id: focusTimer; interval: 120; onTriggered: if (Island.mode === "clipboard") search.forceActiveFocus() }

    TextInput {
        id: search
        x: 48; y: 16; width: 448; height: 24
        color: Theme.text
        font.family: "Inter"; font.pointSize: Theme.pt(14)
        selectionColor: Theme.accentContainer
        focus: true
        onTextChanged: root.query = text
        Keys.onPressed: event => root.handleKey(event)
        Txt { anchors.fill: parent; visible: search.text === ""; px: 14; color: Theme.textMuted; text: "Search clipboard..." }
    }
    Icon { x: 16; y: 16; name: "search"; size: Metrics.iconMd; color: Theme.textMuted }
    Row {
        x: 14; y: 45; spacing: 6
        Repeater {
            model: ["All", "Text", "Images", "Links", "Pinned"]
            delegate: Rectangle {
                required property string modelData
                width: label.implicitWidth + 18; height: 23; radius: 8
                color: root.activeFilter === modelData ? Theme.accentContainer : Theme.chip
                Txt { id: label; anchors.centerIn: parent; px: 10; color: root.activeFilter === modelData ? Theme.accent : Theme.textSecondary; text: modelData }
                MouseArea { anchors.fill: parent; onClicked: root.activeFilter = modelData }
            }
        }
    }
    Rectangle { x: 14; y: 74; width: 486; height: 1; color: Theme.divider }
    ListView {
        id: list
        x: 14; y: 80; width: 486; height: root.visibleCount * 47 + (root.expandedId ? 113 : 0)
        clip: true; spacing: 0
        model: root.rows
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: root.expandedId === modelData.id ? 160 : 47
            Behavior on height { Spring { token: Motion.panel } }
            Rectangle { anchors.fill: parent; radius: 10; color: root.expandedId === row.modelData.id ? Theme.subpage : "transparent" }
            Rectangle { x: 1; y: 13; width: 3; height: 21; radius: 2; color: Theme.accent; visible: root.expandedId === row.modelData.id }
            Icon { x: 12; y: 9; name: row.modelData.image ? "image" : row.modelData.link ? "link" : "content_paste"; size: 28; color: Theme.textSecondary }
            Txt { x: 52; y: 6; width: 350; px: 13; weight: Font.DemiBold; color: Theme.text; elide: Text.ElideRight
                text: row.modelData.link ? row.modelData.host : row.modelData.text.replace(/\n/g, " ") }
            Txt { x: 52; y: 26; width: 350; px: 10.5; color: Theme.textSecondary
                text: row.modelData.image ? "Image · cached clipboard item" : (Clipboard.previewId === row.modelData.id ? Clipboard.previewText.split("\n").length : row.modelData.lines) + " lines" }
            Txt { x: 52; y: 52; width: 418; height: 100; visible: root.expandedId === row.modelData.id && !row.modelData.image
                px: 12; color: Theme.text; wrapMode: Text.Wrap; elide: Text.ElideNone
                maximumLineCount: 6
                text: Clipboard.previewId === row.modelData.id ? Clipboard.previewText : row.modelData.text }
            Icon { x: 438; y: 9; name: Clipboard.pins.some(p => p.id === row.modelData.id || p.text === row.modelData.text) ? "push_pin" : "keep"; size: 18; color: Theme.textMuted }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Clipboard.pin(row.modelData)
                    else {
                        root.expandedId = root.expandedId === row.modelData.id ? "" : row.modelData.id
                        if (root.expandedId) Clipboard.preview(row.modelData.id)
                    }
                }
            }
        }
    }
    function handleKey(event): void {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (event.key === Qt.Key_Escape) { Island.close(); event.accepted = true }
        else if (ctrl && event.key === Qt.Key_P && rows[list.currentIndex]) { Clipboard.pin(rows[list.currentIndex]); event.accepted = true }
        else if (ctrl && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Delete) {
            if (Clipboard.clearConfirm) Clipboard.confirmClear(); else Clipboard.clearHistory()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && rows[list.currentIndex]) { Clipboard.remove(rows[list.currentIndex]); event.accepted = true }
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && rows[list.currentIndex]) { Clipboard.paste(rows[list.currentIndex].id, Config.clipboard.autoPaste); Island.close(); event.accepted = true }
        else if (event.key === Qt.Key_Down) { list.currentIndex = Math.min(rows.length - 1, list.currentIndex + 1); event.accepted = true }
        else if (event.key === Qt.Key_Up) { list.currentIndex = Math.max(0, list.currentIndex - 1); event.accepted = true }
    }
    Txt { x: 14; y: root.height - 26; px: 10.5; color: Theme.danger; visible: Clipboard.clearConfirm; text: "Clear all? Press Ctrl+Shift+Delete again to confirm" }
    Txt { anchors.centerIn: list; visible: root.rows.length === 0; px: 13; color: Theme.textSecondary; text: "No clipboard entries" }
}
