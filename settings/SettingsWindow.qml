import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.controlcenter
import qs.services
import qs.state
import qs.theme

FloatingWindow {
    id: root
    title: "Dynamite Settings"
    visible: false
    implicitWidth: 1320
    implicitHeight: Math.min(970, Math.max(600, screen.height - 40))
    color: Theme.window
    property string page: "Bar & Island"
    property string query: ""
    property var pages: ["Bar & Island", "Clock & Date", "Appearance", "Motion", "Launcher", "Notifications", "Control Center", "Lock Screen", "System", "Wallpaper", "Clipboard", "Power & Battery", "Weather", "System monitor"]

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
                    width: 198; height: 38; radius: 10; color: root.page === modelData ? Theme.card : "transparent"
                    Row { anchors.fill: parent; anchors.leftMargin: 9; spacing: 10
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13; color: root.page === modelData ? Theme.accent : Theme.accentContainer
                            Text { anchors.centerIn: parent; text: "●"; color: root.page === modelData ? Theme.onAccent : Theme.accent; font.pixelSize: 13 }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.text; font.family: "Inter"; font.pointSize: Theme.pt(12.5) }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.page = modelData }
                }
            }
        }
    }
    Text { x: 248; y: 14; text: "‹"; color: Theme.text; font.pixelSize: 20 }
    Text { x: 284; y: 14; text: "›"; color: Theme.text; font.pixelSize: 20 }
    Flickable {
        x: 243; y: 0; width: 1054; height: parent.height; clip: true
        contentWidth: width; contentHeight: body.implicitHeight + 60
        Column {
            id: body; width: parent.width; spacing: 13; topPadding: 46; bottomPadding: 30
            Rectangle {
                width: 1054; height: 156; radius: 12; color: Theme.group
                Column { anchors.centerIn: parent; spacing: 10
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; radius: 28; color: Theme.accentContainer
                        Text { anchors.centerIn: parent; text: "⚙"; color: Theme.accent; font.pixelSize: 23 }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.page; color: Theme.text; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Configure Dynamite. Changes apply immediately."; color: Theme.textSecondary; font.pixelSize: 12 }
                }
            }
            Rectangle {
                visible: root.page === "Control Center"; width: 1054; height: 570; radius: 12; color: Theme.group
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
                    Text { text: "Drag to move · corner to resize · right-click for sizes"; color: Theme.textMuted; font.pointSize: Theme.pt(10.5) }
                    Item { id: previewArea; width: 550; height: 390
                        property var sizeChoices: []
                        property var sizeItem: null
                        property real sizeMenuX: 0
                        property real sizeMenuY: 0
                        function openSizes(item, px, py) {
                            sizeItem = item
                            sizeMenuX = Math.max(0, Math.min(width - 110, px))
                            sizeMenuY = Math.max(0, Math.min(height - 150, py))
                            const choices = GridLayoutModel.capabilities[item.id] || []
                            const menu = []
                            for (const cap of choices)
                                for (let w = cap[1]; w <= cap[2]; ++w)
                                    for (let h = cap[3]; h <= cap[4]; ++h) {
                                        const key = cap[0] + ":" + w + "x" + h
                                        if (!menu.some(c => c.key === key)) menu.push({key:key, kind:cap[0], w:w, h:h, label:w + "×" + h})
                                    }
                            sizeChoices = menu
                        }
                        Repeater { model: GridLayoutModel.items; delegate: Rectangle {
                            required property var modelData
                            x: GridLayoutModel.pad + modelData.x * GridLayoutModel.pitch; y: modelData.y * GridLayoutModel.pitch
                            Behavior on x { Spring { token: Motion.panel } }
                            Behavior on y { Spring { token: Motion.panel } }
                            width: modelData.w * GridLayoutModel.pitch - GridLayoutModel.gap; height: modelData.h * GridLayoutModel.pitch - GridLayoutModel.gap
                            radius: 20; color: Theme.panel; border.width: 1; border.color: selected ? Theme.accent : "transparent"
                            property bool selected: false
                            Text { anchors.centerIn: parent; text: modelData.id; color: Theme.text; font.pixelSize: 12 }
                            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "◢"; color: Theme.textSecondary; font.pixelSize: 12 }
                            Rectangle { x: -4; y: -4; width: 16; height: 16; radius: 8; color: Theme.danger; visible: parent.selected
                                Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; onClicked: { root.pushUndo(); GridLayoutModel.save(GridLayoutModel.items.filter(i => i.id !== modelData.id)) } }
                            }
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; drag.target: parent
                                onClicked: mouse => {
                                    parent.selected = true; selectedItem = modelData
                                    if (mouse.button === Qt.RightButton) previewArea.openSizes(modelData, parent.x + mouse.x, parent.y + mouse.y)
                                    else previewArea.sizeChoices = []
                                }
                                onReleased: {
                                    const nx = Math.max(0, Math.round((parent.x - GridLayoutModel.pad) / GridLayoutModel.pitch))
                                    const ny = Math.max(0, Math.round(parent.y / GridLayoutModel.pitch))
                                    const next = GridLayoutModel.reflow(GridLayoutModel.items, modelData, {x:nx,y:ny}, GridLayoutModel.columns)
                                    if (next) { root.pushUndo(); GridLayoutModel.save(next) }
                                    else { parent.x = GridLayoutModel.pad + modelData.x * GridLayoutModel.pitch; parent.y = modelData.y * GridLayoutModel.pitch; rejected = true; rejectedX = Math.min(width - 100, parent.x); rejectedY = Math.max(0, parent.y - 22); rejectTimer.restart() }
                                }
                            }
                            MouseArea { x: parent.width - 18; y: parent.height - 18; width: 18; height: 18; acceptedButtons: Qt.LeftButton
                                property real startX: 0; property real startY: 0
                                onPressed: mouse => { startX = mouse.x; startY = mouse.y }
                                onReleased: mouse => {
                                    const nw=Math.max(1,Math.round(modelData.w+(mouse.x-startX)/GridLayoutModel.pitch));
                                    const nh=Math.max(1,Math.round(modelData.h+(mouse.y-startY)/GridLayoutModel.pitch));
                                    if (GridLayoutModel.sizeAllowed(modelData.id,modelData.kind,nw,nh)) root.resizeItem(modelData,nw,nh,modelData.kind)
                                }
                            }
                        } }
                        Rectangle { visible: previewArea.sizeChoices.length > 0; x: previewArea.sizeMenuX; y: previewArea.sizeMenuY; width: 106; height: Math.min(150, previewArea.sizeChoices.length * 28 + 8); radius: 10; color: Theme.raised; border.width: 1; border.color: Theme.divider; z: 5
                            Column { anchors.fill: parent; anchors.margins: 4; spacing: 2
                                Repeater { model: previewArea.sizeChoices; delegate: Rectangle { required property var modelData; width: 98; height: 26; radius: 7; color: Theme.control
                                    Text { anchors.centerIn: parent; text: modelData.label; color: Theme.text; font.pixelSize: 11 }
                                    MouseArea { anchors.fill: parent; onClicked: { root.resizeItem(previewArea.sizeItem, modelData.w, modelData.h, modelData.kind); previewArea.sizeChoices = [] } }
                                } }
                            }
                        }
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
                    Slider { x: 400; y: 17; width: 620; height: 4; value: (modelData.value - modelData.min) / (modelData.max - modelData.min); onMoved: root.write(modelData.path, modelData.min + value * (modelData.max - modelData.min)) }
                    Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.value); color: Theme.textSecondary; font.pixelSize: 11 }
                }
            }
            Rectangle { visible: root.page === "Appearance"; width: 1054; height: 480; color: Theme.group; radius: 12
                Grid { anchors.centerIn: parent; columns: 4; spacing: 14
                    Repeater { model: Themes.list; delegate: Rectangle { required property var modelData; width: 220; height: 86; radius: 12; color: Theme.card; border.width: Config.appearance.theme === modelData.name ? 2 : 0; border.color: Theme.accent
                        Text { anchors.centerIn: parent; text: modelData.label; color: Theme.text; font.pixelSize: 14 }
                        MouseArea { anchors.fill: parent; onClicked: Themes.apply(modelData.name) }
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
