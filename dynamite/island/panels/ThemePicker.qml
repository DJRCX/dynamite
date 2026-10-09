import QtQuick
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

// 802 × 220: search row, a carousel of theme cards with the selection centered, and the apply hint.
Item {
    id: root
    readonly property var themes: Themes.list.filter(theme => matches(theme, input.text))
    property string selectedName: ""
    readonly property int selectedIndex: Math.max(0, Themes.indexOf(selectedName, themes))
    readonly property real pitch: Metrics.themeCardWidth + Metrics.themeCardGap
    readonly property real carouselHeight: 106
    readonly property real hintRight: width - 13

    property bool scrollSprung: false
    property real scroll: selectedIndex * pitch
    Behavior on scroll { enabled: root.scrollSprung; Spring { token: Motion.panel } }

    function matches(theme: var, query: string): bool {
        const q = query.trim().toLowerCase()
        return q === "" || theme.name.toLowerCase().includes(q) || (theme.label ?? "").toLowerCase().includes(q)
    }
    function reset(): void {
        scrollSprung = false
        input.text = ""
        selectedName = Config.appearance.theme
        Themes.refresh()
        input.forceActiveFocus()
        scrollSprung = true
    }
    Component.onCompleted: reset()
    Connections {
        target: Island
        function onModeChanged() { if (Island.mode === "themes") root.reset() }
    }

    function move(delta: int): void {
        if (themes.length === 0) return
        selectedName = themes[Math.max(0, Math.min(themes.length - 1, selectedIndex + delta))].name
    }
    function applySelected(): void {
        if (themes.length > 0) Themes.apply(themes[selectedIndex].name)
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
        x: 42; y: 20
        width: counter.x - x - 12
        height: 17
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
        onTextChanged: root.selectedName = root.themes.length > 0 ? root.themes[0].name : ""
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { Island.close(); event.accepted = true }
            else if (event.key === Qt.Key_Left) { root.move(-1); event.accepted = true }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.move(1); event.accepted = true }
            else if (event.key === Qt.Key_Backtab) { root.move(-1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.applySelected(); event.accepted = true }
        }
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
        x: root.hintRight - width
        anchors.baseline: input.baseline
        px: 10
        color: Theme.textMuted
        text: root.themes.length > 0 ? (root.selectedIndex + 1) + "/" + root.themes.length : "0/" + Themes.list.length
    }

    Item {
        id: carousel
        y: 64
        width: root.width
        height: root.carouselHeight

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
                height: root.carouselHeight

                property real lift: selected ? Metrics.themeCardLift : 0
                Behavior on lift { Spring { token: Motion.panel } }
                property real outline: selected ? 1 : 0
                Behavior on outline { Spring { token: Motion.fade; epsilon: 0.005 } }

                Rectangle {
                    y: (root.carouselHeight - height) / 2 - slot.lift
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
                        text: slot.modelData.name
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
                    onClicked: slot.selected ? root.applySelected() : (root.selectedName = slot.modelData.name)
                }
            }
        }
    }

    WheelHandler {
        property real accumulated: 0
        onWheel: event => {
            accumulated += Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y
            while (Math.abs(accumulated) >= 120) {
                root.move(accumulated > 0 ? -1 : 1)
                accumulated -= accumulated > 0 ? 120 : -120
            }
        }
    }

    Txt {
        x: root.hintRight - width
        y: 192
        px: 9.5
        color: Theme.textMuted
        text: "Enter to apply"
    }

    Txt {
        anchors.centerIn: carousel
        visible: root.themes.length === 0
        px: 13
        color: Theme.textSecondary
        text: "No themes match"
    }
}
