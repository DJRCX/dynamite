import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

// 514 wide; height 83 + 47·n for n visible rows. One shared selection bar slides between rows.
Item {
    id: root
    readonly property string calc: Apps.calculate(input.text)
    property string activeCategory: "All"
    readonly property var apps: Apps.search(input.text, activeCategory)
    // Rows: an optional calculator result, then apps.
    readonly property var rows: (calc !== "" ? [{ calc: calc }] : []).concat(apps.map(app => ({ app: app })))
    readonly property int visibleRows: Math.max(1, Math.min(Config.launcher.maxResults, rows.length))
    readonly property int pitch: Metrics.launcherRow

    Binding { target: Island; property: "launcherHeight"; value: 83 + 47 * root.visibleRows }

    function reset(): void {
        input.text = ""
        activeCategory = "All"
        list.currentIndex = 0
        list.positionViewAtBeginning()
        input.forceActiveFocus()
    }
    Component.onCompleted: reset()
    Connections {
        target: Island
        function onModeChanged() { if (Island.mode === "launcher") root.reset() }
    }

    function move(delta: int): void {
        if (rows.length === 0) return
        list.currentIndex = Math.max(0, Math.min(rows.length - 1, list.currentIndex + delta))
    }
    function cycleCategory(delta: int): void {
        const index = Apps.categories.indexOf(activeCategory)
        activeCategory = Apps.categories[(index + delta + Apps.categories.length) % Apps.categories.length]
        list.currentIndex = 0
        list.positionViewAtBeginning()
    }
    function activate(index: int): void {
        const row = rows[index]
        if (!row) return
        if (row.calc !== undefined) Apps.copy(row.calc)
        else Apps.launch(row.app)
        Island.close()
    }

    Icon {
        x: 15
        anchors.verticalCenter: input.verticalCenter
        name: "search"
        size: Metrics.iconMd
        color: Theme.textMuted
    }
    TextInput {
        id: input
        x: 44; y: 21
        width: Metrics.launcherSearchWidth
        height: 20
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: "Inter"
        font.pointSize: Theme.pt(14)
        selectionColor: Theme.accentContainer
        cursorDelegate: Rectangle {
            width: 2; height: 16
            y: (input.height - height) / 2
            color: Theme.text
            visible: input.cursorVisible
        }
        clip: true
        onTextChanged: {
            list.currentIndex = 0
            if (text === ";") { Island.open("clipboard"); text = "" }
            else if (text === "?") { Island.open("keybinds"); text = "" }
            else if (text === "!") { Island.open("window"); text = "" }
        }
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier
            if (event.key === Qt.Key_Escape) { Island.close(); event.accepted = true }
            else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) { root.move(1); event.accepted = true }
            else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) { root.move(-1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activate(list.currentIndex); event.accepted = true }
            else if (event.key === Qt.Key_Tab) {
                root.cycleCategory(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                event.accepted = true
            }
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            px: 14
            color: Theme.textMuted
            text: "Search..."
        }
    }

    Rectangle {
        x: Metrics.launcherCategoryX; y: Metrics.launcherCategoryY
        width: Metrics.launcherCategoryWidth; height: Metrics.launcherCategoryHeight
        radius: height / 2
        color: root.activeCategory === "All" ? Theme.chip : Theme.accentContainer
        Txt { anchors.centerIn: parent; px: 10.5; color: root.activeCategory === "All" ? Theme.textSecondary : Theme.accent; text: root.activeCategory }
    }

    Rectangle {
        x: 14; y: 58
        width: 486; height: 1
        color: Theme.divider
    }

    ListView {
        id: list
        x: 14; y: 71
        width: 486
        height: root.pitch * root.visibleRows + 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows
        highlightFollowsCurrentItem: false
        highlightMoveDuration: 0
        highlight: Item {
            width: list.width
            height: root.pitch + 1
            y: list.currentItem ? list.currentItem.y : 0
            Behavior on y { Spring { token: Motion.panel } }
            Rectangle { anchors.fill: parent; radius: 10; color: Theme.subpage }
            Rectangle { x: 1; y: 13; width: 3; height: 21; radius: 1.5; color: Theme.accent }
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property var app: modelData.app ?? null
            width: list.width
            height: root.pitch

            Rectangle {
                x: 12; y: (root.pitch - height) / 2
                width: Metrics.launcherTile; height: Metrics.launcherTile
                radius: 8
                color: Theme.track
                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: Metrics.launcherIcon; height: Metrics.launcherIcon
                    visible: status === Image.Ready
                    // A fixed source size: some themes ship SVGs with huge canvases.
                    sourceSize: Qt.size(Metrics.launcherIcon * 2, Metrics.launcherIcon * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    source: row.app ? (row.app.iconPath || Quickshell.iconPath(row.app.icon, true)) : ""
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    name: row.app ? "apps" : "calculate"
                    size: Metrics.iconMd
                    color: Theme.textSecondary
                }
            }
            Txt {
                x: 56
                y: comment.text !== "" ? 9 : 15
                width: parent.width - 56 - (row.app && Apps.isWebApp(row.app) ? Metrics.iconSm + Metrics.panelPad : Metrics.panelPad)
                px: 14; weight: Font.DemiBold
                text: row.app ? row.app.name : "= " + row.modelData.calc
            }
            Txt {
                id: comment
                x: 56; y: 27
                width: parent.width - 56 - 14
                visible: text !== ""
                px: 10.5
                color: Theme.textSecondary
                text: row.app ? (row.app.comment || row.app.genericName || "") : "Enter to copy"
            }
            Icon {
                x: parent.width - Metrics.iconSm - Metrics.panelPad
                anchors.verticalCenter: parent.verticalCenter
                visible: row.app && Apps.isWebApp(row.app)
                name: "language"
                size: Metrics.iconSm
                color: Theme.textMuted
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = row.index
                onClicked: root.activate(row.index)
            }
        }
    }

    Txt {
        x: 56; y: 71 + 15
        visible: root.rows.length === 0
        px: 14
        color: Theme.textSecondary
        text: "No results"
    }
}
