import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

ShellRoot {
    id: root

    // Active flyout state: "", "wifi", "battery", "calendar", "apps"
    property string activePopup: ""

    // Smooth popup dismissal state
    property bool isPopupClosing: false
    property string displayedPopup: root.activePopup

    Timer {
        id: popupCloseTimer
        interval: 190
        onTriggered: {
            root.isPopupClosing = false
            root.activePopup = ""
            root.displayedPopup = ""
        }
    }

    function openPopup(name) {
        popupCloseTimer.stop()
        root.isPopupClosing = false
        root.displayedPopup = name
        root.activePopup = name
    }

    function closePopup(instant) {
        if (root.activePopup === "" && !root.isPopupClosing) return
        if (instant) {
            popupCloseTimer.stop()
            root.isPopupClosing = false
            root.activePopup = ""
            root.displayedPopup = ""
        } else {
            root.isPopupClosing = true
            popupCloseTimer.restart()
        }
    }

    function togglePopup(name) {
        if (root.activePopup === name && !root.isPopupClosing) {
            closePopup(false)
        } else {
            openPopup(name)
        }
    }

    // IPC Handler to open/toggle app launcher from external keybind (Mod+Space)
    IpcHandler {
        target: "launcher"
        function toggle() {
            root.togglePopup("apps")
        }
        function open() {
            root.openPopup("apps")
        }
        function close() {
            root.closePopup(false)
        }
    }

    // IPC Handler to open/toggle clipboard history from external keybind (Mod+V)
    IpcHandler {
        target: "clipboard"
        function toggle() {
            root.togglePopup("clipboard")
        }
        function open() {
            root.openPopup("clipboard")
        }
        function close() {
            root.closePopup(false)
        }
    }

    // IPC Handler to open/toggle battery and system panel
    IpcHandler {
        target: "battery"
        function toggle() {
            root.togglePopup("battery")
        }
        function open() {
            root.openPopup("battery")
        }
        function close() {
            root.closePopup(false)
        }
    }

    // IPC Handler to control bar position
    IpcHandler {
        target: "bar"
        function setTop(): void { root.setBarPosition("top") }
        function setBottom(): void { root.setBarPosition("bottom") }
    }

    // Bar side position: "top" or "bottom"
    property string barPosition: "top"

    // Workspace change indicator transient state
    property bool showingWorkspaces: false
    Timer {
        id: wsIndicatorTimer
        interval: 700
        onTriggered: root.showingWorkspaces = false
    }

    function triggerWorkspaceIndicator() {
        root.showingWorkspaces = true
        wsIndicatorTimer.restart()
    }

    // Dynamic Action indicator state (Volume, Brightness full-bar HUD)
    property string actionType: ""
    property string actionIcon: ""
    property string actionText: ""
    property real actionPercent: 0.0
    property color actionColor: theme.accent
    property bool isActionActive: false

    Timer {
        id: actionTimer
        interval: 1300
        onTriggered: {
            root.isActionActive = false
            root.actionType = ""
        }
    }

    function showAction(type, icon, text, percent, color) {
        root.actionType = type
        root.actionIcon = icon
        root.actionText = text
        root.actionPercent = Math.max(0.0, Math.min(1.0, percent))
        root.actionColor = color || theme.accent
        root.isActionActive = true
        actionTimer.restart()
    }

    function triggerVolumeFeedback() {
        let ic = sysStats.volumeMuted ? "󰝟" : (sysStats.volume > 50 ? "󰕾" : (sysStats.volume > 0 ? "󰖀" : "󰕿"))
        let txt = sysStats.volumeMuted ? "Muted" : `${sysStats.volume}%`
        let pct = sysStats.volumeMuted ? 0.0 : (sysStats.volume / 100.0)
        showAction("volume", ic, txt, pct, sysStats.volumeMuted ? theme.danger : theme.accent)
    }

    function triggerBrightnessFeedback() {
        let ic = sysStats.brightness > 70 ? "󰃠" : (sysStats.brightness > 30 ? "󰃟" : "󰃞")
        let txt = `${sysStats.brightness}%`
        let pct = sysStats.brightness / 100.0
        showAction("brightness", ic, txt, pct, theme.warning)
    }


    function setBarPosition(pos) {
        if (pos === "top" || pos === "bottom") {
            root.barPosition = pos
            sysStats.setConfig("position", pos)
        }
    }

    function getAppIcon(appId, appName) {
        let str = ((appId || "") + " " + (appName || "")).toLowerCase()
        if (str.includes("term") || str.includes("kitty") || str.includes("alacritty") || str.includes("foot") || str.includes("agy") || str.includes("console")) return "󰆍"
        if (str.includes("fire") || str.includes("chrome") || str.includes("browser") || str.includes("web") || str.includes("chromium")) return "󰈹"
        if (str.includes("file") || str.includes("nautilus") || str.includes("thunar") || str.includes("dolphin")) return "󰉋"
        if (str.includes("code") || str.includes("dev") || str.includes("git") || str.includes("anti") || str.includes("studio")) return "󰅩"
        if (str.includes("music") || str.includes("audio") || str.includes("sound") || str.includes("spotify")) return "󰝚"
        if (str.includes("video") || str.includes("player") || str.includes("mpv") || str.includes("vlc") || str.includes("koko")) return "󰕼"
        if (str.includes("image") || str.includes("photo") || str.includes("gimp") || str.includes("inkscape")) return "󰋩"
        if (str.includes("setting") || str.includes("config") || str.includes("control") || str.includes("manager")) return "󰒓"
        if (str.includes("chat") || str.includes("discord") || str.includes("telegram") || str.includes("slack")) return "󰭹"
        if (str.includes("game") || str.includes("steam")) return "󰊖"
        return "󰀻"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // THEME DESIGN TOKENS (Pitch Black Aesthetic)
    // ─────────────────────────────────────────────────────────────────────────
    QtObject {
        id: theme
        readonly property color bg: "#000000"
        readonly property color bgTranslucent: "#fa000000"
        readonly property color surface: "#0a0a0a"
        readonly property color surfaceHover: "#161616"
        readonly property color surfaceActive: "#222222"
        readonly property color border: "#1f1f1f"
        readonly property color borderLight: "#2c2c2c"
        readonly property color text: "#f0f2fb"
        readonly property color textMuted: "#7a7d90"
        readonly property color accent: "#89b4fa"
        readonly property color accentSurface: "#141c2b"
        readonly property color success: "#a6e3a1"
        readonly property color warning: "#f9e2af"
        readonly property color danger: "#f38ba8"
        readonly property int barHeight: 46
        readonly property int pillHeight: 36
        readonly property int pillRadius: 18
        readonly property int ballSize: 36
        readonly property int ballRadius: 18
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HARDWARE CONTROLLER & SYSTEM STATE (via control.py)
    // ─────────────────────────────────────────────────────────────────────────
    QtObject {
        id: sysStats

        // Window & Workspace telemetry
        property string focusedApp: ""
        property string focusedAppName: ""
        property string focusedTitle: ""
        property string focusedAppIconPath: ""
        property int activeWorkspace: 1
        property var workspaces: ([
            { "idx": 1, "name": "1", "active": true },
            { "idx": 2, "name": "2", "active": false },
            { "idx": 3, "name": "3", "active": false }
        ])
        property var appsList: []
        property var clipboardList: []

        // Connectivity & Status
        property var wifiData: ({ "powered": true, "connected": false, "ssid": "Disconnected", "signal": 0, "networks": [] })
        property var btData: ({ "powered": false, "connected": false, "device": "None", "devices": [] })

        property bool wifiPowered: wifiData.powered ?? true
        property bool wifiConnected: wifiData.connected ?? false
        property string wifiSsid: wifiData.ssid ?? "Disconnected"
        property int wifiSignal: wifiData.signal ?? 0
        property var wifiNetworks: wifiData.networks ?? []

        property bool btPowered: btData.powered ?? false
        property bool btConnected: btData.connected ?? false
        property string btDevice: btData.device ?? "None"
        property var btDevices: btData.devices ?? []

        property int volume: 76
        property bool volumeMuted: false
        property int brightness: 50
        property string cpuUsage: "0%"
        property real cpuPercent: 0.0
        property string memUsedStr: "0.0 GB"
        property string memTotalStr: "0.0 GB"
        property real memPercent: 0.0

        property string scriptPath: Qt.resolvedUrl("scripts/control.py").toString().replace(/^file:\/\//, "")

        // Realtime WM & Workspace Event Stream
        property Process wmStreamProc: Process {
            id: wmStreamProc
            running: true
            command: ["python3", sysStats.scriptPath, "wm-stream"]
            stdout: SplitParser {
                onRead: data => {
                    let line = data.trim()
                    if (!line) return
                    try {
                        let msg = JSON.parse(line)
                        if (msg.type === "wm") {
                            sysStats.focusedApp = msg.focused_app || ""
                            sysStats.focusedAppName = msg.focused_app_name || ""
                            sysStats.focusedTitle = msg.focused_title || ""
                            sysStats.focusedAppIconPath = msg.focused_icon_path || ""
                            sysStats.activeWorkspace = msg.active_ws || 1
                            if (Array.isArray(msg.workspaces) && msg.workspaces.length > 0) {
                                sysStats.workspaces = msg.workspaces
                            }
                            if (msg.ws_event) {
                                root.triggerWorkspaceIndicator()
                            }
                        } else if (msg.type === "volume") {
                            sysStats.volume = msg.volume
                            sysStats.volumeMuted = msg.muted
                            root.triggerVolumeFeedback()
                        } else if (msg.type === "brightness") {
                            sysStats.brightness = msg.brightness
                            root.triggerBrightnessFeedback()
                        }
                    } catch (e) {}
                }
            }
            onExited: wmRestartTimer.restart()
        }

        property Timer wmRestartTimer: Timer {
            id: wmRestartTimer
            interval: 1200
            onTriggered: sysStats.wmStreamProc.running = true
        }

        // Status poll process
        property Process statusProc: Process {
            command: ["python3", sysStats.scriptPath, "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let data = JSON.parse(text)
                        if (data.config && data.config.position) {
                            root.barPosition = data.config.position
                        }
                        if (data.audio) {
                            sysStats.volume = data.audio.volume ?? 50
                            sysStats.volumeMuted = data.audio.muted ?? false
                        }
                        if (data.wifi) sysStats.wifiData = data.wifi
                        if (data.bt) sysStats.btData = data.bt
                        if (data.brightness !== undefined) sysStats.brightness = data.brightness
                        if (data.cpu !== undefined) {
                            sysStats.cpuUsage = `${data.cpu}%`
                            sysStats.cpuPercent = Math.min(1.0, data.cpu / 100.0)
                        }
                        if (data.mem) {
                            sysStats.memUsedStr = data.mem.used || "0 GB"
                            sysStats.memTotalStr = data.mem.total || "0 GB"
                            sysStats.memPercent = data.mem.percent || 0.0
                        }
                    } catch (e) {}
                }
            }
        }

        // App Catalog Fetcher
        property Process appsProc: Process {
            id: appsProc
            command: ["python3", sysStats.scriptPath, "get-apps"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let list = JSON.parse(text)
                        if (Array.isArray(list)) {
                            sysStats.appsList = list
                        }
                    } catch (e) {}
                }
            }
        }

        function loadApps() {
            if (!appsProc.running) {
                appsProc.running = true
            }
        }

        // Clipboard History Fetcher
        property Process clipProc: Process {
            id: clipProc
            command: ["python3", sysStats.scriptPath, "get-clipboard"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let list = JSON.parse(text)
                        if (Array.isArray(list)) {
                            sysStats.clipboardList = list
                        }
                    } catch (e) {}
                }
            }
        }

        function loadClipboard() {
            if (!clipProc.running) {
                clipProc.running = true
            }
        }

        function copyClipboard(cid, autoPaste) {
            let cmd = ["python3", sysStats.scriptPath, "copy-clipboard", String(cid)]
            if (autoPaste) cmd.push("true")
            Quickshell.execDetached(cmd)
        }

        function deleteClipboard(cid) {
            Quickshell.execDetached(["python3", sysStats.scriptPath, "delete-clipboard", String(cid)])
            sysStats.clipboardList = sysStats.clipboardList.filter(item => item.id !== String(cid))
        }

        function clearClipboard() {
            Quickshell.execDetached(["python3", sysStats.scriptPath, "clear-clipboard"])
            sysStats.clipboardList = []
        }

        function launchApp(execCmd) {
            actionProc.command = ["python3", sysStats.scriptPath, "launch-app", execCmd]
            actionProc.running = true
        }

        function focusWorkspace(idx) {
            actionProc.command = ["python3", sysStats.scriptPath, "focus-workspace", String(idx)]
            actionProc.running = true
        }

        function setConfig(key, val) {
            actionProc.command = ["python3", sysStats.scriptPath, "set-config", key, val]
            actionProc.running = true
        }

        function powerAction(action) {
            Quickshell.execDetached(["python3", sysStats.scriptPath, "power-action", action])
        }

        function refresh() {
            if (!statusProc.running) {
                statusProc.running = true
            }
        }

        // Connectivity Actions
        function toggleWifi() {
            actionProc.command = ["python3", sysStats.scriptPath, "toggle-wifi"]
            actionProc.running = true
        }

        function rescanWifi() {
            actionProc.command = ["python3", sysStats.scriptPath, "rescan-wifi"]
            actionProc.running = true
        }

        function connectWifi(ssid) {
            actionProc.command = ["python3", sysStats.scriptPath, "connect-wifi", ssid]
            actionProc.running = true
        }

        function disconnectWifi() {
            actionProc.command = ["python3", sysStats.scriptPath, "disconnect-wifi"]
            actionProc.running = true
        }

        function toggleBt() {
            actionProc.command = ["python3", sysStats.scriptPath, "toggle-bt"]
            actionProc.running = true
        }

        function connectBt(mac) {
            actionProc.command = ["python3", sysStats.scriptPath, "connect-bt", mac]
            actionProc.running = true
        }

        function disconnectBt(mac) {
            actionProc.command = ["python3", sysStats.scriptPath, "disconnect-bt", mac]
            actionProc.running = true
        }

        function openBtManager() {
            actionProc.command = ["python3", sysStats.scriptPath, "open-bt-manager"]
            actionProc.running = true
        }

        // Native Fast Audio Controls
        function setVolume(pct) {
            let val = Math.max(0, Math.min(100, Math.round(pct)))
            sysStats.volume = val
            if (sysStats.volumeMuted && val > 0) sysStats.volumeMuted = false
            volTimer.restart()
        }

        function commitVolume() {
            volTimer.stop()
            volProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${sysStats.volume}%`]
            volProc.running = true
        }

        function adjustVolume(delta) {
            let val = Math.max(0, Math.min(100, sysStats.volume + delta))
            setVolume(val)
            root.triggerVolumeFeedback()
        }

        function toggleMute() {
            actionProc.command = ["python3", sysStats.scriptPath, "toggle-mute"]
            actionProc.running = true
            sysStats.volumeMuted = !sysStats.volumeMuted
            root.triggerVolumeFeedback()
        }

        // Fast Backlight Controls
        function setBrightness(pct) {
            let val = Math.max(1, Math.min(100, Math.round(pct)))
            sysStats.brightness = val
            brTimer.restart()
        }

        function commitBrightness() {
            brTimer.stop()
            brProc.command = ["brightnessctl", "set", `${sysStats.brightness}%`]
            brProc.running = true
        }

        function adjustBrightness(delta) {
            let val = Math.max(1, Math.min(100, sysStats.brightness + delta))
            setBrightness(val)
            root.triggerBrightnessFeedback()
        }

        // Hardware workers
        property Process volProc: Process {}
        property Process brProc: Process {}
        property Process actionProc: Process {
            stdout: StdioCollector {
                onStreamFinished: sysStats.refresh()
            }
        }
        property Process launchProc: Process {}

        property Timer volTimer: Timer {
            interval: 35
            onTriggered: sysStats.commitVolume()
        }

        property Timer brTimer: Timer {
            interval: 50
            onTriggered: sysStats.commitBrightness()
        }

        Component.onCompleted: {
            sysStats.refresh()
            sysStats.loadApps()
        }
    }

    // Heartbeat Status Polling Timer
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: sysStats.refresh()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 1. PRIMARY SYSTEM BAR WINDOW (Exclusive Zone, Dynamic Positioning)
    // ═════════════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: root.barPosition === "top"
                    bottom: root.barPosition === "bottom"
                    left: true
                    right: true
                }

                implicitHeight: theme.barHeight
                color: "transparent"

                WlrLayershell.namespace: "quickshell:simple-bar"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.exclusiveZone: theme.barHeight
                exclusionMode: ExclusionMode.Normal

                // Dismiss popup when clicking empty space on the bar
                MouseArea {
                    anchors.fill: parent
                    z: 1
                    enabled: root.activePopup !== "" && !root.isPopupClosing
                    onClicked: root.closePopup(false)
                }

                // ─────────────────────────────────────────────────────────────
                // UNIFIED PILL CLUSTER: Center Pill + Revealable Status Balls
                // ─────────────────────────────────────────────────────────────
                Item {
                    id: pillCluster
                    z: 10
                    anchors.centerIn: parent

                    height: theme.barHeight
                    width: showBalls ? (centerPill.width + leftBall.width + rightBall.width + 36) : (centerPill.width + 12)

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    property bool isHovered: false
                    // Balls collapse when workspaces are actively switching or popup is open
                    readonly property bool showBalls: (isHovered || (root.activePopup !== "" && !centerPill.hasOpenPanel)) && !root.showingWorkspaces && !centerPill.hasOpenPanel && !root.isActionActive && !root.isPopupClosing

                    Connections {
                        target: root
                        function onActivePopupChanged() {
                            if (root.activePopup === "" && !clusterHover.hovered) {
                                collapseTimer.restart()
                            }
                        }
                    }

                    Timer {
                        id: collapseTimer
                        interval: 250
                        onTriggered: {
                            if (!clusterHover.hovered && root.activePopup === "") {
                                pillCluster.isHovered = false
                            }
                        }
                    }

                    HoverHandler {
                        id: clusterHover
                        onHoveredChanged: {
                            if (hovered) {
                                collapseTimer.stop()
                                pillCluster.isHovered = true
                            } else {
                                collapseTimer.restart()
                            }
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // CENTER PILL: Clock, Date, Focused App, Workspaces & Volume
                    // ─────────────────────────────────────────────────────────
                    Rectangle {
                        id: centerPill
                        z: 10
                        color: theme.bg
                        radius: theme.pillRadius
                        border.width: 0
                        border.color: "transparent"

                        // When a panel popup is open, expand to match it for the "unified bar" effect
                        readonly property bool hasOpenPanel: (root.activePopup === "apps" || root.activePopup === "clipboard") && !root.isPopupClosing
                        readonly property int panelWidth: 560

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: !hasOpenPanel ? parent.verticalCenter : undefined
                        anchors.top: (hasOpenPanel && root.barPosition === "bottom") ? parent.top : undefined
                        anchors.bottom: (hasOpenPanel && root.barPosition === "top") ? parent.bottom : undefined

                        width: root.showingWorkspaces ? (workspacesRow.implicitWidth + 32)
                               : (root.isActionActive ? (actionRow.implicitWidth + 36)
                               : (hasOpenPanel ? panelWidth
                               : (Math.max(pillContentRow.width, pillContentRow.implicitWidth) + 36)))
                        height: hasOpenPanel ? theme.barHeight : theme.pillHeight

                        // When panel extends below, flatten bottom corners; when extends above, flatten top corners
                        readonly property bool panelBelow: hasOpenPanel && root.barPosition === "top"
                        readonly property bool panelAbove: hasOpenPanel && root.barPosition === "bottom"
                        topLeftRadius:     panelAbove ? 0 : theme.pillRadius
                        topRightRadius:    panelAbove ? 0 : theme.pillRadius
                        bottomLeftRadius:  panelBelow ? 0 : theme.pillRadius
                        bottomRightRadius: panelBelow ? 0 : theme.pillRadius

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        // Volume scrolling feedback state
                        property bool showingVolume: false
                        property Timer volTimer: Timer {
                            interval: 1400
                            onTriggered: centerPill.showingVolume = false
                        }

                        // ─────────────────────────────────────────────────────
                        // A. HORIZONTAL BAR CONTENT
                        // ─────────────────────────────────────────────────────
                        Item {
                            anchors.fill: parent

                            // 1. Normal View (Clock, Date, Focused App / Action indicator)
                            Row {
                                id: pillContentRow
                                anchors.centerIn: parent
                                spacing: 8
                                visible: !root.showingWorkspaces && !root.isActionActive
                                opacity: visible ? 1.0 : 0.0

                                // Interactive Clock + Date Button
                                Rectangle {
                                    id: clockArea
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 26
                                    radius: 13
                                    color: clockMouse.containsMouse || root.activePopup === "calendar" ? theme.surfaceHover : "transparent"
                                    border.width: 0
                                    width: clockRow.implicitWidth + 12

                                    RowLayout {
                                        id: clockRow
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            id: clockTime
                                            text: Qt.formatDateTime(new Date(), "hh:mm A")
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: theme.text

                                            Timer {
                                                interval: 1000
                                                running: true
                                                repeat: true
                                                onTriggered: clockTime.text = Qt.formatDateTime(new Date(), "hh:mm A")
                                            }
                                        }

                                        Rectangle {
                                            width: 4; height: 4; radius: 2; color: theme.textMuted
                                        }

                                        Text {
                                            id: clockDate
                                            text: Qt.formatDateTime(new Date(), "ddd, MMM d")
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            color: theme.textMuted

                                            Timer {
                                                interval: 60000
                                                running: true
                                                repeat: true
                                                onTriggered: clockDate.text = Qt.formatDateTime(new Date(), "ddd, MMM d")
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: clockMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.togglePopup("calendar")
                                    }
                                }

                                // Separator (only visible when appBadge is visible)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 1; height: 14; color: theme.borderLight
                                    visible: appBadge.shouldShow
                                }

                                // Focused App / Launcher / Clipboard area (hides Desktop button when on desktop)
                                Rectangle {
                                    id: appBadge
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 26
                                    radius: 13
                                    color: (appBadgeMouse.containsMouse || root.activePopup === "apps" || root.activePopup === "clipboard") ? theme.surfaceHover : "transparent"
                                    border.width: 0

                                    readonly property bool hasFocusedApp: (sysStats.focusedAppName !== "" || sysStats.focusedApp !== "") && sysStats.focusedApp.toLowerCase() !== "desktop"
                                    readonly property bool isLauncherHovered: appBadgeMouse.containsMouse || (root.activePopup === "apps" && !root.isPopupClosing)
                                    readonly property bool isClipboard: (root.activePopup === "clipboard" && !root.isPopupClosing)
                                    readonly property bool shouldShow: hasFocusedApp || isLauncherHovered || isClipboard

                                    visible: shouldShow
                                    width: shouldShow ? (appBadgeRow.width + 20) : 0
                                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    clip: true

                                    Row {
                                        id: appBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        // Unified icon container
                                        Item {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16; height: 16

                                            // 1. Clipboard icon
                                            Text {
                                                anchors.centerIn: parent
                                                visible: appBadge.isClipboard
                                                text: "󰅍"
                                                font.pixelSize: 14
                                                color: theme.accent
                                            }

                                            // 2. Launcher icon
                                            Text {
                                                anchors.centerIn: parent
                                                visible: appBadge.isLauncherHovered && !appBadge.isClipboard
                                                text: "󰀻"
                                                font.pixelSize: 14
                                                color: theme.accent
                                            }

                                            // 3. Real App Icon (Image or Nerd Font fallback)
                                            Image {
                                                id: appRealIcon
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectFit
                                                source: sysStats.focusedAppIconPath ? ("file://" + sysStats.focusedAppIconPath) : ""
                                                visible: !appBadge.isLauncherHovered && !appBadge.isClipboard && status === Image.Ready
                                                smooth: true
                                                mipmap: true
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !appBadge.isLauncherHovered && !appBadge.isClipboard && (!appRealIcon.visible || appRealIcon.status !== Image.Ready)
                                                text: root.getAppIcon(sysStats.focusedApp, sysStats.focusedAppName)
                                                font.pixelSize: 13
                                                color: theme.accent
                                            }
                                        }

                                        // Text: context-aware label
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: appBadge.isClipboard ? "Clipboard"
                                                : (appBadge.isLauncherHovered ? "Launcher"
                                                : (sysStats.focusedAppName || sysStats.focusedApp || ""))
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: (appBadge.isLauncherHovered || appBadge.isClipboard) ? theme.accent : theme.text
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: appBadgeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.togglePopup("apps")
                                    }
                                }
                            }


                            // 2. Workspaces Changing View (Requirement: Full bar shows ONLY workspace icons!)
                            RowLayout {
                                id: workspacesRow
                                anchors.centerIn: parent
                                spacing: 8
                                visible: opacity > 0.01
                                opacity: root.showingWorkspaces ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Repeater {
                                    model: sysStats.workspaces

                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool isAct: modelData.active
                                        height: 24
                                        width: isAct ? 34 : 26
                                        radius: 12
                                        color: isAct ? theme.accent : (wsMouse.containsMouse ? theme.surfaceHover : theme.surface)
                                        border.width: 0

                                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name || String(modelData.idx)
                                            font.pixelSize: 11
                                            font.weight: isAct ? Font.Bold : Font.Normal
                                            color: isAct ? "#000000" : theme.textMuted
                                        }

                                        MouseArea {
                                            id: wsMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                sysStats.focusWorkspace(modelData.idx)
                                                wsIndicatorTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. Full-Bar Action View (Volume & Brightness HUD replacing clock & whole bar)
                            RowLayout {
                                id: actionRow
                                anchors.centerIn: parent
                                spacing: 10
                                visible: !root.showingWorkspaces && root.isActionActive
                                opacity: visible ? 1.0 : 0.0

                                Text {
                                    text: root.actionIcon
                                    font.pixelSize: 15
                                    color: root.actionColor
                                }

                                Text {
                                    text: root.actionType === "volume" ? "Volume" : "Brightness"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: theme.textMuted
                                }

                                // Mini sleek progress bar
                                Rectangle {
                                    width: 76
                                    height: 4
                                    radius: 2
                                    color: "#222222"

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * root.actionPercent
                                        radius: 2
                                        color: root.actionColor
                                        Behavior on width { NumberAnimation { duration: 80 } }
                                    }
                                }

                                Text {
                                    text: root.actionText
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: theme.text
                                }
                            }
                        }

                        // Background click-dismiss for transient workspace view (only active when showing workspaces)
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            enabled: root.showingWorkspaces
                            onClicked: root.showingWorkspaces = false
                        }

                        // Scrolling anywhere on the pill adjusts audio volume or brightness without intercepting clicks or hovers
                        WheelHandler {
                            onWheel: event => {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    let step = event.angleDelta.y > 0 ? 5 : -5
                                    sysStats.adjustBrightness(step)
                                } else {
                                    let step = event.angleDelta.y > 0 ? 4 : -4
                                    sysStats.adjustVolume(step)
                                }
                            }
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // LEFT BALL: Wi-Fi & Bluetooth (Expands with info on hover)
                    // ─────────────────────────────────────────────────────────
                    Rectangle {
                        id: leftBall
                        z: 12
                        height: theme.ballSize
                        radius: theme.ballRadius
                        anchors.verticalCenter: centerPill.verticalCenter
                        anchors.right: centerPill.left
                        anchors.rightMargin: pillCluster.showBalls ? 10 : -theme.ballRadius

                        property bool isBallHovered: leftBallMouse.containsMouse
                        width: isBallHovered ? Math.max(theme.ballSize, leftBallContent.implicitWidth + 20) : theme.ballSize
                        clip: true

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                        Behavior on anchors.rightMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        color: leftBall.isBallHovered || root.activePopup === "wifi" ? theme.surfaceHover : theme.bg
                        border.color: "transparent"
                        border.width: 0

                        opacity: pillCluster.showBalls ? 1.0 : 0.0
                        scale: pillCluster.showBalls ? 1.0 : 0.4
                        visible: opacity > 0.01

                        RowLayout {
                            id: leftBallContent
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: sysStats.wifiConnected ? "󰤨" : (sysStats.wifiPowered ? "󰤭" : "󰤮")
                                font.pixelSize: 15
                                color: sysStats.wifiConnected ? theme.accent : (sysStats.wifiPowered ? theme.textMuted : theme.danger)
                            }

                            // Dynamic hover text showing active Wi-Fi SSID & Bluetooth status
                            RowLayout {
                                visible: leftBall.isBallHovered
                                spacing: 8

                                Text {
                                    text: sysStats.wifiConnected ? sysStats.wifiSsid : (sysStats.wifiPowered ? "Wi-Fi On" : "Wi-Fi Off")
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: theme.text
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                }

                                Rectangle { width: 3; height: 3; radius: 1.5; color: theme.textMuted }

                                Text {
                                    text: sysStats.btConnected ? sysStats.btDevice : (sysStats.btPowered ? "BT On" : "BT Off")
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: sysStats.btConnected ? theme.accent : theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 90
                                }
                            }
                        }

                        MouseArea {
                            id: leftBallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePopup = root.activePopup === "wifi" ? "" : "wifi"
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // RIGHT BALL: Battery & Device Status (Expands on hover)
                    // ─────────────────────────────────────────────────────────
                    Rectangle {
                        id: rightBall
                        z: 12
                        height: theme.ballSize
                        radius: theme.ballRadius
                        anchors.verticalCenter: centerPill.verticalCenter
                        anchors.left: centerPill.right
                        anchors.leftMargin: pillCluster.showBalls ? 10 : -theme.ballRadius

                        readonly property real rawPct: UPower.displayDevice?.percentage ?? 0
                        readonly property real normalizedPct: rawPct > 1.0 ? (rawPct / 100.0) : rawPct
                        readonly property int pctInt: Math.round(normalizedPct * 100)
                        readonly property bool charging: UPower.displayDevice?.state === 1

                        property bool isBallHovered: rightBallMouse.containsMouse
                        width: isBallHovered ? Math.max(theme.ballSize, rightBallContent.implicitWidth + 20) : theme.ballSize
                        clip: true

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                        Behavior on anchors.leftMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        color: rightBall.isBallHovered || root.activePopup === "battery" ? theme.surfaceHover : theme.bg
                        border.color: "transparent"
                        border.width: 0

                        opacity: pillCluster.showBalls ? 1.0 : 0.0
                        scale: pillCluster.showBalls ? 1.0 : 0.4
                        visible: opacity > 0.01

                        RowLayout {
                            id: rightBallContent
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: rightBall.charging ? "󰂄" : (rightBall.pctInt > 80 ? "󰁹" : (rightBall.pctInt > 50 ? "󰁾" : (rightBall.pctInt > 20 ? "󰁼" : "󰂃")))
                                font.pixelSize: 15
                                color: rightBall.charging ? theme.success : (rightBall.pctInt <= 20 ? theme.danger : theme.text)
                            }

                            // Dynamic hover text showing Battery percentage & state
                            RowLayout {
                                visible: rightBall.isBallHovered
                                spacing: 6

                                Text {
                                    text: `${rightBall.pctInt}% ${rightBall.charging ? "Charging" : ""}`.trim()
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: theme.text
                                }
                            }
                        }

                        MouseArea {
                            id: rightBallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePopup = root.activePopup === "battery" ? "" : "battery"
                        }

                        // Scrolling on the battery/status ball adjusts screen brightness
                        WheelHandler {
                            onWheel: event => {
                                let step = event.angleDelta.y > 0 ? 5 : -5
                                sysStats.adjustBrightness(step)
                            }
                        }
                    }

                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. OVERLAY FLYOUT PANELS (Pitch Black Panels, Sliders, Full Hardware UI)
    // ═════════════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: overlayWindow
                required property var modelData
                screen: modelData

                visible: root.activePopup !== "" || root.isPopupClosing

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                margins {
                    top: root.barPosition === "top" ? theme.barHeight : 0
                    bottom: root.barPosition === "bottom" ? theme.barHeight : 0
                    left: 0
                    right: 0
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:simple-bar-popups"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: ((root.activePopup === "apps" || root.activePopup === "clipboard") && !root.isPopupClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                // Click-outside background to dismiss popup
                MouseArea {
                    anchors.fill: parent
                    enabled: root.activePopup !== "" && !root.isPopupClosing
                    onClicked: root.closePopup(false)
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL A: CONNECTIVITY & QUICK CONTROLS (Wi-Fi, Bluetooth)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: connPanel
                    visible: root.activePopup === "wifi"
                    y: root.barPosition === "top" ? 6 : (parent.height - height - 6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -120

                    width: 380
                    height: 450
                    radius: 18
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                    }

                    property string activeTab: "wifi"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        // Panel Header
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Connectivity"
                                font.pixelSize: 15
                                font.bold: true
                                color: theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: closeConnHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: theme.textMuted }
                                MouseArea {
                                    id: closeConnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        // Tab Switcher (Wi-Fi | Bluetooth)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 10
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                // Wi-Fi Tab
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: connPanel.activeTab === "wifi" ? theme.accentSurface : "transparent"
                                    border.color: connPanel.activeTab === "wifi" ? theme.accent : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰤨"; font.pixelSize: 14; color: connPanel.activeTab === "wifi" ? theme.accent : theme.textMuted }
                                        Text { text: "Wi-Fi"; font.pixelSize: 12; font.weight: Font.DemiBold; color: connPanel.activeTab === "wifi" ? theme.text : theme.textMuted }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: connPanel.activeTab = "wifi"
                                    }
                                }

                                // Bluetooth Tab
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: connPanel.activeTab === "bt" ? theme.accentSurface : "transparent"
                                    border.color: connPanel.activeTab === "bt" ? theme.accent : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰂯"; font.pixelSize: 14; color: connPanel.activeTab === "bt" ? theme.accent : theme.textMuted }
                                        Text { text: "Bluetooth"; font.pixelSize: 12; font.weight: Font.DemiBold; color: connPanel.activeTab === "bt" ? theme.text : theme.textMuted }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: connPanel.activeTab = "bt"
                                    }
                                }
                            }
                        }

                        // ─── TAB 1: WI-FI VIEW ───
                        ColumnLayout {
                            visible: connPanel.activeTab === "wifi"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            // Wi-Fi Power Toggle & Rescan
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: sysStats.wifiPowered ? "Wi-Fi Adapter Enabled" : "Wi-Fi Adapter Disabled"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: theme.text
                                }
                                Item { Layout.fillWidth: true }

                                // Rescan Button
                                Rectangle {
                                    width: 28; height: 28; radius: 6
                                    color: rescanHov.containsMouse ? theme.surfaceHover : theme.surface
                                    border.color: theme.border; border.width: 1
                                    Text { anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 14; color: theme.text }
                                    MouseArea {
                                        id: rescanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: sysStats.rescanWifi()
                                    }
                                }

                                // Wi-Fi Power Toggle Switch
                                Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: sysStats.wifiPowered ? theme.accent : theme.surfaceHover
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: sysStats.wifiPowered ? parent.width - width - 3 : 3
                                        color: sysStats.wifiPowered ? "#000000" : theme.textMuted
                                        Behavior on x { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: sysStats.toggleWifi()
                                    }
                                }
                            }

                            // Active Connection Card
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 10
                                color: theme.surface
                                border.color: sysStats.wifiConnected ? theme.accent : theme.border
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        text: sysStats.wifiConnected ? "󰤨" : "󰤭"
                                        font.pixelSize: 18
                                        color: sysStats.wifiConnected ? theme.accent : theme.textMuted
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: sysStats.wifiConnected ? sysStats.wifiSsid : "Not Connected"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: theme.text
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: sysStats.wifiConnected ? `Signal: ${sysStats.wifiSignal}%` : "Choose a network below"
                                            font.pixelSize: 11
                                            color: theme.textMuted
                                        }
                                    }

                                    Rectangle {
                                        visible: sysStats.wifiConnected
                                        width: 82; height: 26; radius: 6
                                        color: disconHov.containsMouse ? "#3b1a20" : "#261316"
                                        border.color: theme.danger; border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Disconnect"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: theme.danger
                                        }
                                        MouseArea {
                                            id: disconHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: sysStats.disconnectWifi()
                                        }
                                    }
                                }
                            }

                            // Available Networks Title
                            Text {
                                text: "Available Networks"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: theme.textMuted
                            }

                            // Scrollable Networks List
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                ListView {
                                    model: sysStats.wifiNetworks
                                    spacing: 4

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 38
                                        radius: 8
                                        color: netItemHov.containsMouse ? theme.surfaceHover : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8

                                            Text {
                                                text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 50 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟"))
                                                font.pixelSize: 14
                                                color: modelData.inUse ? theme.accent : theme.textMuted
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.ssid
                                                font.pixelSize: 12
                                                font.bold: modelData.inUse
                                                color: modelData.inUse ? theme.accent : theme.text
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: `${modelData.signal}%`
                                                font.pixelSize: 10
                                                color: theme.textMuted
                                            }

                                            Rectangle {
                                                visible: !modelData.inUse
                                                width: 60; height: 22; radius: 5
                                                color: connBtnHov.containsMouse ? theme.surfaceActive : theme.surface
                                                border.color: theme.border; border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    font.pixelSize: 10
                                                    color: theme.text
                                                }
                                                MouseArea {
                                                    id: connBtnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: sysStats.connectWifi(modelData.ssid)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: netItemHov; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }
                            }

                            // Quick Terminal Network Manager
                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: 6
                                color: nmtuiHov.containsMouse ? theme.surfaceHover : "transparent"
                                border.color: theme.border; border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰆍"; font.pixelSize: 12; color: theme.accent }
                                    Text { text: "Open Advanced Network Manager (nmtui)"; font.pixelSize: 10; font.bold: true; color: theme.textMuted }
                                }

                                MouseArea {
                                    id: nmtuiHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closePopup(false)
                                        sysStats.launchProc.command = ["kitty", "-e", "nmtui"]
                                        sysStats.launchProc.running = true
                                    }
                                }
                            }
                        }

                        // ─── TAB 2: BLUETOOTH VIEW ───
                        ColumnLayout {
                            visible: connPanel.activeTab === "bt"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            // Bluetooth Power Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: sysStats.btPowered ? "Bluetooth Enabled" : "Bluetooth Disabled"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: theme.text
                                }
                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: sysStats.btPowered ? theme.accent : theme.surfaceHover
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: sysStats.btPowered ? parent.width - width - 3 : 3
                                        color: sysStats.btPowered ? "#000000" : theme.textMuted
                                        Behavior on x { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: sysStats.toggleBt()
                                    }
                                }
                            }

                            // Paired Devices List Title
                            Text {
                                text: "Paired & Known Devices"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: theme.textMuted
                            }

                            // Devices List
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                ListView {
                                    model: sysStats.btDevices
                                    spacing: 4

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 42
                                        radius: 8
                                        color: btItemHov.containsMouse ? theme.surfaceHover : theme.surface
                                        border.color: modelData.connected ? theme.accent : theme.border
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8

                                            Text {
                                                text: modelData.connected ? "󰂱" : "󰂯"
                                                font.pixelSize: 16
                                                color: modelData.connected ? theme.accent : theme.textMuted
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: 12
                                                    font.bold: modelData.connected
                                                    color: theme.text
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: modelData.connected ? "Connected" : "Disconnected"
                                                    font.pixelSize: 10
                                                    color: modelData.connected ? theme.success : theme.textMuted
                                                }
                                            }

                                            Rectangle {
                                                width: 72; height: 24; radius: 6
                                                color: btBtnHov.containsMouse ? (modelData.connected ? "#3b1a20" : theme.surfaceActive) : (modelData.connected ? "#261316" : theme.surface)
                                                border.color: modelData.connected ? theme.danger : theme.accent
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "Disconnect" : "Connect"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: modelData.connected ? theme.danger : theme.accent
                                                }
                                                MouseArea {
                                                    id: btBtnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            sysStats.disconnectBt(modelData.mac)
                                                        } else {
                                                            sysStats.connectBt(modelData.mac)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: btItemHov; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }
                            }

                            // Bluetooth Manager Shortcut Button
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 8
                                color: bluemanHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.accent; border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰂯"; font.pixelSize: 13; color: theme.accent }
                                    Text { text: "Bluetooth Settings (blueman-manager)"; font.pixelSize: 11; font.bold: true; color: theme.accent }
                                }

                                MouseArea {
                                    id: bluemanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closePopup(false)
                                        sysStats.openBtManager()
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL B: BATTERY & DEVICE RESOURCES (Accurate %, Sliders, Bar Position)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: batteryPanel
                    visible: root.activePopup === "battery"
                    y: root.barPosition === "top" ? 6 : (parent.height - height - 6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 120

                    width: 360
                    height: 590
                    radius: 18
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                    }

                    readonly property real rawPct: UPower.displayDevice?.percentage ?? 0
                    readonly property real normalizedPct: rawPct > 1.0 ? (rawPct / 100.0) : rawPct
                    readonly property int pctInt: Math.round(normalizedPct * 100)
                    readonly property bool charging: UPower.displayDevice?.state === 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        // Panel Header
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Battery & Device Resources"
                                font.pixelSize: 15
                                font.bold: true
                                color: theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: closeBatHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: theme.textMuted }
                                MouseArea {
                                    id: closeBatHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        // Battery Section
                        Rectangle {
                            Layout.fillWidth: true
                            height: 96
                            radius: 12
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: batteryPanel.charging ? "󰂄" : "󰁹"
                                        font.pixelSize: 22
                                        color: batteryPanel.charging ? theme.success : (batteryPanel.pctInt <= 20 ? theme.danger : theme.accent)
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: `${batteryPanel.pctInt}% ${batteryPanel.charging ? "Charging" : "Battery"}`
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: theme.text
                                        }
                                        Text {
                                            text: batteryPanel.charging ? "Plugged in to AC Power" : "Discharging on Battery"
                                            font.pixelSize: 11
                                            color: theme.textMuted
                                        }
                                    }
                                }

                                // Progress Bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 8
                                    radius: 4
                                    color: "#1c1c1c"

                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * Math.max(0.0, Math.min(1.0, batteryPanel.normalizedPct))
                                        radius: 4
                                        color: batteryPanel.charging ? theme.success : (batteryPanel.pctInt <= 20 ? theme.danger : theme.accent)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: `Rate: ${(UPower.displayDevice?.changeRate ?? 0).toFixed(1)} W`
                                        font.pixelSize: 10
                                        color: theme.textMuted
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: {
                                            let s = UPower.displayDevice?.timeToFull ?? 0
                                            if (batteryPanel.charging && s > 0) return `${Math.round(s / 60)} mins to full`
                                            let e = UPower.displayDevice?.timeToEmpty ?? 0
                                            if (!batteryPanel.charging && e > 0) return `${(e / 3600).toFixed(1)} hrs remaining`
                                            return "Normal capacity"
                                        }
                                        font.pixelSize: 10
                                        color: theme.textMuted
                                    }
                                }
                            }
                        }

                        // Sliders (Volume & Brightness)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 94
                            radius: 12
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Volume Slider
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        width: 28; height: 28; radius: 6
                                        color: bVolIconMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: sysStats.volumeMuted ? "󰝟" : (sysStats.volume > 50 ? "󰕾" : (sysStats.volume > 0 ? "󰖀" : "󰕿"))
                                            font.pixelSize: 16
                                            color: sysStats.volumeMuted ? theme.danger : theme.accent
                                        }
                                        MouseArea {
                                            id: bVolIconMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: sysStats.toggleMute()
                                        }
                                    }

                                    Item {
                                        id: bVolTrack
                                        Layout.fillWidth: true
                                        height: 22

                                        property bool dragging: false
                                        readonly property real fraction: Math.max(0.0, Math.min(1.0, sysStats.volume / 100.0))

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width; height: 8; radius: 4; color: "#1c1c1c"
                                            Rectangle {
                                                height: parent.height
                                                width: parent.width * bVolTrack.fraction
                                                radius: 4
                                                color: sysStats.volumeMuted ? theme.danger : theme.accent

                                                Behavior on width {
                                                    enabled: !bVolTrack.dragging
                                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 14; height: 14; radius: 7; color: theme.text
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(bVolTrack.width - width, (bVolTrack.width - width) * bVolTrack.fraction))

                                            Behavior on x {
                                                enabled: !bVolTrack.dragging
                                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateVol(mx) {
                                                let frac = Math.max(0.0, Math.min(1.0, mx / bVolTrack.width))
                                                sysStats.setVolume(frac * 100)
                                            }

                                            onClicked: mouse => {
                                                updateVol(mouse.x)
                                                sysStats.commitVolume()
                                            }
                                            onPressed: mouse => {
                                                bVolTrack.dragging = true
                                                updateVol(mouse.x)
                                            }
                                            onPositionChanged: mouse => {
                                                if (pressed) updateVol(mouse.x)
                                            }
                                            onReleased: {
                                                bVolTrack.dragging = false
                                                sysStats.commitVolume()
                                            }
                                            onWheel: wheel => {
                                                let step = wheel.angleDelta.y > 0 ? 4 : -4
                                                sysStats.adjustVolume(step)
                                            }
                                        }
                                    }

                                    Text {
                                        text: sysStats.volumeMuted ? "Muted" : `${sysStats.volume}%`
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                        Layout.minimumWidth: 38
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                // Brightness Slider
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        width: 28; height: 28; radius: 6
                                        color: "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰃠"
                                            font.pixelSize: 16
                                            color: theme.warning
                                        }
                                    }

                                    Item {
                                        id: bBrTrack
                                        Layout.fillWidth: true
                                        height: 22

                                        property bool dragging: false
                                        readonly property real fraction: Math.max(0.01, Math.min(1.0, sysStats.brightness / 100.0))

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width; height: 8; radius: 4; color: "#1c1c1c"
                                            Rectangle {
                                                height: parent.height
                                                width: parent.width * bBrTrack.fraction
                                                radius: 4
                                                color: theme.warning

                                                Behavior on width {
                                                    enabled: !bBrTrack.dragging
                                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 14; height: 14; radius: 7; color: theme.text
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(bBrTrack.width - width, (bBrTrack.width - width) * bBrTrack.fraction))

                                            Behavior on x {
                                                enabled: !bBrTrack.dragging
                                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateBr(mx) {
                                                let frac = Math.max(0.01, Math.min(1.0, mx / bBrTrack.width))
                                                sysStats.setBrightness(frac * 100)
                                            }

                                            onClicked: mouse => {
                                                updateBr(mouse.x)
                                                sysStats.commitBrightness()
                                            }
                                            onPressed: mouse => {
                                                bBrTrack.dragging = true
                                                updateBr(mouse.x)
                                            }
                                            onPositionChanged: mouse => {
                                                if (pressed) updateBr(mouse.x)
                                            }
                                            onReleased: {
                                                bBrTrack.dragging = false
                                                sysStats.commitBrightness()
                                            }
                                            onWheel: wheel => {
                                                let step = wheel.angleDelta.y > 0 ? 5 : -5
                                                sysStats.adjustBrightness(step)
                                            }
                                        }
                                    }

                                    Text {
                                        text: `${sysStats.brightness}%`
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                        Layout.minimumWidth: 38
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }

                        // BAR POSITION SETTING (Requirement: change the side bar rests - top, bottom, left, right)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 62
                            radius: 10
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Bar Rest Position"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.barPosition.toUpperCase()
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: theme.accent
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { id: "top", label: "Top", icon: "󰁝" },
                                            { id: "bottom", label: "Bottom", icon: "󰁅" }
                                        ]

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            height: 24
                                            radius: 6
                                            readonly property bool isSelected: root.barPosition === modelData.id
                                            color: isSelected ? theme.accentSurface : (posHov.containsMouse ? theme.surfaceHover : "#141414")
                                            border.color: isSelected ? theme.accent : theme.border
                                            border.width: 1

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text {
                                                    text: modelData.icon
                                                    font.pixelSize: 11
                                                    color: isSelected ? theme.accent : theme.textMuted
                                                }
                                                Text {
                                                    text: modelData.label
                                                    font.pixelSize: 10
                                                    font.weight: isSelected ? Font.Bold : Font.Normal
                                                    color: isSelected ? theme.text : theme.textMuted
                                                }
                                            }

                                            MouseArea {
                                                id: posHov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.setBarPosition(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CPU Stats Bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: 10
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "CPU Usage"; font.pixelSize: 11; font.weight: Font.Medium; color: theme.text }
                                    Item { Layout.fillWidth: true }
                                    Text { text: sysStats.cpuUsage; font.pixelSize: 11; font.bold: true; color: theme.accent }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 5; radius: 2.5; color: "#1c1c1c"
                                    Rectangle { height: parent.height; width: parent.width * sysStats.cpuPercent; radius: 2.5; color: theme.accent }
                                }
                            }
                        }

                        // RAM Stats Bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: 10
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Memory (RAM)"; font.pixelSize: 11; font.weight: Font.Medium; color: theme.text }
                                    Item { Layout.fillWidth: true }
                                    Text { text: `${sysStats.memUsedStr} / ${sysStats.memTotalStr}`; font.pixelSize: 11; font.bold: true; color: theme.accent }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 5; radius: 2.5; color: "#1c1c1c"
                                    Rectangle { height: parent.height; width: parent.width * sysStats.memPercent; radius: 2.5; color: theme.accent }
                                }
                            }
                        }

                        // Button to launch btop monitor
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 8
                            color: btopHover.containsMouse ? theme.surfaceHover : theme.surface
                            border.color: theme.border; border.width: 1

                            RowLayout {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "󰄪"; font.pixelSize: 13; color: theme.accent }
                                Text { text: "Open System Monitor (btop)"; font.pixelSize: 11; font.bold: true; color: theme.accent }
                            }

                            MouseArea {
                                id: btopHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.closePopup(false)
                                    sysStats.launchProc.command = ["kitty", "-e", "btop"]
                                    sysStats.launchProc.running = true
                                }
                            }
                        }

                        // Power Management Actions (Lock, Sleep, Restart, Power Off)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: [
                                    { id: "lock", label: "Lock", icon: "󰌾", color: theme.accent, danger: false },
                                    { id: "sleep", label: "Sleep", icon: "󰒲", color: theme.warning, danger: false },
                                    { id: "reboot", label: "Restart", icon: "󰜉", color: theme.accent, danger: false },
                                    { id: "poweroff", label: "Power", icon: "󰐥", color: theme.danger, danger: true }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    height: 32
                                    radius: 8
                                    color: pwrBtnHov.containsMouse ? (modelData.danger ? "#2b1419" : theme.surfaceHover) : theme.surface
                                    border.color: pwrBtnHov.containsMouse ? (modelData.danger ? theme.danger : theme.accent) : theme.border
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: 13
                                            color: pwrBtnHov.containsMouse ? (modelData.danger ? theme.danger : theme.accent) : modelData.color
                                        }

                                        Text {
                                            text: modelData.label
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: pwrBtnHov.containsMouse ? theme.text : theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: pwrBtnHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.closePopup(false)
                                            sysStats.powerAction(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL C: EXPANDED BIG CLOCK & INTERACTIVE CALENDAR
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    visible: root.activePopup === "calendar"
                    y: root.barPosition === "top" ? 6 : (parent.height - height - 6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360
                    height: 390
                    radius: 20
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                    }

                    property var currentDate: new Date()
                    property int viewYear: currentDate.getFullYear()
                    property int viewMonth: currentDate.getMonth()

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                id: bigClockTime
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(new Date(), "hh:mm:ss A")
                                font.pixelSize: 28
                                font.weight: Font.Bold
                                color: theme.text

                                Timer {
                                    interval: 1000
                                    running: root.activePopup === "calendar"
                                    repeat: true
                                    onTriggered: bigClockTime.text = Qt.formatDateTime(new Date(), "hh:mm:ss A")
                                }
                            }

                            Text {
                                id: bigClockDate
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: theme.accent
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: theme.border
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: {
                                    let d = new Date(parent.parent.parent.viewYear, parent.parent.parent.viewMonth, 1)
                                    return Qt.formatDate(d, "MMMM yyyy")
                                }
                                font.pixelSize: 14
                                font.bold: true
                                color: theme.text
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 28; height: 28; radius: 14; color: prevHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "󰅁"; font.pixelSize: 14; color: theme.text }
                                MouseArea {
                                    id: prevHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    onClicked: {
                                        let p = parent.parent.parent.parent
                                        if (p.viewMonth === 0) { p.viewMonth = 11; p.viewYear-- } else { p.viewMonth-- }
                                    }
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 14; color: nextHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "󰅂"; font.pixelSize: 14; color: theme.text }
                                MouseArea {
                                    id: nextHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    onClicked: {
                                        let p = parent.parent.parent.parent
                                        if (p.viewMonth === 11) { p.viewMonth = 0; p.viewYear++ } else { p.viewMonth++ }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Repeater {
                                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: theme.textMuted
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            rowSpacing: 4
                            columnSpacing: 4

                            Repeater {
                                model: 35

                                delegate: Rectangle {
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8

                                    readonly property var calRoot: parent.parent.parent
                                    readonly property int firstDay: new Date(calRoot.viewYear, calRoot.viewMonth, 1).getDay()
                                    readonly property int totalDays: new Date(calRoot.viewYear, calRoot.viewMonth + 1, 0).getDate()
                                    readonly property int dayNumber: index - firstDay + 1
                                    readonly property bool isValidDay: dayNumber >= 1 && dayNumber <= totalDays

                                    readonly property bool isToday: {
                                        let now = new Date()
                                        return isValidDay && dayNumber === now.getDate() && calRoot.viewMonth === now.getMonth() && calRoot.viewYear === now.getFullYear()
                                    }

                                    color: isToday ? theme.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        visible: parent.isValidDay
                                        text: parent.isValidDay ? String(parent.dayNumber) : ""
                                        font.pixelSize: 12
                                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                                        color: parent.isToday ? "#000000" : theme.text
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL D: APP LIST UI (Requirement: opens from top bar, extending width & height)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: appsPanel
                    readonly property bool isShown: root.activePopup === "apps" && !root.isPopupClosing
                    visible: root.displayedPopup === "apps"
                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 520
                    // Flatten the side that connects to the pill
                    topLeftRadius: root.barPosition === "bottom" ? 20 : 0
                    topRightRadius: root.barPosition === "bottom" ? 20 : 0
                    bottomLeftRadius: root.barPosition !== "bottom" ? 20 : 0
                    bottomRightRadius: root.barPosition !== "bottom" ? 20 : 0
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    scale: isShown ? 1.0 : 0.95
                    opacity: isShown ? 1.0 : 0.0
                    transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    transform: Translate {
                        y: appsPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    property string searchQuery: ""
                    property string activeCategory: "All"
                    property int selectedIndex: 0

                    function resetSearch() {
                        searchQuery = ""
                        activeCategory = "All"
                        selectedIndex = 0
                        if (appSearchInput) {
                            appSearchInput.text = ""
                            appSearchInput.forceActiveFocus()
                        }
                        currentApps = getFilteredApps()
                        if (appsScrollView && appsScrollView.contentItem) {
                            appsScrollView.contentItem.contentY = 0
                        }
                    }

                    function getFilteredApps() {
                        let list = sysStats.appsList || []
                        let q = searchQuery.toLowerCase().trim()
                        let cat = activeCategory
                        return list.filter(app => {
                            let matchCat = (cat === "All") || (app.category === cat)
                            if (!matchCat) return false
                            if (!q) return true
                            return (app.name && app.name.toLowerCase().includes(q)) ||
                                   (app.comment && app.comment.toLowerCase().includes(q)) ||
                                   (app.exec && app.exec.toLowerCase().includes(q))
                        })
                    }

                    property var currentApps: getFilteredApps()

                    onSearchQueryChanged: {
                        currentApps = getFilteredApps()
                        selectedIndex = 0
                        if (appsScrollView && appsScrollView.contentItem) {
                            appsScrollView.contentItem.contentY = 0
                        }
                    }
                    onActiveCategoryChanged: {
                        currentApps = getFilteredApps()
                        selectedIndex = 0
                        if (appsScrollView && appsScrollView.contentItem) {
                            appsScrollView.contentItem.contentY = 0
                        }
                    }
                    Connections {
                        target: sysStats
                        function onAppsListChanged() {
                            appsPanel.currentApps = appsPanel.getFilteredApps()
                        }
                    }

                    onVisibleChanged: {
                        if (visible) {
                            resetSearch()
                            sysStats.loadApps()
                        }
                    }

                    onIsShownChanged: {
                        if (isShown) {
                            resetSearch()
                            sysStats.loadApps()
                        }
                    }

                    onSelectedIndexChanged: {
                        if (appsScrollView) appsScrollView.scrollToSelected()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "󰀻"
                                font.pixelSize: 18
                                color: theme.accent
                            }

                            Text {
                                text: "Applications"
                                font.pixelSize: 16
                                font.bold: true
                                color: theme.text
                            }

                            Rectangle {
                                height: 20
                                radius: 10
                                color: theme.surface
                                border.color: theme.border
                                border.width: 1
                                width: appCountText.implicitWidth + 12

                                Text {
                                    id: appCountText
                                    anchors.centerIn: parent
                                    text: `${appsPanel.currentApps.length} apps`
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: theme.textMuted
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: closeAppsHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: theme.textMuted }
                                MouseArea {
                                    id: closeAppsHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        // Search Box
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 10
                            color: theme.surface
                            border.color: appSearchInput.activeFocus ? theme.accent : theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: "󰍉"
                                    font.pixelSize: 14
                                    color: appSearchInput.activeFocus ? theme.accent : theme.textMuted
                                }

                                TextInput {
                                    id: appSearchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 13
                                    color: theme.text
                                    selectByMouse: true
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        text: "Search applications by name or command..."
                                        font.pixelSize: 13
                                        color: theme.textMuted
                                        visible: !parent.text && !parent.activeFocus
                                    }

                                    onTextChanged: appsPanel.searchQuery = text

                                    Keys.onEscapePressed: root.closePopup(false)
                                    Keys.onReturnPressed: {
                                        if (appsPanel.currentApps.length > 0) {
                                            let idx = Math.max(0, Math.min(appsPanel.selectedIndex, appsPanel.currentApps.length - 1))
                                            sysStats.launchApp(appsPanel.currentApps[idx].exec)
                                            root.closePopup(false)
                                        }
                                    }
                                    Keys.onDownPressed: {
                                        if (appsPanel.currentApps.length > 0) {
                                            let next = appsPanel.selectedIndex + 2
                                            if (next >= appsPanel.currentApps.length && appsPanel.selectedIndex % 2 === 0 && appsPanel.selectedIndex + 1 < appsPanel.currentApps.length) {
                                                next = appsPanel.selectedIndex + 1
                                            }
                                            appsPanel.selectedIndex = Math.min(appsPanel.currentApps.length - 1, next)
                                        }
                                    }
                                    Keys.onUpPressed: {
                                        if (appsPanel.currentApps.length > 0) {
                                            appsPanel.selectedIndex = Math.max(0, appsPanel.selectedIndex - 2)
                                        }
                                    }
                                    Keys.onRightPressed: {
                                        if (text === "" || cursorPosition === text.length) {
                                            if (appsPanel.currentApps.length > 0) {
                                                appsPanel.selectedIndex = Math.min(appsPanel.currentApps.length - 1, appsPanel.selectedIndex + 1)
                                            }
                                        } else {
                                            event.accepted = false
                                        }
                                    }
                                    Keys.onLeftPressed: {
                                        if (text === "" || cursorPosition === 0) {
                                            if (appsPanel.currentApps.length > 0) {
                                                appsPanel.selectedIndex = Math.max(0, appsPanel.selectedIndex - 1)
                                            }
                                        } else {
                                            event.accepted = false
                                        }
                                    }
                                    Keys.onTabPressed: {
                                        if (appsPanel.currentApps.length > 0) {
                                            appsPanel.selectedIndex = (appsPanel.selectedIndex + 1) % appsPanel.currentApps.length
                                        }
                                    }
                                    Keys.onBacktabPressed: {
                                        if (appsPanel.currentApps.length > 0) {
                                            appsPanel.selectedIndex = (appsPanel.selectedIndex - 1 + appsPanel.currentApps.length) % appsPanel.currentApps.length
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: appSearchInput.text !== ""
                                    width: 18; height: 18; radius: 9
                                    color: clearSearchHov.containsMouse ? theme.surfaceHover : "transparent"
                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: theme.textMuted }
                                    MouseArea {
                                        id: clearSearchHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            appSearchInput.text = ""
                                            appSearchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        // Category Filter Pills
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: ["All", "System", "Development", "Internet", "Media", "Office", "Utility"]

                                delegate: Rectangle {
                                    required property string modelData
                                    height: 24
                                    radius: 12
                                    readonly property bool isSelected: appsPanel.activeCategory === modelData
                                    color: isSelected ? theme.accentSurface : (catHov.containsMouse ? theme.surfaceHover : theme.surface)
                                    border.color: isSelected ? theme.accent : theme.border
                                    border.width: 1
                                    width: catText.implicitWidth + 16

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 11
                                        font.weight: parent.isSelected ? Font.Bold : Font.Normal
                                        color: parent.isSelected ? theme.accent : theme.textMuted
                                    }

                                    MouseArea {
                                        id: catHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appsPanel.activeCategory = modelData
                                    }
                                }
                            }
                        }

                        // App Cards Grid (Flow for proper 2-col layout without overlapping)
                        ScrollView {
                            id: appsScrollView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth

                            function scrollToSelected() {
                                if (!contentItem) return
                                let row = Math.floor(appsPanel.selectedIndex / 2)
                                let itemY = row * 64
                                let itemH = 56
                                let viewTop = contentItem.contentY
                                let viewH = height
                                if (itemY < viewTop) {
                                    contentItem.contentY = Math.max(0, itemY - 6)
                                } else if (itemY + itemH > viewTop + viewH) {
                                    contentItem.contentY = Math.min(contentItem.contentHeight - viewH, itemY + itemH - viewH + 6)
                                }
                            }

                            Flow {
                                id: appsFlow
                                width: appsScrollView.availableWidth
                                spacing: 8

                                Repeater {
                                    model: appsPanel.currentApps

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        readonly property bool isSelected: appsPanel.selectedIndex === index
                                        // Each card = half the Flow width minus half the spacing
                                        width: (appsFlow.width - 8) / 2
                                        height: 56
                                        radius: 10
                                        color: isSelected ? theme.accentSurface : (appCardMouse.containsMouse ? theme.surfaceHover : theme.surface)
                                        border.color: isSelected ? theme.accent : (appCardMouse.containsMouse ? theme.borderLight : theme.border)
                                        border.width: isSelected ? 1.5 : 1
                                        clip: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            // Icon Container
                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 8
                                                color: "#0f0f0f"
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36

                                                Image {
                                                    id: appImg
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    fillMode: Image.PreserveAspectFit
                                                    source: modelData.icon_path ? ("file://" + modelData.icon_path) : ""
                                                    visible: status === Image.Ready
                                                    smooth: true
                                                    mipmap: true
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !appImg.visible || appImg.status !== Image.Ready
                                                    text: root.getAppIcon(modelData.icon, modelData.name)
                                                    font.pixelSize: 18
                                                    color: theme.accent
                                                }
                                            }

                                            // Name & Info
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: isSelected ? theme.accent : theme.text
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.comment || modelData.category || "Application"
                                                    font.pixelSize: 10
                                                    color: theme.textMuted
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: appCardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: appsPanel.selectedIndex = index
                                            onClicked: {
                                                sysStats.launchApp(modelData.exec)
                                                root.closePopup(false)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }


                // ─────────────────────────────────────────────────────────────
                // PANEL E: CLIPBOARD HISTORY UI (Ability to see & paste photos + text)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: clipboardPanel
                    readonly property bool isShown: root.activePopup === "clipboard" && !root.isPopupClosing
                    visible: root.displayedPopup === "clipboard"

                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 540
                    topLeftRadius: root.barPosition === "bottom" ? 20 : 0
                    topRightRadius: root.barPosition === "bottom" ? 20 : 0
                    bottomLeftRadius: root.barPosition !== "bottom" ? 20 : 0
                    bottomRightRadius: root.barPosition !== "bottom" ? 20 : 0
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    scale: isShown ? 1.0 : 0.95
                    opacity: isShown ? 1.0 : 0.0
                    transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    transform: Translate {
                        y: clipboardPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    property string searchQuery: ""
                    property string activeFilter: "All"
                    property int selectedIndex: 0

                    function resetSearch() {
                        searchQuery = ""
                        activeFilter = "All"
                        selectedIndex = 0
                        if (clipSearchInput) {
                            clipSearchInput.text = ""
                            clipSearchInput.forceActiveFocus()
                        }
                        currentClips = getFilteredClips()
                        if (clipListView) {
                            clipListView.positionViewAtIndex(0, ListView.Beginning)
                        }
                    }

                    function getFilteredClips() {
                        let list = sysStats.clipboardList || []
                        let q = searchQuery.toLowerCase().trim()
                        let f = activeFilter
                        return list.filter(item => {
                            if (f === "Text" && item.type !== "text") return false
                            if (f === "Images" && item.type !== "image") return false
                            if (!q) return true
                            return (item.preview && item.preview.toLowerCase().includes(q)) ||
                                   (item.dims && item.dims.toLowerCase().includes(q)) ||
                                   (item.size && item.size.toLowerCase().includes(q))
                        })
                    }

                    property var currentClips: getFilteredClips()

                    onSearchQueryChanged: {
                        currentClips = getFilteredClips()
                        selectedIndex = 0
                        if (clipListView) clipListView.positionViewAtIndex(0, ListView.Beginning)
                    }
                    onActiveFilterChanged: {
                        currentClips = getFilteredClips()
                        selectedIndex = 0
                        if (clipListView) clipListView.positionViewAtIndex(0, ListView.Beginning)
                    }
                    Connections {
                        target: sysStats
                        function onClipboardListChanged() {
                            clipboardPanel.currentClips = clipboardPanel.getFilteredClips()
                        }
                    }

                    onVisibleChanged: {
                        if (visible) {
                            resetSearch()
                            sysStats.loadClipboard()
                        }
                    }

                    onIsShownChanged: {
                        if (isShown) {
                            resetSearch()
                            sysStats.loadClipboard()
                        }
                    }

                    onSelectedIndexChanged: {
                        if (clipListView && selectedIndex >= 0 && selectedIndex < currentClips.length) {
                            clipListView.positionViewAtIndex(selectedIndex, ListView.Contain)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "󰅍"
                                font.pixelSize: 18
                                color: theme.accent
                            }

                            Text {
                                text: "Clipboard History"
                                font.pixelSize: 16
                                font.bold: true
                                color: theme.text
                            }

                            Rectangle {
                                height: 20
                                radius: 10
                                color: theme.surface
                                border.color: theme.border
                                border.width: 1
                                width: clipCountText.implicitWidth + 12

                                Text {
                                    id: clipCountText
                                    anchors.centerIn: parent
                                    text: `${clipboardPanel.currentClips.length} items`
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: theme.textMuted
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Clear All Button
                            Rectangle {
                                height: 26
                                radius: 13
                                color: clearClipsHov.containsMouse ? "#2d1419" : theme.surface
                                border.color: clearClipsHov.containsMouse ? theme.danger : theme.border
                                border.width: 1
                                width: clearClipsRow.implicitWidth + 14

                                RowLayout {
                                    id: clearClipsRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "󰆴"
                                        font.pixelSize: 11
                                        color: clearClipsHov.containsMouse ? theme.danger : theme.textMuted
                                    }
                                    Text {
                                        text: "Clear"
                                        font.pixelSize: 11
                                        color: clearClipsHov.containsMouse ? theme.danger : theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: clearClipsHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sysStats.clearClipboard()
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: closeClipHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: theme.textMuted }
                                MouseArea {
                                    id: closeClipHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        // Search Box
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 10
                            color: theme.surface
                            border.color: clipSearchInput.activeFocus ? theme.accent : theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: "󰍉"
                                    font.pixelSize: 14
                                    color: clipSearchInput.activeFocus ? theme.accent : theme.textMuted
                                }

                                TextInput {
                                    id: clipSearchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 13
                                    color: theme.text
                                    selectByMouse: true
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        text: "Search clipboard history (text, links, images)..."
                                        font.pixelSize: 13
                                        color: theme.textMuted
                                        visible: !parent.text && !parent.activeFocus
                                    }

                                    onTextChanged: clipboardPanel.searchQuery = text

                                    Keys.onEscapePressed: root.closePopup(false)
                                    Keys.onReturnPressed: {
                                        if (clipboardPanel.currentClips.length > 0) {
                                            let idx = Math.max(0, Math.min(clipboardPanel.selectedIndex, clipboardPanel.currentClips.length - 1))
                                            sysStats.copyClipboard(clipboardPanel.currentClips[idx].id, true)
                                            root.closePopup(false)
                                        }
                                    }
                                    Keys.onDownPressed: {
                                        if (clipboardPanel.currentClips.length > 0) {
                                            clipboardPanel.selectedIndex = Math.min(clipboardPanel.currentClips.length - 1, clipboardPanel.selectedIndex + 1)
                                        }
                                    }
                                    Keys.onUpPressed: {
                                        if (clipboardPanel.currentClips.length > 0) {
                                            clipboardPanel.selectedIndex = Math.max(0, clipboardPanel.selectedIndex - 1)
                                        }
                                    }
                                    Keys.onTabPressed: {
                                        if (clipboardPanel.currentClips.length > 0) {
                                            clipboardPanel.selectedIndex = (clipboardPanel.selectedIndex + 1) % clipboardPanel.currentClips.length
                                        }
                                    }
                                    Keys.onBacktabPressed: {
                                        if (clipboardPanel.currentClips.length > 0) {
                                            clipboardPanel.selectedIndex = (clipboardPanel.selectedIndex - 1 + clipboardPanel.currentClips.length) % clipboardPanel.currentClips.length
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: clipSearchInput.text !== ""
                                    width: 18; height: 18; radius: 9
                                    color: clearClipSearchHov.containsMouse ? theme.surfaceHover : "transparent"
                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: theme.textMuted }
                                    MouseArea {
                                        id: clearClipSearchHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            clipSearchInput.text = ""
                                            clipSearchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        // Filter Pills (All, Text, Images)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: ["All", "Text", "Images"]

                                delegate: Rectangle {
                                    required property string modelData
                                    height: 24
                                    radius: 12
                                    readonly property bool isSelected: clipboardPanel.activeFilter === modelData
                                    color: isSelected ? theme.accentSurface : (filterHov.containsMouse ? theme.surfaceHover : theme.surface)
                                    border.color: isSelected ? theme.accent : theme.border
                                    border.width: 1
                                    width: filterText.implicitWidth + 18

                                    RowLayout {
                                        id: filterText
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: modelData === "Images" ? "󰋩" : (modelData === "Text" ? "󰦨" : "󰅍")
                                            font.pixelSize: 11
                                            color: parent.parent.isSelected ? theme.accent : theme.textMuted
                                        }

                                        Text {
                                            text: modelData
                                            font.pixelSize: 11
                                            font.weight: parent.parent.isSelected ? Font.Bold : Font.Normal
                                            color: parent.parent.isSelected ? theme.accent : theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: filterHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            clipboardPanel.activeFilter = modelData
                                            clipSearchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        // Clipboard List View
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: clipListView
                                width: parent.width
                                spacing: 8
                                model: clipboardPanel.currentClips
                                currentIndex: clipboardPanel.selectedIndex

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool isSelected: clipboardPanel.selectedIndex === index
                                    readonly property bool isImg: modelData.type === "image"
                                    width: parent.width
                                    height: isImg ? 108 : 58
                                    radius: 10
                                    color: isSelected ? theme.accentSurface : (clipItemMouse.containsMouse ? theme.surfaceHover : theme.surface)
                                    border.color: isSelected ? theme.accent : (clipItemMouse.containsMouse ? theme.borderLight : theme.border)
                                    border.width: isSelected ? 1.5 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 12

                                        // Left Visual: Thumbnail (if image) or Icon (if text)
                                        Rectangle {
                                            Layout.preferredWidth: isImg ? 92 : 40
                                            Layout.fillHeight: true
                                            radius: 8
                                            color: "#121212"
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                visible: isImg
                                                fillMode: Image.PreserveAspectFit
                                                source: isImg && modelData.thumb ? ("file://" + modelData.thumb) : ""
                                                asynchronous: true
                                                smooth: true
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !isImg
                                                text: "󰦨"
                                                font.pixelSize: 16
                                                color: theme.accent
                                            }
                                        }

                                        // Center Content: Info & Text/Image description
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                visible: isImg

                                                Text {
                                                    text: "󰋩 Image"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: theme.text
                                                }

                                                Rectangle {
                                                    visible: !!modelData.dims
                                                    height: 18
                                                    radius: 4
                                                    color: theme.accentSurface
                                                    border.color: theme.accent
                                                    border.width: 1
                                                    width: dimsText.implicitWidth + 8

                                                    Text {
                                                        id: dimsText
                                                        anchors.centerIn: parent
                                                        text: modelData.dims || ""
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        color: theme.accent
                                                    }
                                                }

                                                Text {
                                                    text: modelData.size || ""
                                                    font.pixelSize: 10
                                                    color: theme.textMuted
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: isImg ? "Click to paste image into active window" : modelData.preview
                                                font.pixelSize: 12
                                                font.family: !isImg ? "monospace" : ""
                                                color: isImg ? theme.textMuted : theme.text
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.WrapAnywhere
                                            }
                                        }

                                        // Actions: Copy & Delete
                                        RowLayout {
                                            spacing: 6

                                             Rectangle {
                                                width: 30; height: 30; radius: 15
                                                color: copyHov.containsMouse ? theme.accentSurface : "transparent"
                                                border.color: copyHov.containsMouse ? theme.accent : "transparent"
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰆏"
                                                    font.pixelSize: 13
                                                    color: copyHov.containsMouse ? theme.accent : theme.textMuted
                                                }

                                                MouseArea {
                                                    id: copyHov
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        sysStats.copyClipboard(modelData.id, true)
                                                        root.closePopup(false)
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 30; height: 30; radius: 15
                                                color: delHov.containsMouse ? "#2d1419" : "transparent"
                                                border.color: delHov.containsMouse ? theme.danger : "transparent"
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰆴"
                                                    font.pixelSize: 13
                                                    color: delHov.containsMouse ? theme.danger : theme.textMuted
                                                }

                                                MouseArea {
                                                    id: delHov
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: sysStats.deleteClipboard(modelData.id)
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: clipItemMouse
                                        anchors.fill: parent
                                        z: -1
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: clipboardPanel.selectedIndex = index
                                        onClicked: {
                                            sysStats.copyClipboard(modelData.id, true)
                                            root.closePopup(false)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
