import QtQuick
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

// Theme selection is intentionally separate from wallpaper browsing.
Item {
    id: root
    width: 802
    height: Metrics.themePickerHeight

    property string query: ""
    property string selectedName: ""
    property bool scrollSprung: false

    readonly property var themes: Themes.list.filter(theme => matches(theme, query))
    readonly property int selectedIndex: {
        const index = themes.findIndex(theme => theme.name === selectedName)
        return index < 0 ? 0 : index
    }
    readonly property real pitch: Metrics.themeCardWidth + Metrics.themeCardGap
    property real scroll: selectedIndex * pitch
    Behavior on scroll { enabled: root.scrollSprung; Spring { token: Motion.panel } }

    function matches(theme: var, searchText: string): bool {
        const value = searchText.trim().toLowerCase()
        return value === "" || theme.name.toLowerCase().includes(value)
            || (theme.label ?? "").toLowerCase().includes(value)
    }

    function reset(): void {
        scrollSprung = false
        query = ""
        selectedName = Config.appearance.theme
        Themes.refresh()
        input.text = ""
        Qt.callLater(() => input.forceActiveFocus())
        scrollSprung = true
    }

    function applyTheme(theme: var): void {
        if (!theme) return
        Themes.apply(theme.name)
    }

    function moveTheme(delta: int): void {
        if (!themes.length) return
        const index = Math.max(0, Math.min(themes.length - 1, selectedIndex + delta))
        selectedName = themes[index].name
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            Island.close()
        } else if (event.key === Qt.Key_Left) {
            if (input.text.length && input.cursorPosition > 0) return
            moveTheme(-1)
        } else if (event.key === Qt.Key_Right) {
            if (input.text.length && input.cursorPosition < input.text.length) return
            moveTheme(1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (themes.length) applyTheme(themes[selectedIndex])
        } else {
            return
        }
        event.accepted = true
    }

    Component.onCompleted: reset()
    Connections {
        target: Island
        function onModeChanged() { if (Island.mode === "themes") root.reset() }
    }
    Connections {
        target: Themes
        function onListChanged() {
            if (root.themes.some(theme => theme.name === root.selectedName)) return
            const active = Themes.list.find(theme => theme.name === Config.appearance.theme)
            root.selectedName = active?.name ?? (root.themes.length ? root.themes[0].name : "")
        }
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
        x: 42; y: 12
        width: counter.x - x - 12
        height: 19
        text: root.query
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: "Inter"
        font.pointSize: Theme.pt(13)
        selectionColor: Theme.accentContainer
        cursorDelegate: Rectangle {
            width: 2; height: 15
            y: (input.height - height) / 2
            color: Theme.text
            visible: input.cursorVisible
        }
        clip: true
        onTextChanged: {
            root.query = text
            if (!root.themes.some(theme => theme.name === root.selectedName))
                root.selectedName = root.themes.length ? root.themes[0].name : ""
        }
        Keys.onPressed: event => root.handleKey(event)
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            px: 13
            color: Theme.textMuted
            text: "Search themes..."
        }
    }
    Txt {
        id: counter
        x: root.width - 14 - width
        anchors.baseline: input.baseline
        px: 10
        color: Theme.textMuted
        text: root.themes.length ? (root.selectedIndex + 1) + "/" + root.themes.length : "0/" + Themes.list.length
    }

    Item {
        id: carousel
        x: 0; y: 52
        width: root.width; height: 112
        clip: true
        Repeater {
            model: root.themes
            delegate: Item {
                id: slot
                required property var modelData
                required property int index
                readonly property bool selected: index === root.selectedIndex
                readonly property bool applied: modelData.name === Config.appearance.theme
                x: (root.width - Metrics.themeCardWidth) / 2 + index * root.pitch - root.scroll
                visible: x > -width && x < root.width
                width: Metrics.themeCardWidth
                height: root.height
                property real lift: selected ? Metrics.themeCardLift : 0
                Behavior on lift { Spring { token: Motion.panel } }
                property real outline: selected ? 1 : 0
                Behavior on outline { Spring { token: Motion.fade; epsilon: 0.005 } }

                Rectangle {
                    y: (carousel.height - height) / 2 - slot.lift
                    width: Metrics.themeCardWidth
                    height: Metrics.themeCardHeight
                    radius: Metrics.themeCardRadius
                    color: slot.modelData.panel ?? Theme.panel
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 40 - Metrics.themeDot / 2
                        spacing: Metrics.themeDotGap
                        Repeater {
                            model: slot.modelData.preview ?? []
                            delegate: Rectangle {
                                required property string modelData
                                width: Metrics.themeDot; height: Metrics.themeDot
                                radius: width / 2
                                color: modelData
                            }
                        }
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 81 - height / 2
                        width: Math.min(implicitWidth, parent.width - 20)
                        px: 10
                        weight: slot.selected ? Font.DemiBold : Font.Medium
                        color: slot.selected ? Theme.text : Theme.textSecondary
                        text: slot.modelData.label ?? slot.modelData.name
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        x: parent.width - 12 - width / 2
                        y: 10 - height / 2
                        width: Metrics.themeMarker; height: Metrics.themeMarker
                        radius: width / 2
                        color: Theme.textSecondary
                        visible: slot.applied
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        opacity: slot.outline
                        visible: opacity > 0.01
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedName = slot.modelData.name
                        input.forceActiveFocus()
                        root.applyTheme(slot.modelData)
                    }
                }
            }
        }
    }

    WheelHandler {
        property real accumulated: 0
        onWheel: event => {
            accumulated += Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y
            while (Math.abs(accumulated) >= 120) {
                root.moveTheme(accumulated > 0 ? -1 : 1)
                accumulated -= accumulated > 0 ? 120 : -120
            }
        }
    }

    Rectangle { x: 14; y: 178; width: root.width - 28; height: 1; color: Theme.divider }
    Txt {
        x: 15; y: 187
        px: 9.5
        color: Theme.textMuted
        text: "← / → to browse · Enter to apply (random wallpaper)"
    }
    Txt {
        x: root.width - 14 - width; y: 187
        px: 9.5
        color: Theme.textMuted
        text: "Mod+4: Wallpapers"
    }
}
