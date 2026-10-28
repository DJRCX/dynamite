import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.controlcenter
import qs.controlcenter.tiles
import qs.services
import qs.state
import qs.theme

FloatingWindow {
    id: root
    title: "Dynamite Settings"
    visible: false
    onVisibleChanged: if (visible && Niri.focusedFullscreen) visible = false
    implicitWidth: 1320
    implicitHeight: Math.min(970, Math.max(600, screen.height - 40))
    color: Theme.window
    property string page: "Bar & Island"
    property string query: ""
    property var pages: ["Bar & Island", "Clock & Date", "Appearance", "Motion", "Launcher", "Notifications", "Control Center", "Lock Screen", "System", "Wallpaper", "Clipboard", "Power & Battery", "Weather", "System monitor"]

    function reopen(page: string): void {
        if (Niri.focusedFullscreen) return
        root.visible = false
        Qt.callLater(() => { root.page = page; root.navHistory = [page]; root.historyIndex = 0; root.visible = true })
    }
    onClosed: root.visible = false
    Connections {
        target: Niri
        function onFocusedFullscreenChanged(): void {
            if (Niri.focusedFullscreen) root.visible = false
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.window; radius: 16; border.width: 1; border.color: Qt.alpha(Theme.text, 0.06) }
    Rectangle {
        x: 0; y: 0; width: 232; height: parent.height; color: Theme.sidebar; radius: 16
        TextInput {
            x: 17; y: 11; width: 198; height: 31; color: Theme.text; font.family: "Inter"; font.pixelSize: 12
            text: root.query; onTextChanged: { root.query = text; root.jumpToMatch(text) }
            Rectangle { z: -1; anchors.fill: parent; radius: 9; color: Theme.field }
            Text { anchors.centerIn: parent; visible: !parent.text; text: "Search Settings"; color: Theme.textMuted; font.pixelSize: 12 }
        }
        Column {
            x: 17; y: 54; width: 198; spacing: 5
            Repeater {
                model: root.filteredPages()
                delegate: Rectangle {
                    required property string modelData
                    readonly property var pageIcons: ({
                        "Bar & Island": "tune", "Media": "music_note", "Clock & Date": "schedule",
                        "Appearance": "palette", "Motion": "animation", "Launcher": "search",
                        "Notifications": "notifications", "Control Center": "tune", "Lock Screen": "lock",
                        "System": "settings", "Wallpaper": "wallpaper", "Clipboard": "content_paste",
                        "Power & Battery": "battery_full", "Weather": "partly_cloudy_day", "System monitor": "memory"
                    })
                    width: 198; height: 38; radius: 10; color: root.page === modelData ? Theme.card : "transparent"
                    Row { anchors.fill: parent; anchors.leftMargin: 9; spacing: 10
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13; color: root.page === modelData ? Theme.accent : Theme.accentContainer
                            Icon { anchors.centerIn: parent; name: pageIcons[modelData] || "settings"; size: Metrics.iconSm; color: root.page === modelData ? Theme.onAccent : Theme.accent }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.text; font.family: "Inter"; font.pointSize: Theme.pt(12.5) }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.navigateTo(modelData) }
                }
            }
        }
    }
    Rectangle {
        x: 246; y: 8; width: 30; height: 30; radius: 15
        color: historyIndex > 0 ? Theme.control : "transparent"
        Icon { anchors.centerIn: parent; name: "chevron_left"; size: Metrics.iconMd; color: historyIndex > 0 ? Theme.text : Theme.textMuted }
        MouseArea { anchors.fill: parent; enabled: historyIndex > 0; onClicked: root.goHistory(-1) }
    }
    Rectangle {
        x: 282; y: 8; width: 30; height: 30; radius: 15
        color: historyIndex < navHistory.length - 1 ? Theme.control : "transparent"
        Icon { anchors.centerIn: parent; name: "chevron_right"; size: Metrics.iconMd; color: historyIndex < navHistory.length - 1 ? Theme.text : Theme.textMuted }
        MouseArea { anchors.fill: parent; enabled: historyIndex < navHistory.length - 1; onClicked: root.goHistory(1) }
    }
    Flickable {
        x: 243; y: 0; width: 1054; height: parent.height; clip: true
        contentWidth: width; contentHeight: body.implicitHeight + 60
        Column {
            id: body; width: parent.width; spacing: 13; topPadding: 46; bottomPadding: 30
            Rectangle {
                width: Metrics.settingsGroupWidth; height: Metrics.settingsHeaderHeight
                radius: Metrics.settingsCardRadius; color: Theme.group
                Rectangle { x: 0; y: 14; width: 3; height: parent.height - 28; radius: 2; color: Theme.accent }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.settingsInset + 4
                    anchors.rightMargin: Metrics.settingsInset
                    spacing: 16
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52; height: 52; radius: 16; color: Theme.accentContainer
                        Icon { anchors.centerIn: parent; name: "tune"; size: Metrics.iconLg; color: Theme.accent }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text { text: root.page; color: Theme.text; font.family: Theme.fonts.settingsTitle.family; font.pixelSize: Theme.fonts.settingsTitle.pixelSize; font.weight: Theme.fonts.settingsTitle.weight }
                        Text { width: 850; text: root.pageDescription(root.page); color: Theme.textSecondary; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize; wrapMode: Text.WordWrap }
                        Text { text: "Changes apply immediately"; color: Theme.accent; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize }
                    }
                }
            }
            Rectangle {
                visible: root.page === "Clock & Date"
                width: Metrics.settingsGroupWidth
                height: Metrics.settingsClockCardHeight
                radius: Metrics.settingsCardRadius
                color: Theme.group
                Column {
                    x: Metrics.settingsInset
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text { text: "Time format"; color: Theme.text; font.family: Theme.fonts.settingsRow.family; font.pixelSize: Theme.fonts.settingsRow.pixelSize; font.weight: Theme.fonts.settingsRow.weight }
                    Text { text: Config.clock.use24h ? "Preview  ·  14:30" : "Preview  ·  2:30 PM"; color: Theme.textSecondary; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.settingsInset
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.settingsFormatOptionGap
                    Repeater {
                        model: [{ label: "24-hour", value: true }, { label: "12-hour", value: false }]
                        delegate: Rectangle {
                            required property var modelData
                            width: Metrics.settingsFormatOptionWidth
                            height: Metrics.settingsFormatOptionHeight
                            radius: height / 2
                            color: Config.clock.use24h === modelData.value ? Theme.accent : Theme.control
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Config.clock.use24h === modelData.value ? Theme.onAccent : Theme.text
                                font.family: Theme.fonts.settingsRow.family
                                font.pixelSize: Theme.fonts.settingsRow.pixelSize
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Config.clock.use24h = modelData.value
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: root.page === "Control Center"; width: 1054; height: 170 + GridLayoutModel.heightFor(root.previewLayout || GridLayoutModel.items) + GridLayoutModel.pitch; radius: 12; color: Theme.group
                Column { x: 15; y: 14; spacing: 14
                    Text { text: "Layout"; color: Theme.textMuted; font.pixelSize: 11 }
                    Row { spacing: 7
                        Repeater { model: [5,6,7,8,9]; delegate: Rectangle { required property int modelData; width: 25; height: 27; radius: 14; color: GridLayoutModel.columns === modelData ? Theme.accent : Theme.control
                            Text { anchors.centerIn: parent; text: modelData; color: GridLayoutModel.columns === modelData ? Theme.onAccent : Theme.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: {
                                if (GridLayoutModel.columns === modelData) return
                                GridLayoutModel.save(GridLayoutModel.fitColumns(GridLayoutModel.items, modelData))
                                Config.controlCenter.columns = modelData
                            } }
                        } }
                        Rectangle { width: 55; height: 27; radius: 14; color: Theme.control
                            Text { anchors.centerIn: parent; text: "Tidy"; color: Theme.text; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: { root.pushUndo(); GridLayoutModel.save(GridLayoutModel.tidy(GridLayoutModel.items, GridLayoutModel.columns)) } }
                        }
                        Rectangle { width: 55; height: 27; radius: 14; color: Theme.control
                            Text { anchors.centerIn: parent; text: "Undo"; color: Theme.text; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: { if (undoStack.length) Config.controlCenter.items = undoStack.pop() } }
                        }
                        Rectangle { width: 55; height: 27; radius: 14; color: Theme.control
                            Text { anchors.centerIn: parent; text: "Reset"; color: Theme.text; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: { root.pushUndo(); GridLayoutModel.reset() } }
                        }
                    }
                    Text { text: "Drag a control to move it · use any edge handle to resize horizontally or vertically"; color: Theme.textMuted; font.pointSize: Theme.pt(10.5) }
                    Item {
                        id: previewArea
                        x: (Metrics.settingsGroupWidth - width) / 2 - 15
                        width: Math.max(550, GridLayoutModel.width)
                        height: GridLayoutModel.heightFor(root.previewLayout || GridLayoutModel.items) + GridLayoutModel.pitch
                        readonly property real gridOffsetX: (width - GridLayoutModel.width) / 2
                        Repeater {
                            model: GridLayoutModel.columns
                            delegate: Rectangle {
                                required property int index
                                x: previewArea.gridOffsetX + GridLayoutModel.pad + index * GridLayoutModel.pitch
                                y: GridLayoutModel.pad + GridLayoutModel.rowsFor(root.previewLayout || GridLayoutModel.items) * GridLayoutModel.pitch
                                width: GridLayoutModel.cell; height: GridLayoutModel.cell
                                radius: width / 2
                                color: Qt.alpha(Theme.text, 0.04)
                            }
                        }
                        Repeater { model: GridLayoutModel.items; delegate: Rectangle {
                            id: previewCell
                            required property var modelData
                            readonly property var previewData: root.previewItem(modelData)
                            readonly property var cellRect: GridLayoutModel.rect(previewData)
                            x: previewArea.gridOffsetX + (resizing ? GridLayoutModel.pad + resizeCellX * GridLayoutModel.pitch : cellRect.x)
                            y: resizing ? GridLayoutModel.pad + resizeCellY * GridLayoutModel.pitch : cellRect.y
                            Behavior on x { enabled: !moving; Spring { token: Motion.panel } }
                            Behavior on y { enabled: !moving; Spring { token: Motion.panel } }
                            Behavior on width { enabled: !resizing; Spring { token: Motion.panel } }
                            Behavior on height { enabled: !resizing; Spring { token: Motion.panel } }
                            radius: 20; color: "transparent"
                            border.width: selected || resizing ? 1 : 0
                            border.color: resizing && !resizeFits ? Theme.danger : Theme.accent
                            readonly property bool selected: root.selectedItem?.id === modelData.id
                            property bool resizing: false
                            property bool moving: false
                            property real resizeWidth: modelData.w
                            property real resizeHeight: modelData.h
                            property real resizeStartX: 0
                            property real resizeStartY: 0
                            property real resizeStartWidth: modelData.w
                            property real resizeStartHeight: modelData.h
                            property int resizeCellX: modelData.x
                            property int resizeCellY: modelData.y
                            property int resizeStartCellX: modelData.x
                            property int resizeStartCellY: modelData.y
                            property string resizeEdge: "bottom-right"
                            readonly property bool resizeFits: root.previewLayout !== null
                            onModelDataChanged: { resizeWidth = modelData.w; resizeHeight = modelData.h }
                            width: resizing ? GridLayoutModel.span(resizeWidth) : cellRect.w
                            height: resizing ? GridLayoutModel.span(resizeHeight) : cellRect.h
                            Loader {
                                id: controlPreview
                                anchors.fill: parent
                                property var spec: previewCell.modelData
                                sourceComponent: spec.kind === "tile" ? tileVisual
                                    : spec.kind === "toggle" ? toggleVisual
                                    : spec.kind === "slider" ? sliderVisual
                                    : spec.kind === "notifications" ? notificationsVisual
                                    : spec.kind === "tray" ? trayVisual
                                    : spec.kind === "nowplaying" ? nowPlayingVisual : null
                            }
                            Component { id: tileVisual; Tile { cid: controlPreview.spec.id; enabled: false } }
                            Component { id: toggleVisual; ToggleCircle { cid: controlPreview.spec.id; enabled: false } }
                            Component { id: sliderVisual; SliderCard { cid: controlPreview.spec.id; enabled: false } }
                            Component { id: notificationsVisual; NotificationsCard { enabled: false } }
                            Component { id: trayVisual; TrayCard { enabled: false } }
                            Component { id: nowPlayingVisual; NowPlayingCard { enabled: false } }
                            Text { anchors.centerIn: parent; visible: !controlPreview.item; text: modelData.id; color: Theme.text; font.pixelSize: 12 }
                            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "◢"; color: Theme.textSecondary; font.pixelSize: 12 }
                            Rectangle { x: -4; y: -4; width: 16; height: 16; radius: 8; color: Theme.danger; visible: parent.selected
                                Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; onClicked: { root.pushUndo(); GridLayoutModel.save(GridLayoutModel.items.filter(i => i.id !== modelData.id)) } }
                            }
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton; drag.target: parent
                                onPressed: parent.moving = true
                                onClicked: mouse => {
                                    selectedItem = modelData
                                }
                                onReleased: {
                                    const nx = Math.max(0, Math.round((parent.x - previewArea.gridOffsetX - GridLayoutModel.pad) / GridLayoutModel.pitch))
                                    const ny = Math.max(0, Math.round((parent.y - GridLayoutModel.pad) / GridLayoutModel.pitch))
                                    const next = GridLayoutModel.reflow(GridLayoutModel.items, modelData, {x:nx,y:ny}, GridLayoutModel.columns)
                                    if (next) { root.pushUndo(); GridLayoutModel.save(next) }
                                    else { parent.x = previewArea.gridOffsetX + GridLayoutModel.pad + modelData.x * GridLayoutModel.pitch; parent.y = GridLayoutModel.pad + modelData.y * GridLayoutModel.pitch; rejected = true; rejectedX = Math.min(width - 100, parent.x); rejectedY = Math.max(0, parent.y - 22); rejectTimer.restart() }
                                    parent.moving = false
                                }
                                onCanceled: parent.moving = false
                            }
                            Repeater {
                                model: ["left", "right", "top", "bottom"]
                                delegate: MouseArea {
                                    required property string modelData
                                    z: 5
                                    acceptedButtons: Qt.LeftButton
                                    visible: previewCell.selected || previewCell.resizing
                                    cursorShape: ["left", "right"].includes(modelData) ? Qt.SizeHorCursor : Qt.SizeVerCursor
                                    width: ["left", "right"].includes(modelData) ? 14 : Math.min(38, previewCell.width * 0.6)
                                    height: ["top", "bottom"].includes(modelData) ? 14 : Math.min(38, previewCell.height * 0.6)
                                    x: modelData === "left" ? -7 : modelData === "right" ? previewCell.width - 7 : (previewCell.width - width) / 2
                                    y: modelData === "top" ? -7 : modelData === "bottom" ? previewCell.height - 7 : (previewCell.height - height) / 2
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: ["left", "right"].includes(modelData) ? 4 : Math.min(28, parent.width - 8)
                                        height: ["top", "bottom"].includes(modelData) ? 4 : Math.min(28, parent.height - 8)
                                        radius: 3
                                        color: Theme.accent
                                    }
                                    onPressed: mouse => {
                                        root.selectedItem = previewCell.modelData
                                        previewCell.resizing = true
                                        previewCell.resizeEdge = modelData
                                        root.previewLayout = GridLayoutModel.items
                                        previewCell.resizeStartWidth = previewCell.modelData.w
                                        previewCell.resizeStartHeight = previewCell.modelData.h
                                        previewCell.resizeStartCellX = previewCell.modelData.x
                                        previewCell.resizeStartCellY = previewCell.modelData.y
                                        previewCell.resizeCellX = previewCell.modelData.x
                                        previewCell.resizeCellY = previewCell.modelData.y
                                        const point = mapToItem(previewArea, mouse.x, mouse.y)
                                        previewCell.resizeStartX = point.x
                                        previewCell.resizeStartY = point.y
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressed) return
                                        const point = mapToItem(previewArea, mouse.x, mouse.y)
                                        const dx = Math.round((point.x - previewCell.resizeStartX) / GridLayoutModel.pitch)
                                        const dy = Math.round((point.y - previewCell.resizeStartY) / GridLayoutModel.pitch)
                                        let x = previewCell.resizeStartCellX
                                        let y = previewCell.resizeStartCellY
                                        let w = previewCell.resizeStartWidth
                                        let h = previewCell.resizeStartHeight
                                        if (modelData === "left") { w -= dx; x = previewCell.resizeStartCellX + previewCell.resizeStartWidth - w }
                                        else if (modelData === "right") w += dx
                                        else if (modelData === "top") { h -= dy; y = previewCell.resizeStartCellY + previewCell.resizeStartHeight - h }
                                        else h += dy
                                        const size = GridLayoutModel.clampSize(previewCell.modelData.id, previewCell.modelData.kind,
                                            w, h, Math.max(0, x), Math.max(0, y), GridLayoutModel.columns)
                                        w = size.w; h = size.h
                                        if (modelData === "left") x = Math.max(0, previewCell.resizeStartCellX + previewCell.resizeStartWidth - w)
                                        if (modelData === "top") y = Math.max(0, previewCell.resizeStartCellY + previewCell.resizeStartHeight - h)
                                        if (x === 0 && modelData === "left") w = Math.min(w, previewCell.resizeStartCellX + previewCell.resizeStartWidth)
                                        if (y === 0 && modelData === "top") h = Math.min(h, previewCell.resizeStartCellY + previewCell.resizeStartHeight)
                                        previewCell.resizeWidth = w
                                        previewCell.resizeHeight = h
                                        previewCell.resizeCellX = x
                                        previewCell.resizeCellY = y
                                        root.previewLayout = GridLayoutModel.resizeLayout(GridLayoutModel.items, previewCell.modelData,
                                            w, h, GridLayoutModel.columns, x, y)
                                    }
                                    onReleased: previewCell.finishResize()
                                    onCanceled: { previewCell.resizing = false; root.previewLayout = null }
                                }
                            }
                            function finishResize(): void {
                                if (root.previewLayout && (resizeWidth !== modelData.w || resizeHeight !== modelData.h || resizeCellX !== modelData.x || resizeCellY !== modelData.y)) {
                                    root.pushUndo()
                                    GridLayoutModel.save(root.previewLayout)
                                } else if (!root.previewLayout) {
                                    rejected = true
                                    rejectedX = Math.min(previewArea.width - 100, x)
                                    rejectedY = Math.max(0, y - 22)
                                    rejectTimer.restart()
                                }
                                resizing = false
                                root.previewLayout = null
                            }
                        } }
                        Text { x: root.rejectedX; y: root.rejectedY; visible: rejected; text: "Doesn't fit here"; color: Theme.danger; font.pointSize: Theme.pt(10.5) }
                    }
                    Row { spacing: 6
                        Repeater { model: Object.keys(GridLayoutModel.capabilities).filter(k => !GridLayoutModel.items.some(i => i.id === k)); delegate: Rectangle { required property string modelData; width: 110; height: 32; radius: 16; color: Theme.control
                            Text { anchors.centerIn: parent; text: "+ " + modelData; color: Theme.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: { const cap = GridLayoutModel.capabilities[modelData][0]; const p = GridLayoutModel.firstFree(GridLayoutModel.items, cap[1], cap[3], GridLayoutModel.columns); if (p) { root.pushUndo(); GridLayoutModel.save(GridLayoutModel.items.concat([{id:modelData,kind:cap[0],x:p.x,y:p.y,w:cap[1],h:cap[3]}])) } } }
                        } }
                    }
                }
            }
            Rectangle {
                visible: root.page === "Weather"; width: 1054; height: 286; radius: 12; color: Theme.group
                Column { x: 16; y: 14; width: parent.width - 32; spacing: 9
                    Text { text: "Location"; color: Theme.text; font.pixelSize: 12 }
                    Text { text: Config.weather.place || (Config.weather.lat !== null ? "Saved coordinates" : "No location selected"); color: Theme.textSecondary; font.pixelSize: 10 }
                    TextInput { id: locationQuery; width: 420; height: 30; color: Theme.text; font.pixelSize: 12
                        Rectangle { z: -1; anchors.fill: parent; radius: 8; color: Theme.field }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; leftPadding: 9; visible: !locationQuery.text; text: "Search a city"; color: Theme.textMuted; font.pixelSize: 11 }
                        onTextChanged: geocodeTimer.restart()
                    }
                    Timer { id: geocodeTimer; interval: 350; onTriggered: Weather.searchLocation(locationQuery.text) }
                    Row { spacing: 6
                        Repeater { model: Weather.locations; delegate: Rectangle { required property var modelData; width: 190; height: 30; radius: 8; color: Theme.card
                            Text { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; text: [modelData.name, modelData.admin1, modelData.country].filter(Boolean).join(", "); color: Theme.text; font.pixelSize: 10; elide: Text.ElideRight }
                            MouseArea { anchors.fill: parent; onClicked: Weather.chooseLocation(modelData) }
                        } }
                    }
                    Row { spacing: 8
                        Text { text: "Units"; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Repeater { model: [{label:"°C", value:"celsius"},{label:"°F", value:"fahrenheit"}]; delegate: Rectangle { required property var modelData; width: 48; height: 26; radius: 13; color: Config.weather.units === modelData.value ? Theme.accent : Theme.control
                            Text { anchors.centerIn: parent; text: modelData.label; color: Config.weather.units === modelData.value ? Theme.onAccent : Theme.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: { Config.weather.units = modelData.value; Weather.refresh() } }
                        } }
                    }
                    Row { spacing: 24
                        Row { spacing: 8
                            Text { text: "Calendar"; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Switch { checked: Config.weather.inCalendar; onToggled: Config.weather.inCalendar = checked }
                        }
                        Row { spacing: 8
                            Text { text: "Hover clock"; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Switch { checked: Config.weather.inHoverClock; onToggled: Config.weather.inHoverClock = checked }
                        }
                        Row { spacing: 8
                            Text { text: "Lock screen"; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Switch { checked: Config.weather.onLockScreen; onToggled: Config.weather.onLockScreen = checked }
                        }
                    }
                }
            }
            Rectangle {
                visible: root.page === "System monitor"; width: 1054; height: 106; radius: 12; color: Theme.group
                Column { x: 16; y: 14; spacing: 10
                    Text { text: "Temperature sensor"; color: Theme.text; font.pixelSize: 12 }
                    Row { spacing: 7
                        Repeater { model: SysStats.sensors; delegate: Rectangle { required property string modelData; width: 130; height: 28; radius: 14; color: Config.sysmon.tempSensor === modelData ? Theme.accent : Theme.control
                            Text { anchors.centerIn: parent; text: modelData === "auto" ? "Auto" : modelData; color: Config.sysmon.tempSensor === modelData ? Theme.onAccent : Theme.text; font.pixelSize: 10 }
                            MouseArea { anchors.fill: parent; onClicked: Config.sysmon.tempSensor = modelData }
                        } }
                    }
                }
            }
            Rectangle {
                visible: root.page === "Power & Battery"; width: 1054; height: 228; radius: 12; color: Theme.group
                Column { x: 16; y: 12; spacing: 10
                    Row { spacing: 12
                        Text { text: "Automatic power profiles"; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Switch { checked: Config.power.auto; onToggled: Config.power.auto = checked }
                    }
                    Row { spacing: 6
                        Text { text: "Lock after"; width: 110; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Repeater { model: [{label:"Never",seconds:0},{label:"1m",seconds:60},{label:"2m",seconds:120},{label:"5m",seconds:300},{label:"10m",seconds:600},{label:"15m",seconds:900},{label:"30m",seconds:1800}]; delegate: Rectangle { required property var modelData; width: 54; height: 25; radius: 13; color: Config.idle.lockAfter === modelData.seconds ? Theme.accent : Theme.control
                            Text { anchors.centerIn: parent; text: modelData.label; color: Config.idle.lockAfter === modelData.seconds ? Theme.onAccent : Theme.text; font.pixelSize: 10 }
                            MouseArea { anchors.fill: parent; onClicked: Config.idle.lockAfter = modelData.seconds }
                        } }
                    }
                    Row { spacing: 6
                        Text { text: "Screen off after"; width: 110; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Repeater { model: [{label:"Never",seconds:0},{label:"1m",seconds:60},{label:"2m",seconds:120},{label:"5m",seconds:300},{label:"10m",seconds:600},{label:"15m",seconds:900},{label:"30m",seconds:1800}]; delegate: Rectangle { required property var modelData; width: 54; height: 25; radius: 13; color: Config.idle.screenOffAfter === modelData.seconds ? Theme.accent : Theme.control
                            Text { anchors.centerIn: parent; text: modelData.label; color: Config.idle.screenOffAfter === modelData.seconds ? Theme.onAccent : Theme.text; font.pixelSize: 10 }
                            MouseArea { anchors.fill: parent; onClicked: Config.idle.screenOffAfter = modelData.seconds }
                        } }
                    }
                    Row { spacing: 20
                        Row { spacing: 8
                            Text { text: "Block suspend"; color: Theme.text; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                            Switch { checked: Config.caffeine.blockSleep; onToggled: Config.caffeine.blockSleep = checked }
                        }
                        Row { spacing: 8
                            Text { text: "While media plays"; color: Theme.text; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                            Switch { checked: Config.caffeine.whilePlaying; onToggled: Config.caffeine.whilePlaying = checked }
                        }
                        Row { spacing: 8
                            Text { text: "In game mode"; color: Theme.text; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                            Switch { checked: Config.caffeine.inGameMode; onToggled: Config.caffeine.inGameMode = checked }
                        }
                    }
                }
            }
            Repeater {
                model: root.rowsFor(root.page)
                delegate: Rectangle {
                    required property var modelData
                    width: Metrics.settingsGroupWidth; height: Metrics.settingsRowHeight; radius: Metrics.settingsCardRadius; color: Theme.group
                    Rectangle { x: 0; y: 15; width: 2; height: parent.height - 30; radius: 1; color: Theme.accent }
                    Column {
                        x: Metrics.settingsInset; width: Math.max(245, parent.width * 0.34); anchors.verticalCenter: parent.verticalCenter; spacing: 5
                        Text { text: modelData.group.toUpperCase(); color: Theme.accent; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize; font.weight: Font.DemiBold }
                        Text { text: modelData.label; color: Theme.text; font.family: Theme.fonts.settingsRow.family; font.pixelSize: Theme.fonts.settingsRow.pixelSize; font.weight: Theme.fonts.settingsRow.weight }
                        Text { width: parent.width; text: modelData.help; color: Theme.textSecondary; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                    }
                    Slider {
                        anchors.right: valueBadge.left; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(Metrics.settingsSliderWidthMax, Math.max(Metrics.settingsSliderWidthMin, parent.width * 0.44))
                        height: Metrics.settingsSliderHitHeight; trackThickness: Metrics.sliderTrackThickness
                        value: (modelData.value - modelData.min) / (modelData.max - modelData.min)
                        onMoved: nextValue => root.write(modelData.path, modelData.min + nextValue * (modelData.max - modelData.min))
                    }
                    Rectangle {
                        id: valueBadge
                        anchors.right: parent.right; anchors.rightMargin: Metrics.settingsInset; anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 32; radius: 10; color: Theme.accentContainer
                        Text { anchors.centerIn: parent; text: root.formatSetting(modelData.value, modelData.unit); color: Theme.accent; font.family: Theme.fonts.settingsRow.family; font.pixelSize: Theme.fonts.settingsRow.pixelSize; font.weight: Font.DemiBold }
                    }
                }
            }
            Rectangle {
                visible: root.page === "Appearance"
                width: Metrics.settingsGroupWidth
                height: appearanceContent.implicitHeight + 32
                color: Theme.group
                radius: Metrics.settingsCardRadius
                Column {
                    id: appearanceContent
                    x: 16; y: 16; width: parent.width - 32; spacing: 18
                    Grid {
                        id: themeCards
                        columns: 4
                        spacing: 14
                        Repeater { model: Themes.list; delegate: Rectangle {
                        required property var modelData
                        readonly property bool applied: Config.appearance.theme === modelData.name
                        width: 220; height: 86; radius: Metrics.themeCardRadius
                        color: modelData.panel ?? Theme.panel
                        border.width: applied ? 2 : 0
                        border.color: modelData.accent ?? Theme.accent

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 28 - Metrics.themeDot / 2
                            spacing: Metrics.themeDotGap
                            Repeater {
                                model: modelData.preview ?? []
                                delegate: Rectangle {
                                    required property string modelData
                                    width: Metrics.themeDot; height: Metrics.themeDot
                                    radius: width / 2
                                    color: modelData
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 53
                            text: modelData.label
                            color: applied ? (modelData.text ?? Theme.text) : (modelData.textSecondary ?? Theme.textSecondary)
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: applied ? Font.DemiBold : Font.Medium
                        }
                        Rectangle {
                            x: parent.width - 12 - width / 2
                            y: 10 - height / 2
                            width: Metrics.themeMarker; height: Metrics.themeMarker
                            radius: width / 2
                            color: modelData.accent ?? Theme.accent
                            visible: applied
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Themes.apply(modelData.name)
                            }
                        }
                        } }
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        Column {
                            width: parent.width - resetAll.width - 12
                            spacing: 4
                            Text { text: "Theme colors"; color: Theme.text; font.family: Theme.fonts.settingsRow.family; font.pixelSize: Theme.fonts.settingsTitle.pixelSize; font.weight: Font.DemiBold }
                            Text { text: "Tune shell colors, terminal colors, and supported app palettes. Enter a #RRGGBB value."; color: Theme.textSecondary; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize }
                        }
                        Rectangle {
                            id: resetAll
                            width: 144; height: 34; radius: 17
                            color: Theme.control
                            Text { anchors.centerIn: parent; text: "Reset theme colors"; color: Theme.text; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize }
                            MouseArea { anchors.fill: parent; onClicked: Themes.resetThemeOverrides() }
                        }
                    }
                    Grid {
                        id: colorEditorGrid
                        columns: 2
                        columnSpacing: Metrics.themeEditorColumnGap
                        rowSpacing: Metrics.themeEditorRowGap
                        width: parent.width
                        height: Math.ceil(colorEditorRepeater.count / columns) * (Metrics.themeEditorRowHeight + rowSpacing) - rowSpacing
                        Repeater {
                            id: colorEditorRepeater
                            model: root.appearanceColorRows()
                            delegate: Rectangle {
                                required property var modelData
                                width: (colorEditorGrid.width - Metrics.themeEditorColumnGap) / 2
                                height: Metrics.themeEditorRowHeight
                                radius: 9
                                color: Theme.card
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Column {
                                        width: Math.max(90, parent.width - Metrics.themeEditorSwatchSize - Metrics.themeEditorFieldWidth - 42)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text { text: modelData.label; color: Theme.text; font.family: Theme.fonts.caption.family; font.pixelSize: Theme.fonts.caption.pixelSize; elide: Text.ElideRight; width: parent.width }
                                        Text { text: modelData.group; color: Theme.textMuted; font.family: Theme.fonts.caption.family; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Metrics.themeEditorSwatchSize; height: Metrics.themeEditorSwatchSize
                                        radius: 7; color: modelData.value
                                        border.width: 1; border.color: Theme.divider
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Metrics.themeEditorFieldWidth; height: 28
                                        radius: 7; color: Theme.field
                                        TextInput {
                                            anchors.fill: parent
                                            anchors.leftMargin: 7; anchors.rightMargin: 7
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: modelData.value
                                            color: Theme.text
                                            selectionColor: Theme.accent
                                            selectedTextColor: Theme.onAccent
                                            font.family: Theme.fonts.code.family
                                            font.pixelSize: 10
                                            selectByMouse: true
                                            onEditingFinished: {
                                                if (!Themes.setColorOverride(modelData.key, text)) text = modelData.value
                                            }
                                        }
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 24; height: 24; radius: 12
                                        color: modelData.overridden ? Theme.accentContainer : "transparent"
                                        Text { anchors.centerIn: parent; text: "↺"; color: modelData.overridden ? Theme.accent : Theme.textMuted; font.pixelSize: 15 }
                                        MouseArea { anchors.fill: parent; enabled: modelData.overridden; onClicked: Themes.resetColorOverride(modelData.key) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle { visible: root.page === "Motion"; width: 1054; height: 150; radius: 12; color: Theme.group
                Text { x: 18; y: 14; text: "Live spring preview"; color: Theme.text; font.pixelSize: 13 }
                Rectangle { id: previewRect; x: previewToggle ? 800 : 30; y: 63; width: previewToggle ? 220 : 96; height: previewToggle ? 72 : 33; radius: height/2; color: Theme.island
                    Behavior on x { Spring { token: Motion.island; epsilon: 0.01 } }
                    Behavior on width { Spring { token: Motion.island; epsilon: 0.01 } }
                    Behavior on height { Spring { token: Motion.island; epsilon: 0.01 } }
                }
                Timer { interval: 1500; repeat: true; running: root.page === "Motion"; onTriggered: previewToggle = !previewToggle }
            }
        }
    }
    property var undoStack: []
    property var navHistory: ["Bar & Island"]
    property int historyIndex: 0
    property var selectedItem: null
    property var previewLayout: null
    property bool previewToggle: false
    property bool rejected: false
    property real rejectedX: 0
    property real rejectedY: 0
    Timer { id: rejectTimer; interval: 700; onTriggered: root.rejected = false }
    function write(path, val) { const parts = path.split("."); let o = Config; for (let i=0;i<parts.length-1;i++) o=o[parts[i]]; o[parts[parts.length-1]]=val }
    function pageDescription(p) {
        return ({
            "Bar & Island": "Tune the island size, spacing, and game mode layout.",
            "Clock & Date": "Choose how time and date information appears.",
            "Appearance": "Choose a theme and tune its shell, terminal, and supported app colors.",
            "Motion": "Adjust spring behavior and reduce motion effects.",
            "Launcher": "Control how many matching apps appear in launcher results.",
            "Notifications": "Set how long notification cards remain visible.",
            "Control Center": "Arrange cards and resize each control with its edge handles.",
            "Lock Screen": "Set the background blur used by the lock screen.",
            "System": "Manage system integration and idle behavior.",
            "Wallpaper": "Configure wallpaper transitions and automatic changes.",
            "Clipboard": "Set how many recent clipboard items are kept in the panel.",
            "Power & Battery": "Choose when Dynamite switches to power saver.",
            "Weather": "Choose a location and how weather is shown.",
            "System monitor": "Set the temperature threshold used for warnings."
        })[p] || "Configure this part of Dynamite. Changes apply immediately."
    }
    function appearanceColorRows(): var {
        const selected = Themes.list.find(theme => theme.name === Config.appearance.theme)
        if (!selected) return []
        const all = Config.appearance.colorOverrides || {}
        const current = all[Config.appearance.theme] || {}
        const rows = []
        for (const key in Theme.defaults) {
            rows.push({
                key,
                label: key.replace(/([A-Z])/g, " $1").replace(/^./, value => value.toUpperCase()),
                group: "SHELL",
                value: current[key] || selected.colors?.[key] || Theme.defaults[key],
                overridden: !!current[key]
            })
        }
        const appRoles = [
            ["appBackground", "App background"], ["appForeground", "App foreground"],
            ["appAccent", "App accent"], ["appSelection", "App selection"], ["appCursor", "App cursor"]
        ]
        for (let roleIndex = 0; roleIndex < appRoles.length; ++roleIndex) {
            const role = appRoles[roleIndex]
            const key = role[0]
            const label = role[1]
            const fallback = key === "appBackground" ? selected.colors?.window
                : key === "appForeground" ? selected.colors?.text
                : key === "appAccent" ? selected.colors?.accent
                : key === "appSelection" ? selected.colors?.accentContainer
                : selected.colors?.accent
            rows.push({ key, label, group: "APPLICATIONS", value: current[key] || fallback || "#000000", overridden: !!current[key] })
        }
        for (let index = 0; index < 16; ++index) {
            const key = `color${index}`
            rows.push({ key, label: `Terminal color ${index}`, group: "ANSI PALETTE",
                value: current[key] || selected.ansi?.[index] || selected.baseAnsi?.[index] || "#000000",
                overridden: !!current[key] })
        }
        return rows
    }
    function navigateTo(p: string): void {
        if (p === page) return
        navHistory = navHistory.slice(0, historyIndex + 1).concat([p])
        historyIndex = navHistory.length - 1
        page = p
    }
    function goHistory(delta: int): void {
        const next = Math.max(0, Math.min(navHistory.length - 1, historyIndex + delta))
        historyIndex = next
        page = navHistory[next]
    }
    function filteredPages(): var {
        if (!query.trim()) return pages
        const needle = query.trim().toLowerCase()
        return pages.filter(p => p.toLowerCase().includes(needle)
            || pageDescription(p).toLowerCase().includes(needle)
            || rowsFor(p).some(row => (row.label + " " + row.help + " " + row.group).toLowerCase().includes(needle)))
    }
    function jumpToMatch(text: string): void {
        const needle = text.trim().toLowerCase()
        if (!needle) return
        const matches = filteredPages()
        if (matches.length && !matches.includes(page)) navigateTo(matches[0])
    }
    function formatSetting(value: real, unit: string): string {
        const digits = Math.abs(value - Math.round(value)) > 0.001 ? 1 : 0
        return Number(value).toFixed(digits) + (unit ? " " + unit : "")
    }
    function previewItem(item) {
        if (!previewLayout) return item
        return previewLayout.find(i => i.id === item.id) || item
    }
    function pushUndo() { undoStack = undoStack.concat([GridLayoutModel.items.slice()]).slice(-20) }
    function rowsFor(p) {
        const defs = {
          "Bar & Island":[
            ["Bar height","island.barHeight",20,48,"Bar geometry","Height of the compact bar and its click targets.","px"],
            ["Collapsed width","island.collapsedWidth",60,200,"Bar geometry","Width of the centered collapsed island.","px"],
            ["Gap from screen edge","island.gap",0,30,"Bar geometry","Distance between the island and top screen edge.","px"],
            ["Inner padding","island.innerPadding",0,8,"Bar geometry","Space between island content and its edge.","px"],
            ["Corner radius","island.radius",0,24,"Bar geometry","Roundness of the compact island corners.","px"],
            ["Expanded height","island.expandedHeight",90,200,"Expanded island","Height used by expanded island panels.","px"],
            ["Expanded radius","island.radiusExpanded",12,40,"Expanded island","Roundness of expanded panel corners.","px"],
            ["Stage lift","island.stageLift",0,16,"Expanded island","Vertical offset used while panels open.","px"],
            ["Game bar height","gameMode.barHeight",32,64,"Game mode","Height of the island while game mode is active.","px"],
            ["Game cluster gap","gameMode.clusterGap",80,400,"Game mode","Spacing between game mode bar clusters.","px"]],
          "Motion":[
            ["Island spring","motion.islandSpring",1,12,"Island motion","Spring strength for island size and position changes.",""],
            ["Island damping","motion.islandDamping",0.1,1,"Island motion","Damping for island movement; lower values bounce more.",""],
            ["Panel spring","motion.panelSpring",1,12,"Panel motion","Spring strength for panels and layout changes.",""],
            ["Panel damping","motion.panelDamping",0.1,1,"Panel motion","Damping for panel movement; lower values bounce more.",""],
            ["Fade spring","motion.fadeSpring",1,12,"Fade motion","Spring strength for opacity transitions.",""],
            ["Fade damping","motion.fadeDamping",0.1,1,"Fade motion","Damping for opacity transitions.",""]],
          "Launcher":[["Max results","launcher.maxResults",4,10,"Search results","Maximum matching apps shown at once.","apps"]],
          "Notifications":[["Toast duration","notifications.toastSeconds",2,10,"Notification timing","How long toast notifications stay visible.","sec"]],
          "Lock Screen":[["Blur radius","lock.blur",0,96,"Background effect","Blur strength applied to the lock screen background.","px"]],
          "Power & Battery":[["Power saver at","power.saverAt",20,80,"Automatic profile","Battery level that triggers power saver mode.","%"]],
          "System monitor":[["Warning temperature","sysmon.warnTemp",70,100,"Temperature warning","CPU temperature threshold for a warning state.","°C"]],
          "Wallpaper":[
            ["Transition length","wallpaper.transitionSeconds",0.3,3,"Wallpaper transition","Duration of the crossfade when changing wallpapers.","sec"],
            ["Slideshow minutes","wallpaper.slideshowMinutes",0,60,"Automatic slideshow","Minutes between wallpaper changes. Zero disables the slideshow.","min"]],
          "Clipboard":[["Items shown","clipboard.maxItems",20,500,"History size","Maximum number of clipboard entries kept in history.","items"]], "Weather":[]
        }[p] || []
        const needle = query.trim().toLowerCase()
        return defs.filter(d => !needle || (d[0] + " " + d[4] + " " + d[5]).toLowerCase().includes(needle))
            .map(d => { const parts=d[1].split("."); return {label:d[0],path:d[1],min:d[2],max:d[3],group:d[4],help:d[5],unit:d[6],value:Config[parts[0]][parts[1]]} })
    }
}
