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

    // Bar side position: "top", "bottom", "left", "right"
    property string barPosition: "top"
    readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"

    // Workspace change indicator transient state
    property bool showingWorkspaces: false
    Timer {
        id: wsIndicatorTimer
        interval: 1800
        onTriggered: root.showingWorkspaces = false
    }

    function triggerWorkspaceIndicator() {
        root.showingWorkspaces = true
        wsIndicatorTimer.restart()
    }

    function setBarPosition(pos) {
        if (pos === "top" || pos === "bottom" || pos === "left" || pos === "right") {
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
        property int activeWorkspace: 1
        property var workspaces: ([
            { "idx": 1, "name": "1", "active": true },
            { "idx": 2, "name": "2", "active": false },
            { "idx": 3, "name": "3", "active": false }
        ])
        property var appsList: []

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
                            sysStats.activeWorkspace = msg.active_ws || 1
                            if (Array.isArray(msg.workspaces) && msg.workspaces.length > 0) {
                                sysStats.workspaces = msg.workspaces
                            }
                            if (msg.ws_event) {
                                root.triggerWorkspaceIndicator()
                            }
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
        }

        function toggleMute() {
            actionProc.command = ["python3", sysStats.scriptPath, "toggle-mute"]
            actionProc.running = true
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
                    top: root.barPosition === "top" || root.barPosition === "left" || root.barPosition === "right"
                    bottom: root.barPosition === "bottom" || root.barPosition === "left" || root.barPosition === "right"
                    left: root.barPosition === "top" || root.barPosition === "bottom" || root.barPosition === "left"
                    right: root.barPosition === "top" || root.barPosition === "bottom" || root.barPosition === "right"
                }

                implicitHeight: (root.barPosition === "top" || root.barPosition === "bottom") ? theme.barHeight : 0
                implicitWidth: (root.barPosition === "left" || root.barPosition === "right") ? theme.barHeight : 0
                color: "transparent"

                WlrLayershell.namespace: "quickshell:simple-bar"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.exclusiveZone: theme.barHeight
                exclusionMode: ExclusionMode.Normal

                // Dismiss popup when clicking empty space on the bar
                MouseArea {
                    anchors.fill: parent
                    z: 1
                    enabled: root.activePopup !== ""
                    onClicked: root.activePopup = ""
                }

                // ─────────────────────────────────────────────────────────────
                // UNIFIED PILL CLUSTER: Center Pill + Revealable Status Balls
                // ─────────────────────────────────────────────────────────────
                Item {
                    id: pillCluster
                    z: 10
                    anchors.centerIn: parent

                    // Orientation dimensions
                    height: root.isVerticalBar ?
                            (showBalls ? (centerPill.height + leftBall.height + rightBall.height + 36) : (centerPill.height + 12)) :
                            theme.barHeight

                    width: root.isVerticalBar ?
                           theme.barHeight :
                           (showBalls ? (centerPill.width + leftBall.width + rightBall.width + 36) : (centerPill.width + 12))

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    property bool isHovered: false
                    // Balls collapse when workspaces are actively switching or popup is open
                    readonly property bool showBalls: (isHovered || (root.activePopup !== "")) && !root.showingWorkspaces

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
                        interval: 400
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
                        anchors.centerIn: parent
                        radius: theme.pillRadius
                        color: centerPillMouse.containsMouse || root.activePopup === "calendar" ? theme.surfaceHover : theme.bg
                        border.color: (root.activePopup === "calendar" || root.showingWorkspaces) ? theme.accent : theme.border
                        border.width: 1

                        // Horizontal vs Vertical Pill dimensions
                        width: root.isVerticalBar ? theme.pillHeight :
                               (root.showingWorkspaces ? (workspacesRow.implicitWidth + 32) : (pillContentRow.implicitWidth + 36))
                        height: root.isVerticalBar ?
                                (root.showingWorkspaces ? (workspacesCol.implicitHeight + 32) : (pillContentCol.implicitHeight + 24)) :
                                theme.pillHeight

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

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
                            visible: !root.isVerticalBar

                            // 1. Normal View (Clock, Date, Focused App)
                            RowLayout {
                                id: pillContentRow
                                anchors.centerIn: parent
                                spacing: 8
                                visible: opacity > 0.01
                                opacity: (!centerPill.showingVolume && !root.showingWorkspaces) ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                // Clock + Date
                                RowLayout {
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

                                // Focused Application Badge (Extends Pill Width!)
                                RowLayout {
                                    visible: sysStats.focusedApp !== ""
                                    spacing: 8

                                    Rectangle {
                                        width: 1; height: 14; color: theme.borderLight
                                    }

                                    Rectangle {
                                        id: appBadge
                                        height: 24
                                        radius: 12
                                        color: appBadgeMouse.containsMouse || root.activePopup === "apps" ? theme.surfaceHover : "transparent"
                                        border.color: root.activePopup === "apps" ? theme.accent : (appBadgeMouse.containsMouse ? theme.borderLight : "transparent")
                                        border.width: 1
                                        width: appBadgeRow.implicitWidth + 14

                                        RowLayout {
                                            id: appBadgeRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: root.getAppIcon(sysStats.focusedApp, sysStats.focusedAppName)
                                                font.pixelSize: 13
                                                color: theme.accent
                                            }

                                            Text {
                                                text: sysStats.focusedAppName || sysStats.focusedApp
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 160
                                            }
                                        }

                                        MouseArea {
                                            id: appBadgeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activePopup = root.activePopup === "apps" ? "" : "apps"
                                            }
                                        }
                                    }
                                }

                                // Quick Apps Launcher Button
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    color: appsIconMouse.containsMouse || root.activePopup === "apps" ? theme.surfaceHover : "transparent"
                                    border.color: root.activePopup === "apps" ? theme.accent : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰀻"
                                        font.pixelSize: 13
                                        color: root.activePopup === "apps" ? theme.accent : theme.textMuted
                                    }

                                    MouseArea {
                                        id: appsIconMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activePopup = root.activePopup === "apps" ? "" : "apps"
                                        }
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
                                        border.color: isAct ? theme.accent : theme.border
                                        border.width: 1

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

                            // 3. Volume HUD View
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: opacity > 0.01
                                opacity: (centerPill.showingVolume && !root.showingWorkspaces) ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Text {
                                    text: sysStats.volumeMuted ? "󰝟" : (sysStats.volume > 50 ? "󰕾" : (sysStats.volume > 0 ? "󰖀" : "󰕿"))
                                    font.pixelSize: 14
                                    color: sysStats.volumeMuted ? theme.danger : theme.accent
                                }

                                Text {
                                    text: sysStats.volumeMuted ? "Muted" : `${sysStats.volume}%`
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: theme.text
                                }
                            }
                        }

                        // ─────────────────────────────────────────────────────
                        // B. VERTICAL BAR CONTENT (Left / Right positions)
                        // ─────────────────────────────────────────────────────
                        Item {
                            anchors.fill: parent
                            visible: root.isVerticalBar

                            ColumnLayout {
                                id: pillContentCol
                                anchors.centerIn: parent
                                spacing: 8
                                visible: !root.showingWorkspaces

                                // Clock stacked
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 1
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Qt.formatDateTime(new Date(), "hh")
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Qt.formatDateTime(new Date(), "mm")
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: theme.textMuted
                                    }
                                }

                                // Focused App Icon
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: sysStats.focusedApp !== ""
                                    width: 24; height: 24; radius: 12
                                    color: root.activePopup === "apps" ? theme.accentSurface : "transparent"
                                    border.color: root.activePopup === "apps" ? theme.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.getAppIcon(sysStats.focusedApp, sysStats.focusedAppName)
                                        font.pixelSize: 13
                                        color: theme.accent
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activePopup = root.activePopup === "apps" ? "" : "apps"
                                    }
                                }
                            }

                            // Workspaces Column
                            ColumnLayout {
                                id: workspacesCol
                                anchors.centerIn: parent
                                spacing: 6
                                visible: root.showingWorkspaces

                                Repeater {
                                    model: sysStats.workspaces

                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool isAct: modelData.active
                                        width: 24
                                        height: isAct ? 30 : 22
                                        radius: 11
                                        color: isAct ? theme.accent : theme.surface
                                        border.color: isAct ? theme.accent : theme.border
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name || String(modelData.idx)
                                            font.pixelSize: 10
                                            font.weight: isAct ? Font.Bold : Font.Normal
                                            color: isAct ? "#000000" : theme.textMuted
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                sysStats.focusWorkspace(modelData.idx)
                                                wsIndicatorTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Center Pill Mouse interaction
                        MouseArea {
                            id: centerPillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.showingWorkspaces) {
                                    root.showingWorkspaces = false
                                } else {
                                    root.activePopup = root.activePopup === "calendar" ? "" : "calendar"
                                }
                            }

                            // Scrolling adjusts audio volume
                            onWheel: wheel => {
                                let step = wheel.angleDelta.y > 0 ? 4 : -4
                                sysStats.adjustVolume(step)
                                centerPill.showingVolume = true
                                centerPill.volTimer.restart()
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

                        // Anchoring: Horizontal (left of centerPill) vs Vertical (above centerPill)
                        anchors.verticalCenter: !root.isVerticalBar ? centerPill.verticalCenter : undefined
                        anchors.right: !root.isVerticalBar ? centerPill.left : undefined
                        anchors.rightMargin: !root.isVerticalBar ? (pillCluster.showBalls ? 10 : -theme.ballRadius) : 0

                        anchors.horizontalCenter: root.isVerticalBar ? centerPill.horizontalCenter : undefined
                        anchors.bottom: root.isVerticalBar ? centerPill.top : undefined
                        anchors.bottomMargin: root.isVerticalBar ? (pillCluster.showBalls ? 10 : -theme.ballRadius) : 0

                        property bool isBallHovered: leftBallMouse.containsMouse
                        width: (!root.isVerticalBar && isBallHovered) ? Math.max(theme.ballSize, leftBallContent.implicitWidth + 20) : theme.ballSize
                        clip: true

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                        Behavior on anchors.rightMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        color: leftBall.isBallHovered || root.activePopup === "wifi" ? theme.surfaceHover : theme.bg
                        border.color: root.activePopup === "wifi" ? theme.accent : theme.border
                        border.width: 1

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
                                visible: !root.isVerticalBar && leftBall.isBallHovered
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

                        // Anchoring: Horizontal (right of centerPill) vs Vertical (below centerPill)
                        anchors.verticalCenter: !root.isVerticalBar ? centerPill.verticalCenter : undefined
                        anchors.left: !root.isVerticalBar ? centerPill.right : undefined
                        anchors.leftMargin: !root.isVerticalBar ? (pillCluster.showBalls ? 10 : -theme.ballRadius) : 0

                        anchors.horizontalCenter: root.isVerticalBar ? centerPill.horizontalCenter : undefined
                        anchors.top: root.isVerticalBar ? centerPill.bottom : undefined
                        anchors.topMargin: root.isVerticalBar ? (pillCluster.showBalls ? 10 : -theme.ballRadius) : 0

                        readonly property real rawPct: UPower.displayDevice?.percentage ?? 0
                        readonly property real normalizedPct: rawPct > 1.0 ? (rawPct / 100.0) : rawPct
                        readonly property int pctInt: Math.round(normalizedPct * 100)
                        readonly property bool charging: UPower.displayDevice?.state === 1

                        property bool isBallHovered: rightBallMouse.containsMouse
                        width: (!root.isVerticalBar && isBallHovered) ? Math.max(theme.ballSize, rightBallContent.implicitWidth + 20) : theme.ballSize
                        clip: true

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                        Behavior on anchors.leftMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on anchors.topMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        color: rightBall.isBallHovered || root.activePopup === "battery" ? theme.surfaceHover : theme.bg
                        border.color: root.activePopup === "battery" ? theme.accent : theme.border
                        border.width: 1

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
                                visible: !root.isVerticalBar && rightBall.isBallHovered
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

                visible: root.activePopup !== ""

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                margins {
                    top: root.barPosition === "top" ? theme.barHeight : 0
                    bottom: root.barPosition === "bottom" ? theme.barHeight : 0
                    left: root.barPosition === "left" ? theme.barHeight : 0
                    right: root.barPosition === "right" ? theme.barHeight : 0
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:simple-bar-popups"
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                // Click-outside background to dismiss popup
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.activePopup = ""
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL A: CONNECTIVITY & QUICK CONTROLS (Wi-Fi, Bluetooth)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: connPanel
                    visible: root.activePopup === "wifi"
                    anchors.top: (root.barPosition === "top" || root.isVerticalBar) ? parent.top : undefined
                    anchors.topMargin: root.barPosition === "top" ? 6 : 20
                    anchors.bottom: root.barPosition === "bottom" ? parent.bottom : undefined
                    anchors.bottomMargin: root.barPosition === "bottom" ? 6 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.isVerticalBar ? 0 : -120

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
                                    onClicked: root.activePopup = ""
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
                                        root.activePopup = ""
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
                                        root.activePopup = ""
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
                    anchors.top: (root.barPosition === "top" || root.isVerticalBar) ? parent.top : undefined
                    anchors.topMargin: root.barPosition === "top" ? 6 : 20
                    anchors.bottom: root.barPosition === "bottom" ? parent.bottom : undefined
                    anchors.bottomMargin: root.barPosition === "bottom" ? 6 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.isVerticalBar ? 0 : 120

                    width: 360
                    height: 550
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
                                    onClicked: root.activePopup = ""
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
                                            { id: "bottom", label: "Bottom", icon: "󰁅" },
                                            { id: "left", label: "Left", icon: "󰁍" },
                                            { id: "right", label: "Right", icon: "󰁔" }
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
                                    root.activePopup = ""
                                    sysStats.launchProc.command = ["kitty", "-e", "btop"]
                                    sysStats.launchProc.running = true
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
                    anchors.top: (root.barPosition === "top" || root.isVerticalBar) ? parent.top : undefined
                    anchors.topMargin: root.barPosition === "top" ? 6 : 20
                    anchors.bottom: root.barPosition === "bottom" ? parent.bottom : undefined
                    anchors.bottomMargin: root.barPosition === "bottom" ? 6 : 0
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
                    visible: root.activePopup === "apps"
                    anchors.top: (root.barPosition === "top" || root.isVerticalBar) ? parent.top : undefined
                    anchors.topMargin: root.barPosition === "top" ? 8 : 20
                    anchors.bottom: root.barPosition === "bottom" ? parent.bottom : undefined
                    anchors.bottomMargin: root.barPosition === "bottom" ? 8 : 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 520
                    radius: 20
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    scale: visible ? 1.0 : 0.94
                    opacity: visible ? 1.0 : 0.0
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                    MouseArea {
                        anchors.fill: parent
                    }

                    property string searchQuery: ""
                    property string activeCategory: "All"

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

                    onSearchQueryChanged: currentApps = getFilteredApps()
                    onActiveCategoryChanged: currentApps = getFilteredApps()
                    Connections {
                        target: sysStats
                        function onAppsListChanged() {
                            appsPanel.currentApps = appsPanel.getFilteredApps()
                        }
                    }

                    onVisibleChanged: {
                        if (visible) {
                            searchQuery = ""
                            activeCategory = "All"
                            sysStats.loadApps()
                            appSearchInput.forceActiveFocus()
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
                                    onClicked: root.activePopup = ""
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

                                    Keys.onEscapePressed: root.activePopup = ""
                                    Keys.onReturnPressed: {
                                        if (appsPanel.currentApps.length > 0) {
                                            sysStats.launchApp(appsPanel.currentApps[0].exec)
                                            root.activePopup = ""
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
                                        onClicked: appSearchInput.text = ""
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

                        // App Cards Grid
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            GridLayout {
                                width: parent.width
                                columns: 2
                                rowSpacing: 6
                                columnSpacing: 8

                                Repeater {
                                    model: appsPanel.currentApps

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 52
                                        radius: 10
                                        color: appCardMouse.containsMouse ? theme.surfaceHover : theme.surface
                                        border.color: appCardMouse.containsMouse ? theme.borderLight : theme.border
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 10

                                            // Icon Container
                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 8
                                                color: "#141414"

                                                Image {
                                                    id: appImg
                                                    anchors.centerIn: parent
                                                    width: 26
                                                    height: 26
                                                    fillMode: Image.PreserveAspectFit
                                                    source: modelData.icon_path ? ("file://" + modelData.icon_path) : ""
                                                    visible: status === Image.Ready
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !modelData.icon_path || appImg.status !== Image.Ready
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
                                                    color: theme.text
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
                                            onClicked: {
                                                sysStats.launchApp(modelData.exec)
                                                root.activePopup = ""
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
}
