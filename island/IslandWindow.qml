import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.controlcenter
import qs.island.panels
import qs.services
import qs.state
import qs.theme

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    implicitWidth: screen.width
    implicitHeight: Metrics.windowHeight
    color: "transparent"
    exclusiveZone: game ? Config.gameMode.barHeight : Config.island.gap + Config.island.barHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dynamite-island"
    WlrLayershell.keyboardFocus: !onThisScreen ? WlrKeyboardFocus.None
        : Island.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive
        : Island.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property string mode: Island.modeOn(screen.name)
    readonly property bool onThisScreen: mode === Island.mode
    readonly property bool game: Island.gameMode
    // Top of an expanded panel: below the islands, or below the game bar.
    readonly property real stageTop: game ? Config.gameMode.barHeight + Config.island.stageLift
        : Config.island.gap + Config.island.stageLift

    mask: Region {
        Region { item: gameBar }
        Region { item: albumIsland }
        Region { item: centerIsland }
        Region { item: statusIsland }
    }
    IdleInhibitor { window: root; enabled: Idle.caffeine }

    function centerWidth(): real {
        switch (mode) {
        case "clock": return 254
        case "calendar": return 335
        case "launcher": return 514
        case "power": return 514
        case "osd": return 280
        case "toast": return 450
        case "polkit": return 430
        case "themes": return 802
        case "wallpapers": return 802
        case "clipboard": case "keybinds": case "window": return 514
        default: return game ? 0 : Config.island.collapsedWidth
        }
    }
    function centerHeight(): real {
        switch (mode) {
        case "clock": return 116
        case "calendar": return Config.weather.inCalendar ? (Weather.expanded ? 405 : 341) : 277
        case "launcher": return Island.launcherHeight
        case "power": return 110
        case "osd": return 44
        case "toast": return 67
        case "polkit": return 266
        case "themes": return 220
        case "wallpapers": return 296
        case "clipboard": return Island.clipboardHeight
        case "keybinds": return 500
        case "window": return 370 + WindowMenu.desktopActions.length * (Metrics.rowHeight + 5)
            + (WindowMenu.outputs.length > 1 ? Metrics.rowHeight + 5 : 0)
            + (WindowMenu.expanded === "workspace" ? Math.min(210, WindowMenu.targetWorkspaces.length * 37)
            : WindowMenu.expanded === "monitor" ? Math.min(148, WindowMenu.outputs.length * 37) : 0)
        default: return game ? 0 : Config.island.barHeight
        }
    }
    function centerY(): real {
        if (game) return centerExpanded ? stageTop : Config.island.gap + Config.island.barHeight / 2
        if (Config.island.notchMode) return 0
        return centerExpanded ? stageTop : Config.island.gap
    }
    function centerRadius(): real {
        const h = centerHeight()
        return h <= Metrics.pillRadiusThreshold ? h / 2 : Config.island.radiusExpanded
    }
    readonly property bool centerExpanded: ["clock", "calendar", "launcher", "power", "osd", "toast", "polkit", "themes", "wallpapers", "clipboard", "keybinds", "window"].includes(mode)
    property real albumGap: mode === "media" ? Metrics.mediaGap : centerExpanded ? Metrics.expandedGap : Metrics.collapsedGap
    property real statusGap: centerExpanded ? Metrics.expandedGap : Metrics.collapsedGap
    Behavior on albumGap { Spring { token: Motion.island } }
    Behavior on statusGap { Spring { token: Motion.island } }

    Connections {
        target: Island
        function onFocusRequested() { keys.forceActiveFocus() }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.mode === "polkit") Polkit.cancel()
                else Island.close()
                event.accepted = true
            } else if (root.mode === "cc" && Island.ccPage !== "main" && event.key === Qt.Key_Backspace) {
                Island.ccPage = "main"
                event.accepted = true
            } else if (root.mode === "calendar" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                calendarSlot.item?.shift(event.key === Qt.Key_Left ? -1 : 1)
                event.accepted = true
            } else if (root.mode === "window" && event.key === Qt.Key_Return && WindowMenu.expanded === "workspace" && WindowMenu.targetWorkspaces.length) {
                const ws = WindowMenu.targetWorkspaces[WindowMenu.selectedWorkspaceIndex]
                WindowMenu.action("workspace:" + String(ws.name || ws.idx))
                Island.close()
                event.accepted = true
            } else if (root.mode === "window" && WindowMenu.expanded === "workspace" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down) && WindowMenu.targetWorkspaces.length) {
                const step = event.key === Qt.Key_Down ? 1 : -1
                WindowMenu.selectedWorkspaceIndex = (WindowMenu.selectedWorkspaceIndex + step + WindowMenu.targetWorkspaces.length) % WindowMenu.targetWorkspaces.length
                event.accepted = true
            } else if (root.mode === "media" && event.key === Qt.Key_Space && Media.activePlayer?.canTogglePlaying) {
                Media.activePlayer.togglePlaying()
                event.accepted = true
            }
        }
    }

    // Hover: collapsed → clock after 80 ms; clock → collapsed 120 ms and calendar → collapsed 350 ms after leaving.
    Timer {
        id: hoverOpen
        interval: 80
        onTriggered: if (centerHover.hovered && root.mode === "collapsed" && ["collapsed", "clock"].includes(Island.mode))
            Island.open("clock", root.screen.name)
    }
    Timer {
        id: hoverClose
        interval: root.mode === "calendar" ? 350 : 120
        onTriggered: if (!centerHover.hovered && (root.mode === "clock" || root.mode === "calendar")) Island.close()
    }

    // Once the launcher has finished opening, result-count resizes use the softer panel spring.
    property bool launcherSettled: false
    onModeChanged: { launcherSettled = false; if (mode === "launcher") launcherSettle.restart() }
    Timer { id: launcherSettle; interval: 450; onTriggered: root.launcherSettled = root.mode === "launcher" }

    SpringRect {
        id: centerIsland
        heightToken: root.launcherSettled || (root.mode === "window" && WindowMenu.expanded !== "") ? Motion.panel : Motion.island
        tx: (root.width - root.centerWidth()) / 2
        ty: root.centerY()
        tw: root.centerWidth()
        th: root.centerHeight()
        tr: root.centerRadius()
        notch: Config.island.notchMode

        HoverHandler {
            id: centerHover
            onHoveredChanged: {
                if (hovered) {
                    hoverClose.stop()
                    if (root.mode === "collapsed") hoverOpen.restart()
                } else {
                    hoverOpen.stop()
                    if (root.mode === "clock" || root.mode === "calendar") hoverClose.restart()
                }
            }
        }

        TapHandler {
            enabled: root.mode === "collapsed"
            onTapped: Island.open("clock", root.screen.name)
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: !Island.interactive && root.mode === "collapsed"
            onTapped: Island.open("window", root.screen.name)
        }

        PanelSlot {
            width: Config.island.collapsedWidth
            height: Config.island.barHeight
            shown: !root.centerExpanded
            content: CollapsedClock {}
        }
        PanelSlot {
            width: 254
            height: 116
            shown: root.mode === "clock"
            content: HoverClock {}
        }
        PanelSlot {
            id: calendarSlot
            width: 335
            height: Config.weather.inCalendar ? (Weather.expanded ? 405 : 341) : 277
            shown: root.mode === "calendar"
            content: Calendar {}
        }
        PanelSlot {
            width: 514
            height: 83 + 47 * Config.launcher.maxResults
            shown: root.mode === "launcher"
            content: Launcher {}
        }
        PanelSlot {
            width: 514
            height: 110
            shown: root.mode === "power"
            content: PowerMenu {}
        }
        PanelSlot {
            width: 280
            height: 44
            shown: root.mode === "osd"
            content: Osd {}
        }
        PanelSlot {
            width: 450
            height: 67
            shown: root.mode === "toast"
            content: Toast {}
        }
        PanelSlot {
            width: 430
            height: 266
            shown: root.mode === "polkit"
            content: PolkitPrompt {}
        }
        PanelSlot {
            width: 802
            height: 220
            shown: root.mode === "themes"
            content: ThemePicker {}
        }
        PanelSlot {
            width: 802; height: 296
            shown: root.mode === "wallpapers"
            content: WallpaperPicker {}
        }
        PanelSlot { width: 514; height: 380; shown: root.mode === "clipboard"; content: ClipboardPanel {} }
        PanelSlot { width: 514; height: 500; shown: root.mode === "keybinds"; content: KeybindsPanel {} }
        PanelSlot { width: 514; height: root.centerHeight(); shown: root.mode === "window"; content: WindowMenuPanel {} }
    }

    // Game mode: a full-width bar grows down from the top edge; its content is pinned to the bar's bottom.
    Rectangle {
        id: gameBar
        width: root.width
        height: root.game ? Config.gameMode.barHeight : 0
        Behavior on height { Spring { token: Motion.island } }
        color: Theme.island
        clip: true
        visible: height > 0.5

        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Config.gameMode.barHeight

            Txt {
                anchors.centerIn: parent
                px: 15; weight: Font.DemiBold
                SystemClock { id: gameClock; precision: SystemClock.Minutes }
                text: Qt.formatTime(gameClock.date, Config.clock.use24h ? "HH:mm" : "h:mm")
            }
            AlbumCircle {
                x: parent.width / 2 - Config.gameMode.clusterGap - width / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.activePlayer !== null || !Config.island.albumCircleWhilePlaying
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.toggle("media", root.screen.name)
                }
            }
            StatusCircle {
                x: parent.width / 2 + Config.gameMode.clusterGap - width / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.island.statusCircle
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.toggle("cc", root.screen.name)
                }
            }
        }
    }

    SpringRect {
        id: albumIsland
        readonly property bool shown: (Media.activePlayer !== null || !Config.island.albumCircleWhilePlaying) && !Island.gameMode
        springX: false
        readonly property bool expanded: root.mode === "media"
        readonly property bool rightEdgeAnchored: expanded || width > Metrics.circle
        readonly property real diameter: expanded ? Metrics.albumWidth : shown ? Metrics.circle : 0
        readonly property real centerAnchorX: centerIsland.x - root.albumGap - Metrics.circle / 2
        x: root.game && expanded ? (root.width - width) / 2
            : rightEdgeAnchored ? centerIsland.x - root.albumGap - width : centerAnchorX - width / 2
        ty: expanded ? root.stageTop : Config.island.gap + (shown ? 0 : Metrics.circle / 2)
        tw: diameter
        th: expanded ? Metrics.albumHeight : diameter
        tr: expanded ? Config.island.radiusExpanded : Metrics.circle / 2
        notch: Config.island.notchMode

        AlbumCircle {
            width: Metrics.circle; height: Metrics.circle
            x: Math.max(albumIsland.width - width, (albumIsland.width - width) / 2)
            y: Math.min(0, (albumIsland.height - height) / 2)
            scale: Math.min(1, Math.min(albumIsland.width, albumIsland.height) / Metrics.circle)
            opacity: albumIsland.expanded ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !albumIsland.expanded && albumIsland.shown
            cursorShape: Qt.PointingHandCursor
            onClicked: Island.open("media", root.screen.name)
        }
        PanelSlot {
            width: Metrics.albumWidth
            height: Metrics.albumHeight
            edge: 1
            shown: albumIsland.expanded
            content: MediaPlayer {}
        }
    }

    SpringRect {
        id: statusIsland
        readonly property bool shown: Config.island.statusCircle && !Island.gameMode
        springX: false
        readonly property bool expanded: root.mode === "cc"
        readonly property bool leftEdgeAnchored: expanded || width > Metrics.circle
        readonly property real diameter: expanded ? GridLayoutModel.pageWidth(Island.ccPage) : shown ? Metrics.circle : 0
        readonly property real centerAnchorX: centerIsland.x + centerIsland.width + root.statusGap + Metrics.circle / 2
        x: root.game && expanded ? (root.width - width) / 2
            : leftEdgeAnchored ? centerIsland.x + centerIsland.width + root.statusGap : centerAnchorX - width / 2
        ty: root.game && expanded ? root.stageTop : Config.island.gap + (expanded || shown ? 0 : Metrics.circle / 2)
        tw: diameter
        th: expanded ? GridLayoutModel.pageHeight(Island.ccPage) : diameter
        tr: expanded ? Config.island.radiusExpanded : Metrics.circle / 2
        notch: Config.island.notchMode

        StatusCircle {
            x: Math.min(0, (statusIsland.width - width) / 2)
            y: Math.min(0, (statusIsland.height - height) / 2)
            scale: Math.min(1, Math.min(statusIsland.width, statusIsland.height) / Metrics.circle)
            opacity: statusIsland.expanded ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !statusIsland.expanded && statusIsland.shown
            cursorShape: Qt.PointingHandCursor
            onClicked: Island.open("cc", root.screen.name)
        }
        PanelSlot {
            width: Math.max(GridLayoutModel.width, 514)
            height: Math.max(GridLayoutModel.mainHeight, 717)
            edge: -1
            shown: statusIsland.expanded
            content: ControlCenter {}
        }
    }
}
