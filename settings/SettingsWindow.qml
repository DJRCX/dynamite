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
        Qt.callLater(() => { root.page = page; root.visible = true })
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
            text: root.query; onTextChanged: root.query = text
            Rectangle { z: -1; anchors.fill: parent; radius: 9; color: Theme.field }
            Text { anchors.centerIn: parent; visible: !parent.text; text: "Search Settings"; color: Theme.textMuted; font.pixelSize: 12 }
        }
        Column {
            x: 17; y: 54; width: 198; spacing: 5
            Repeater {
                model: root.pages.filter(p => !root.query || p.toLowerCase().includes(root.query.toLowerCase()))
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
                    MouseArea { anchors.fill: parent; onClicked: root.page = modelData }
                }
            }
        }
    }
    Icon { x: 248; y: 14; name: "chevron_left"; size: Metrics.iconMd; color: Theme.text }
    Icon { x: 284; y: 14; name: "chevron_right"; size: Metrics.iconMd; color: Theme.text }
    Flickable {
        x: 243; y: 0; width: 1054; height: parent.height; clip: true
        contentWidth: width; contentHeight: body.implicitHeight + 60
        Column {
            id: body; width: parent.width; spacing: 13; topPadding: 46; bottomPadding: 30
            Rectangle {
                width: 1054; height: 156; radius: 12; color: Theme.group
                Column { anchors.centerIn: parent; spacing: 10
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; radius: 28; color: Theme.accentContainer
                        Icon { anchors.centerIn: parent; name: "settings"; size: Metrics.iconLg; color: Theme.accent }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.page; color: Theme.text; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Configure Dynamite. Changes apply immediately."; color: Theme.textSecondary; font.pixelSize: 12 }
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
                visible: root.page === "Control Center"; width: 1054; height: 170 + GridLayoutModel.mainHeight + GridLayoutModel.pitch; radius: 12; color: Theme.group
                Column { x: 15; y: 14; spacing: 14
                    Text { text: "Layout"; color: Theme.textMuted; font.pixelSize: 11 }
                    Row { spacing: 7
                        Repeater { model: [5,6,7,8,9]; delegate: Rectangle { required property int modelData; width: 25; height: 27; radius: 14; color: GridLayoutModel.columns === modelData ? Theme.accent : Theme.control
                            Text { anchors.centerIn: parent; text: modelData; color: GridLayoutModel.columns === modelData ? Theme.onAccent : Theme.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: Config.controlCenter.columns = modelData }
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
                    Text { text: "Drag to move · drag the bottom-right corner to resize freely"; color: Theme.textMuted; font.pointSize: Theme.pt(10.5) }
                    Item {
                        id: previewArea
                        x: (Metrics.settingsGroupWidth - width) / 2 - 15
                        width: Math.max(550, GridLayoutModel.width)
                        height: GridLayoutModel.mainHeight + GridLayoutModel.pitch
                        readonly property real gridOffsetX: (width - GridLayoutModel.width) / 2
                        Repeater {
                            model: GridLayoutModel.columns
                            delegate: Rectangle {
                                required property int index
                                x: previewArea.gridOffsetX + GridLayoutModel.pad + index * GridLayoutModel.pitch
                                y: GridLayoutModel.pad + GridLayoutModel.rows * GridLayoutModel.pitch
                                width: GridLayoutModel.cell; height: GridLayoutModel.cell
                                radius: width / 2
                                color: Qt.alpha(Theme.text, 0.04)
                            }
                        }
                        Repeater { model: GridLayoutModel.items; delegate: Rectangle {
                            id: previewCell
                            required property var modelData
                            readonly property var cellRect: GridLayoutModel.rect(modelData)
                            x: previewArea.gridOffsetX + cellRect.x
                            y: cellRect.y
                            Behavior on x { Spring { token: Motion.panel } }
                            Behavior on y { Spring { token: Motion.panel } }
                            radius: 20; color: "transparent"
                            border.width: selected || resizing ? 1 : 0
                            border.color: resizing && !resizeFits ? Theme.danger : Theme.accent
                            property bool selected: false
                            property bool resizing: false
                            property real resizeWidth: modelData.w
                            property real resizeHeight: modelData.h
                            property real resizeStartX: 0
                            property real resizeStartY: 0
                            property real resizeStartWidth: modelData.w
                            property real resizeStartHeight: modelData.h
                            readonly property bool resizeFits: GridLayoutModel.canPlace(Object.assign({}, modelData, {w: resizeWidth, h: resizeHeight}), modelData.x, modelData.y)
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
                                onClicked: mouse => {
                                    parent.selected = true; selectedItem = modelData
                                }
                                onReleased: {
                                    const nx = Math.max(0, Math.round((parent.x - previewArea.gridOffsetX - GridLayoutModel.pad) / GridLayoutModel.pitch))
                                    const ny = Math.max(0, Math.round((parent.y - GridLayoutModel.pad) / GridLayoutModel.pitch))
                                    const next = GridLayoutModel.reflow(GridLayoutModel.items, modelData, {x:nx,y:ny}, GridLayoutModel.columns)
                                    if (next) { root.pushUndo(); GridLayoutModel.save(next) }
                                    else { parent.x = previewArea.gridOffsetX + GridLayoutModel.pad + modelData.x * GridLayoutModel.pitch; parent.y = GridLayoutModel.pad + modelData.y * GridLayoutModel.pitch; rejected = true; rejectedX = Math.min(width - 100, parent.x); rejectedY = Math.max(0, parent.y - 22); rejectTimer.restart() }
                                }
                            }
                            MouseArea {
                                x: parent.width - 18; y: parent.height - 18; width: 18; height: 18
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.SizeFDiagCursor
                                onPressed: mouse => {
                                    parent.resizing = true
                                    parent.resizeStartWidth = modelData.w
                                    parent.resizeStartHeight = modelData.h
                                    const point = mapToItem(previewArea, mouse.x, mouse.y)
                                    parent.resizeStartX = point.x
                                    parent.resizeStartY = point.y
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return
                                    const point = mapToItem(previewArea, mouse.x, mouse.y)
                                    parent.resizeWidth = Math.max(0.5, Math.min(GridLayoutModel.columns - modelData.x,
                                        parent.resizeStartWidth + (point.x - parent.resizeStartX) / GridLayoutModel.pitch))
                                    parent.resizeHeight = Math.max(0.5, Math.min(64 - modelData.y,
                                        parent.resizeStartHeight + (point.y - parent.resizeStartY) / GridLayoutModel.pitch))
                                }
                                onReleased: {
                                    parent.resizing = false
                                    if (Math.abs(parent.resizeWidth - modelData.w) > 0.001 || Math.abs(parent.resizeHeight - modelData.h) > 0.001)
                                        root.resizeItem(modelData, parent.resizeWidth, parent.resizeHeight, modelData.kind)
                                }
                                onCanceled: parent.resizing = false
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
                    width: 1054; height: 60; radius: 12; color: Theme.group
                    Text { x: 15; y: 11; text: modelData.label; color: Theme.text; font.family: "Inter"; font.pixelSize: 12 }
                    Text { x: 15; y: 36; text: modelData.valueText; color: Theme.textSecondary; font.pointSize: Theme.pt(10.5) }
                    Slider { x: 400; y: 17; width: 620; height: Metrics.settingsSliderHitHeight; trackThickness: Metrics.sliderTrackThickness; value: (modelData.value - modelData.min) / (modelData.max - modelData.min); onMoved: nextValue => root.write(modelData.path, modelData.min + nextValue * (modelData.max - modelData.min)) }
                    Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.value); color: Theme.textSecondary; font.pixelSize: 11 }
                }
            }
            Rectangle { visible: root.page === "Appearance"; width: 1054; height: 480; color: Theme.group; radius: 12
                Grid { anchors.centerIn: parent; columns: 4; spacing: 14
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
            }
            Rectangle { visible: root.page === "Motion"; width: 1054; height: 150; radius: 12; color: Theme.group
                Text { x: 18; y: 14; text: "Live spring preview"; color: Theme.text; font.pixelSize: 13 }
                Rectangle { id: previewRect; x: previewToggle ? 800 : 30; y: 63; width: previewToggle ? 220 : 96; height: previewToggle ? 72 : 33; radius: height/2; color: Theme.island
                    Behavior on x { SpringAnimation { spring: Config.motion.islandSpring; damping: Config.motion.islandDamping; epsilon: 0.01 } }
                    Behavior on width { SpringAnimation { spring: Config.motion.islandSpring; damping: Config.motion.islandDamping; epsilon: 0.01 } }
                    Behavior on height { SpringAnimation { spring: Config.motion.islandSpring; damping: Config.motion.islandDamping; epsilon: 0.01 } }
                }
                Timer { interval: 1500; repeat: true; running: root.page === "Motion"; onTriggered: previewToggle = !previewToggle }
            }
        }
    }
    property var undoStack: []
    property var selectedItem: null
    property bool previewToggle: false
    property bool rejected: false
    property real rejectedX: 0
    property real rejectedY: 0
    Timer { id: rejectTimer; interval: 700; onTriggered: root.rejected = false }
    function write(path, val) { const parts = path.split("."); let o = Config; for (let i=0;i<parts.length-1;i++) o=o[parts[i]]; o[parts[parts.length-1]]=val }
    function pushUndo() { undoStack = undoStack.concat([GridLayoutModel.items.slice()]).slice(-20) }
    function resizeItem(item, w, h, kind) {
        const updated=Object.assign({},item,{w:w,h:h,kind:kind})
        const next=GridLayoutModel.items.map(i => i.id===item.id ? updated : i)
        if (GridLayoutModel.canPlace(updated,item.x,item.y)) { pushUndo(); GridLayoutModel.save(next) }
        else { rejected=true; rejectTimer.restart() }
    }
    function rowsFor(p) {
        const defs = {
          "Bar & Island":[["Bar height","island.barHeight",20,48],["Collapsed width","island.collapsedWidth",60,200],["Expanded height","island.expandedHeight",90,200],["Gap from screen edge","island.gap",0,30],["Inner padding","island.innerPadding",0,8],["Corner radius","island.radius",0,24],["Expanded radius","island.radiusExpanded",12,40],["Stage lift","island.stageLift",0,16],["Game bar height","gameMode.barHeight",32,64],["Game cluster gap","gameMode.clusterGap",80,400]],
          "Motion":[["Island spring","motion.islandSpring",1,12],["Island damping","motion.islandDamping",0.1,1],["Panel spring","motion.panelSpring",1,12],["Panel damping","motion.panelDamping",0.1,1],["Fade spring","motion.fadeSpring",1,12],["Fade damping","motion.fadeDamping",0.1,1]],
          "Launcher":[["Max results","launcher.maxResults",4,10]], "Notifications":[["Toast duration","notifications.toastSeconds",2,10]], "Lock Screen":[["Blur radius","lock.blur",0,96]],
          "Power & Battery":[["Power saver at","power.saverAt",20,80]], "System monitor":[["Warning temperature","sysmon.warnTemp",70,100]],
          "Wallpaper":[["Transition length","wallpaper.transitionSeconds",0.3,3],["Slideshow minutes","wallpaper.slideshowMinutes",0,60]],
          "Clipboard":[["Items shown","clipboard.maxItems",20,500]], "Weather":[]
        }[p] || []
        return defs.map(d => { const parts=d[1].split("."); return {label:d[0],path:d[1],min:d[2],max:d[3],value:Config[parts[0]][parts[1]],valueText:""} })
    }
}
