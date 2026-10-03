import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Widgets

ShellRoot {
    id: root

    // Notification Server (Single instance at ShellRoot outside per-screen Variants)
    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true
            root.recordNotificationTimestamp(n.id)
            root.hasUnreadNotifications = true
            if (!root.isDndActive) {
                root.pushToast(n)
            }
        }
    }

    // Active flyout state: "", "wifi", "battery", "calendar", "apps", "clipboard", "notifications"
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

    // IPC Handler to control bar position and bar-workspaces
    IpcHandler {
        target: "bar"
        function setTop(): void { root.setBarPosition("top") }
        function setBottom(): void { root.setBarPosition("bottom") }
        function nextWorkspace(): void { root.nextBarWorkspace() }
        function prevWorkspace(): void { root.prevBarWorkspace() }
        function setWorkspace(idx: int): void { root.setBarWorkspace(idx) }
    }

    // IPC Handler for notifications
    IpcHandler {
        target: "notifications"
        function toggle() { root.togglePopup("notifications") }
        function open() { root.openPopup("notifications") }
        function close() { root.closePopup(false) }
        function clearAll() {
            let items = notifServer.trackedNotifications.values
            for (let i = 0; i < items.length; i++) {
                items[i].dismiss()
            }
            root.hasUnreadNotifications = false
        }
    }

    // Notification timestamps & unread state
    property var notifTimestamps: ({})
    function recordNotificationTimestamp(id) {
        let map = Object.assign({}, root.notifTimestamps)
        map[id] = Date.now()
        root.notifTimestamps = map
    }
    function getNotificationTimeAgo(id) {
        let ts = root.notifTimestamps[id]
        if (!ts) return "Just now"
        let sec = Math.floor((Date.now() - ts) / 1000)
        if (sec < 60) return "Just now"
        let min = Math.floor(sec / 60)
        if (min < 60) return `${min}m ago`
        let hr = Math.floor(min / 60)
        if (hr < 24) return `${hr}h ago`
        return `${Math.floor(hr / 24)}d ago`
    }
    property bool hasUnreadNotifications: false
    property bool isDndActive: false

    // In-Pill Notification Toast State
    property var toastQueue: []
    property var currentToast: null
    property bool isToastActive: false

    Timer {
        id: toastTimer
        interval: 5000
        repeat: false
        onTriggered: root.dismissCurrentToast()
    }

    function pushToast(n) {
        if (!n) return
        toastQueue.push(n)
        if (!root.isToastActive && !root.isActionActive && !root.showingWorkspaces) {
            showNextToast()
        }
    }

    function showNextToast() {
        if (toastQueue.length === 0) {
            root.isToastActive = false
            root.currentToast = null
            return
        }
        root.currentToast = toastQueue.shift()
        root.isToastActive = true
        toastTimer.stop()
        if (root.currentToast.urgency !== NotificationUrgency.Critical) {
            let timeout = root.currentToast.expireTimeout
            toastTimer.interval = (timeout && timeout > 0) ? timeout : 5000
            toastTimer.restart()
        }
    }

    function dismissCurrentToast() {
        toastTimer.stop()
        root.isToastActive = false
        root.currentToast = null
        if (toastQueue.length > 0) {
            showNextToast()
        }
    }

    // Bar side position: "top" or "bottom"
    property string barPosition: "top"

    // ─────────────────────────────────────────────────────────────────
    // BAR-WORKSPACES (Switchable Bar Modes akin to Niri workspaces)
    // 0: Overview (Primary Bar)
    // 1: Media (MPRIS Music & Playback)
    // 2: Hardware (CPU, RAM, Battery, Thermals, Controls)
    // 3: Workspaces (Dedicated Niri Workspaces & Active Tasks)
    // ─────────────────────────────────────────────────────────────────
    property int barWorkspaceIndex: 0
    readonly property int barWorkspaceCount: 4

    // Cooldown / debounce no longer needed (keybind-only navigation)
    property real lastBarScrollTime: 0  // kept for safe binding reference, not used

    function nextBarWorkspace() {
        setBarWorkspace((root.barWorkspaceIndex + 1) % root.barWorkspaceCount)
    }

    function prevBarWorkspace() {
        setBarWorkspace((root.barWorkspaceIndex - 1 + root.barWorkspaceCount) % root.barWorkspaceCount)
    }

    function setBarWorkspace(idx) {
        if (idx < 0) idx = 0
        if (idx >= root.barWorkspaceCount) idx = root.barWorkspaceCount - 1
        if (root.barWorkspaceIndex !== idx) {
            root.barWorkspaceIndex = idx
        }
    }

    // MPRIS Active Player Tracker
    readonly property var activeMprisPlayer: {
        try {
            let list = Mpris.players.values
            if (!list || list.length === 0) return null
            for (let i = 0; i < list.length; i++) {
                if (list[i] && list[i].isPlaying) return list[i]
            }
            return list[0]
        } catch (e) {
            return null
        }
    }

    // Workspace change indicator transient state
    property bool showingWorkspaces: false
    Timer {
        id: wsIndicatorTimer
        interval: 700
        onTriggered: {
            root.showingWorkspaces = false
            if (root.isToastActive && root.currentToast && root.currentToast.urgency !== NotificationUrgency.Critical) {
                toastTimer.restart()
            }
        }
    }

    function triggerWorkspaceIndicator() {
        if (root.isToastActive) toastTimer.stop()
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
            if (root.isToastActive && root.currentToast && root.currentToast.urgency !== NotificationUrgency.Critical) {
                toastTimer.restart()
            }
        }
    }

    function showAction(type, icon, text, percent, color) {
        if (root.isToastActive) toastTimer.stop()
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

    function getWeatherIcon(code, isDay) {
        if (code === 0) return isDay ? "󰖙" : "󰖔"
        if (code === 1 || code === 2) return isDay ? "󰖕" : "󰼱"
        if (code === 3) return "󰖐"
        if (code === 45 || code === 48) return "󰖑"
        if (code >= 51 && code <= 67) return "󰖗"
        if (code >= 71 && code <= 77) return "󰖘"
        if (code >= 80 && code <= 82) return "󰖖"
        if (code >= 95) return "󰖓"
        return isDay ? "󰖙" : "󰖔"
    }

    function getNotificationIcon(notif) {
        if (!notif) return ""
        if (notif.image && typeof notif.image === "string" && notif.image !== "") {
            return notif.image.startsWith("/") ? ("file://" + notif.image) : notif.image
        }
        if (notif.appIcon && typeof notif.appIcon === "string" && notif.appIcon !== "") {
            if (notif.appIcon.startsWith("/")) return "file://" + notif.appIcon
            if (notif.appIcon.startsWith("file://")) return notif.appIcon
        }
        let keys = []
        if (notif.desktopEntry) keys.push(notif.desktopEntry.toLowerCase())
        if (notif.appIcon) keys.push(notif.appIcon.toLowerCase())
        if (notif.appName) {
            keys.push(notif.appName.toLowerCase())
            keys.push(notif.appName.toLowerCase().replace(/\s+/g, "-"))
            keys.push(notif.appName.toLowerCase().replace(/\s+/g, "_"))
        }
        // 1. Try matching against appsList icon_path
        if (sysStats.appsList && sysStats.appsList.length > 0) {
            for (let k = 0; k < keys.length; k++) {
                let key = keys[k]
                if (!key) continue
                for (let i = 0; i < sysStats.appsList.length; i++) {
                    let app = sysStats.appsList[i]
                    let aPath = app.icon_path || ""
                    if (!aPath || !aPath.startsWith("/")) continue
                    let aName = (app.name || "").toLowerCase()
                    let aExec = (app.exec || "").toLowerCase()
                    let aIcon = (app.icon || "").toLowerCase()
                    if (aName === key || aIcon === key || aExec.includes(key)) {
                        return "file://" + aPath
                    }
                }
            }
        }
        // 2. Try Quickshell.iconPath
        for (let k = 0; k < keys.length; k++) {
            let key = keys[k]
            if (!key) continue
            try {
                let p = Quickshell.iconPath(key, true)
                if (p && p !== "" && p.startsWith("/")) {
                    return "file://" + p
                }
            } catch (e) {}
        }
        return ""
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
        property int cpuTemp: 45
        property string memUsedStr: "0.0 GB"
        property string memTotalStr: "0.0 GB"
        property real memPercent: 0.0
        property string swapUsedStr: "0.0 GB"
        property real swapPercent: 0.0
        property bool caffeineActive: false

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
                        if (data.cpu_temp !== undefined) {
                            sysStats.cpuTemp = data.cpu_temp
                        }
                        if (data.mem) {
                            sysStats.memUsedStr = data.mem.used || "0 GB"
                            sysStats.memTotalStr = data.mem.total || "0 GB"
                            sysStats.memPercent = data.mem.percent || 0.0
                        }
                        if (data.swap) {
                            sysStats.swapUsedStr = data.swap.used || "0 GB"
                            sysStats.swapPercent = data.swap.percent || 0.0
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

        // Caffeine worker
        property Process caffeineProc: Process {
            id: caffeineProc
            property bool isToggling: false
            command: ["python3", sysStats.scriptPath, "caffeine-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let res = JSON.parse(text)
                        if (res.active !== undefined) {
                            sysStats.caffeineActive = res.active
                            if (caffeineProc.isToggling) {
                                caffeineProc.isToggling = false
                                Quickshell.execDetached([
                                    "notify-send",
                                    "-a", "Caffeine",
                                    "-i", res.active ? "caffeine" : "caffeine-off",
                                    res.active ? "Caffeine Enabled" : "Caffeine Disabled",
                                    res.active ? "Screen sleep and idle timeout are inhibited." : "Screen sleep and idle timeout are restored."
                                ])
                            }
                        }
                    } catch (e) {
                        caffeineProc.isToggling = false
                    }
                }
            }
        }

        function checkCaffeine() {
            if (!caffeineProc.running) {
                caffeineProc.command = ["python3", sysStats.scriptPath, "caffeine-status"]
                caffeineProc.running = true
            }
        }

        function toggleCaffeine() {
            caffeineProc.isToggling = true
            caffeineProc.command = ["python3", sysStats.scriptPath, "caffeine-toggle"]
            caffeineProc.running = true
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

        // Weather Data & Fetcher
        property string weatherTemp: "--°C"
        property int weatherCode: 0
        property int weatherIsDay: 1
        property string weatherDesc: "Loading..."

        property Process weatherProc: Process {
            id: weatherProc
            command: ["python3", sysStats.scriptPath, "weather"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let data = JSON.parse(text)
                        if (data.temp) sysStats.weatherTemp = data.temp
                        if (data.code !== undefined) sysStats.weatherCode = data.code
                        if (data.is_day !== undefined) sysStats.weatherIsDay = data.is_day
                        if (data.desc) sysStats.weatherDesc = data.desc
                    } catch(e) {}
                }
            }
        }

        property Timer weatherTimer: Timer {
            interval: 900000
            running: true
            repeat: true
            onTriggered: sysStats.refreshWeather()
        }

        function refreshWeather() {
            if (!weatherProc.running) weatherProc.running = true
        }

        Component.onCompleted: {
            sysStats.refresh()
            sysStats.loadApps()
            sysStats.refreshWeather()
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
                    readonly property bool showBalls: root.barWorkspaceIndex === 0 && (isHovered || (root.activePopup !== "" && !centerPill.hasOpenPanel)) && !root.showingWorkspaces && !centerPill.hasOpenPanel && !root.isActionActive && !root.isToastActive && !root.isPopupClosing

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
                        readonly property bool hasOpenPanel: root.activePopup !== "" && !root.isPopupClosing
                        readonly property int panelWidth: 560

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: !hasOpenPanel ? parent.verticalCenter : undefined
                        anchors.top: (hasOpenPanel && root.barPosition === "bottom") ? parent.top : undefined
                        anchors.bottom: (hasOpenPanel && root.barPosition === "top") ? parent.bottom : undefined

                        // Width of active bar-workspace
                        readonly property int currentBarWorkspaceWidth: {
                            switch (root.barWorkspaceIndex) {
                                case 0: return pillContentRow.implicitWidth
                                case 1: return statusWorkspaceRow.implicitWidth
                                case 2: return mediaWorkspaceRow.implicitWidth
                                case 3: return sysresWorkspaceRow.implicitWidth
                                default: return pillContentRow.implicitWidth
                            }
                        }

                        // Tracks toast content width even when container is hidden (invisible → implicitWidth = 0)
                        property int toastContentWidth: 260

                        width: root.showingWorkspaces ? (workspacesRow.implicitWidth + 32)
                               : (root.isActionActive ? (actionRow.implicitWidth + 36)
                               : (root.isToastActive ? (toastContentWidth + 36)
                               : (hasOpenPanel ? panelWidth
                               : (currentBarWorkspaceWidth + 24))))
                        height: hasOpenPanel ? theme.barHeight : theme.pillHeight

                        property bool isPillHovered: false
                        HoverHandler {
                            id: centerPillHover
                            onHoveredChanged: centerPill.isPillHovered = hovered
                        }

                        readonly property bool showLauncherBtn: root.activePopup === "apps"
                        readonly property bool hasFocusedApp: (sysStats.focusedAppName !== "" || sysStats.focusedApp !== "") && sysStats.focusedApp.toLowerCase() !== "desktop"

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
                        // A. HORIZONTAL BAR CONTENT (Switchable Bar-Workspaces)
                        // ─────────────────────────────────────────────────────
                        Item {
                            anchors.fill: parent

                            // ─────────────────────────────────────────────────
                            // 1. BAR-WORKSPACE 0: PRIMARY OVERVIEW
                            // ─────────────────────────────────────────────────
                            Item {
                                id: ws0Overview
                                anchors.fill: parent
                                visible: opacity > 0.01
                                opacity: (root.barWorkspaceIndex === 0 && !root.showingWorkspaces && !root.isActionActive && !root.isToastActive) ? 1.0 : 0.0
                                transform: Translate {
                                    x: root.barWorkspaceIndex === 0 ? 0 : (root.barWorkspaceIndex > 0 ? -16 : 16)
                                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                }
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Row {
                                    id: pillContentRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // LEFT SECTION: Fixed Launcher (Hover only) & Focused App
                                    Row {
                                        id: leftSection
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        visible: centerPill.hasFocusedApp || centerPill.showLauncherBtn

                                        // Fixed 26x26 Launcher Button (Revealed only on hover or apps popup)
                                        Rectangle {
                                            id: launcherBtn
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: centerPill.showLauncherBtn ? 26 : 0
                                            height: 26
                                            radius: 13
                                            clip: true
                                            visible: width > 0
                                            opacity: centerPill.showLauncherBtn ? 1.0 : 0.0
                                            color: (launcherMouse.containsMouse || root.activePopup === "apps" || root.activePopup === "clipboard") ? theme.surfaceHover : "transparent"
                                            border.width: 0

                                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.activePopup === "clipboard" ? "󰅍" : "󰀻"
                                                font.pixelSize: 14
                                                color: (root.activePopup === "apps" || root.activePopup === "clipboard") ? theme.accent : theme.text
                                            }

                                            MouseArea {
                                                id: launcherMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.togglePopup("apps")
                                            }
                                        }

                                        // Separator between launcherBtn and focusedAppBtn
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: (centerPill.showLauncherBtn && centerPill.hasFocusedApp) ? 1 : 0
                                            height: 14
                                            color: theme.borderLight
                                            visible: width > 0
                                            opacity: (centerPill.showLauncherBtn && centerPill.hasFocusedApp) ? 1.0 : 0.0

                                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                        }

                                        // Stable Focused App Button
                                        Rectangle {
                                            id: focusedAppBtn
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 26
                                            radius: 13
                                            color: appBtnMouse.containsMouse || root.activePopup === "appcontext" ? theme.surfaceHover : "transparent"
                                            border.width: 0

                                            visible: centerPill.hasFocusedApp
                                            width: centerPill.hasFocusedApp ? (appRow.implicitWidth + 14) : 0
                                            clip: true

                                            Row {
                                                id: appRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                // Icon only visible when hovered (or app context menu open)
                                                Item {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: (centerPill.isPillHovered || root.activePopup === "appcontext") ? 16 : 0
                                                    height: 16
                                                    visible: width > 0
                                                    clip: true
                                                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                                    Image {
                                                        id: appRealIcon
                                                        anchors.fill: parent
                                                        fillMode: Image.PreserveAspectFit
                                                        source: sysStats.focusedAppIconPath ? ("file://" + sysStats.focusedAppIconPath) : ""
                                                        visible: status === Image.Ready
                                                        smooth: true
                                                        mipmap: true
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: !appRealIcon.visible || appRealIcon.status !== Image.Ready
                                                        text: root.getAppIcon(sysStats.focusedApp, sysStats.focusedAppName)
                                                        font.pixelSize: 13
                                                        color: theme.accent
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: sysStats.focusedAppName || sysStats.focusedApp || ""
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: theme.text
                                                    elide: Text.ElideRight
                                                    width: Math.min(implicitWidth, 180)
                                                }
                                            }

                                            MouseArea {
                                                id: appBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.togglePopup("appcontext")
                                            }
                                        }
                                    }

                                    // Separator between leftSection and clockArea
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (centerPill.hasFocusedApp || centerPill.showLauncherBtn) ? 1 : 0
                                        height: 14
                                        color: theme.borderLight
                                        visible: width > 0
                                    }

                                    // CENTER SECTION: Clock & Date Button
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

                                    // Separator between clockArea and rightSection (Seamless, no dead space)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 1; height: 14; color: theme.borderLight
                                    }

                                    // RIGHT SECTION: Weather/Tray Slot & Bell
                                    Row {
                                        id: rightSection
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        // Weather / System Tray Slot
                                        Item {
                                            id: weatherTraySlot
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 26

                                            property bool isSlotHovered: false
                                            property bool trayMenuOpen: false

                                            readonly property bool showTray: (isSlotHovered || trayMenuOpen) && SystemTray.items.length > 0

                                            width: showTray ? (trayRow.implicitWidth + 8) : (weatherView.implicitWidth + 8)
                                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                            Timer {
                                                id: slotCollapseTimer
                                                interval: 250
                                                onTriggered: {
                                                    if (!slotHover.hovered && !weatherTraySlot.trayMenuOpen) {
                                                        weatherTraySlot.isSlotHovered = false
                                                    }
                                                }
                                            }

                                            HoverHandler {
                                                id: slotHover
                                                onHoveredChanged: {
                                                    if (hovered) {
                                                        slotCollapseTimer.stop()
                                                        weatherTraySlot.isSlotHovered = true
                                                    } else {
                                                        slotCollapseTimer.restart()
                                                    }
                                                }
                                            }

                                            // Weather View (Default)
                                            RowLayout {
                                                id: weatherView
                                                anchors.centerIn: parent
                                                spacing: 5
                                                opacity: weatherTraySlot.showTray ? 0.0 : 1.0
                                                visible: opacity > 0.01
                                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                                Text {
                                                    text: root.getWeatherIcon(sysStats.weatherCode, sysStats.weatherIsDay)
                                                    font.pixelSize: 13
                                                    color: theme.accent
                                                }
                                                Text {
                                                    text: sysStats.weatherTemp
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: theme.text
                                                }
                                            }

                                            // System Tray Row (Revealed on hover)
                                            Row {
                                                id: trayRow
                                                anchors.centerIn: parent
                                                spacing: 6
                                                opacity: weatherTraySlot.showTray ? 1.0 : 0.0
                                                visible: opacity > 0.01
                                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                                Repeater {
                                                    model: SystemTray.items

                                                    delegate: Item {
                                                        required property var modelData
                                                        width: 20
                                                        height: 20

                                                        IconImage {
                                                            anchors.centerIn: parent
                                                            width: 16
                                                            height: 16
                                                            source: modelData.icon
                                                        }

                                                        // Needs attention dot
                                                        Rectangle {
                                                            width: 4; height: 4; radius: 2
                                                            color: theme.warning
                                                            anchors.top: parent.top
                                                            anchors.right: parent.right
                                                            visible: modelData.status === Status.NeedsAttention
                                                        }

                                                        QsMenuAnchor {
                                                            id: trayMenu
                                                            menu: modelData.menu
                                                            anchor.window: barWindow
                                                            onClosed: {
                                                                weatherTraySlot.trayMenuOpen = false
                                                                slotCollapseTimer.restart()
                                                            }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                                            cursorShape: Qt.PointingHandCursor

                                                            onWheel: wheel => {
                                                                wheel.accepted = true
                                                                modelData.scroll(wheel.angleDelta.y, false)
                                                            }

                                                            onClicked: mouse => {
                                                                if (mouse.button === Qt.LeftButton) {
                                                                    if (modelData.onlyMenu) {
                                                                        weatherTraySlot.trayMenuOpen = true
                                                                        trayMenu.open()
                                                                    } else {
                                                                        modelData.activate()
                                                                    }
                                                                } else if (mouse.button === Qt.RightButton) {
                                                                    if (modelData.menu) {
                                                                        weatherTraySlot.trayMenuOpen = true
                                                                        trayMenu.open()
                                                                    }
                                                                } else if (mouse.button === Qt.MiddleButton) {
                                                                    modelData.secondaryActivate()
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Separator before Bell
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 1; height: 14; color: theme.borderLight
                                        }

                                        // Fixed 26x26 Notification Bell Button
                                        Rectangle {
                                            id: bellBtn
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 26; height: 26; radius: 13
                                            color: (bellMouse.containsMouse || root.activePopup === "notifications") ? theme.surfaceHover : "transparent"
                                            border.width: 0

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.isDndActive ? "󰂛" : (root.hasUnreadNotifications ? "󱅫" : "󰂚")
                                                font.pixelSize: 14
                                                color: root.isDndActive ? theme.warning : (root.hasUnreadNotifications ? theme.accent : theme.textMuted)
                                            }

                                            // Unread indicator dot
                                            Rectangle {
                                                width: 5; height: 5; radius: 2.5
                                                color: theme.accent
                                                anchors.top: parent.top; anchors.topMargin: 3
                                                anchors.right: parent.right; anchors.rightMargin: 3
                                                visible: root.hasUnreadNotifications && !root.isDndActive
                                            }

                                            MouseArea {
                                                id: bellMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hasUnreadNotifications = false
                                                    root.togglePopup("notifications")
                                                }
                                            }
                                        }
                                    }

                                    // Separator before pager dots (only when hovered)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: centerPill.isPillHovered ? 1 : 0
                                        height: 14
                                        color: theme.borderLight
                                        visible: width > 0
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on width { NumberAnimation { duration: 140 } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }

                                    // Mini Bar-Workspace Pager Indicator (only when hovered)
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        visible: opacity > 0.01
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 140 } }

                                        Repeater {
                                            model: root.barWorkspaceCount
                                            delegate: Rectangle {
                                                required property int index
                                                readonly property bool isActive: root.barWorkspaceIndex === index
                                                width: isActive ? 12 : 4
                                                height: 4
                                                radius: 2
                                                color: isActive ? theme.accent : (p0Mouse.containsMouse ? theme.text : theme.borderLight)

                                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 140 } }

                                                MouseArea {
                                                    id: p0Mouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setBarWorkspace(index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ─────────────────────────────────────────────────
                            // 2. BAR-WORKSPACE 1: STATUS & CONTROLS (Wi-Fi, BT, Caffeine, Battery, Brightness, Volume)
                            // ─────────────────────────────────────────────────
                            Item {
                                id: ws1Status
                                anchors.fill: parent
                                visible: opacity > 0.01
                                opacity: (root.barWorkspaceIndex === 1 && !root.showingWorkspaces && !root.isActionActive && !root.isToastActive) ? 1.0 : 0.0
                                transform: Translate {
                                    x: root.barWorkspaceIndex === 1 ? 0 : (root.barWorkspaceIndex > 1 ? -16 : 16)
                                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                }
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Row {
                                    id: statusWorkspaceRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // 1. Wi-Fi Control
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: wifiCtrlMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: wifiCtrlRow.implicitWidth + 10
                                        clip: true

                                        Row {
                                            id: wifiCtrlRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: !sysStats.wifiPowered ? "󰤭" : (sysStats.wifiConnected ? "󰤨" : "󰤩")
                                                font.pixelSize: 13
                                                color: sysStats.wifiConnected ? theme.accent : theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: centerPill.isPillHovered
                                                text: !sysStats.wifiPowered ? "Off" : (sysStats.wifiConnected ? (sysStats.wifiSsid || "Connected") : "Disconnected")
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 90)
                                            }
                                        }

                                        MouseArea {
                                            id: wifiCtrlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("wifi")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 2. Bluetooth Control
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: btCtrlMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: btCtrlRow.implicitWidth + 10
                                        clip: true

                                        Row {
                                            id: btCtrlRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: !sysStats.btPowered ? "󰂲" : (sysStats.btConnected ? "󰂱" : "󰂯")
                                                font.pixelSize: 13
                                                color: sysStats.btConnected ? theme.accent : theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: centerPill.isPillHovered
                                                text: !sysStats.btPowered ? "Off" : (sysStats.btConnected ? (sysStats.btDevice || "Connected") : "Disconnected")
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 90)
                                            }
                                        }

                                        MouseArea {
                                            id: btCtrlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("wifi")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 3. Caffeine Toggle
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: cafCtrlMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: cafCtrlRow.implicitWidth + 10
                                        clip: true

                                        Row {
                                            id: cafCtrlRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sysStats.caffeineActive ? "󰅶" : "󰾪"
                                                font.pixelSize: 13
                                                color: sysStats.caffeineActive ? theme.warning : theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: centerPill.isPillHovered
                                                text: sysStats.caffeineActive ? "Caffeine On" : "Caffeine Off"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: cafCtrlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: sysStats.toggleCaffeine()
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 4. Battery Status
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: batCtrlMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: batCtrlRow.implicitWidth + 10
                                        clip: true

                                        Row {
                                            id: batCtrlRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: rightBall.charging ? "󰂄" : (rightBall.pctInt > 80 ? "󰁹" : (rightBall.pctInt > 50 ? "󰁾" : (rightBall.pctInt > 20 ? "󰁼" : "󰂃")))
                                                font.pixelSize: 13
                                                color: rightBall.charging ? theme.success : (rightBall.pctInt <= 20 ? theme.danger : theme.text)
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: centerPill.isPillHovered
                                                text: `${rightBall.pctInt}%`
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: batCtrlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("battery")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 5. Brightness
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: briCtrlMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: briCtrlRow.implicitWidth + 10
                                        clip: true

                                        Row {
                                            id: briCtrlRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰃠"
                                                font.pixelSize: 13
                                                color: theme.warning
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: centerPill.isPillHovered
                                                text: `${sysStats.brightness}%`
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: briCtrlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("battery")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 6. Volume
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: volCtrlMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: volCtrlRow.implicitWidth + 10
                                        clip: true

                                        Row {
                                            id: volCtrlRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sysStats.volumeMuted ? "󰖁" : (sysStats.volume > 50 ? "󰕾" : "󰖀")
                                                font.pixelSize: 13
                                                color: sysStats.volumeMuted ? theme.danger : theme.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: centerPill.isPillHovered
                                                text: sysStats.volumeMuted ? "Muted" : `${sysStats.volume}%`
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: volCtrlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("battery")
                                        }
                                    }

                                    // Separator before pager dots (only when hovered)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: centerPill.isPillHovered ? 1 : 0
                                        height: 14
                                        color: theme.borderLight
                                        visible: width > 0
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on width { NumberAnimation { duration: 140 } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }

                                    // Mini Bar-Workspace Pager Indicator (only when hovered)
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        visible: opacity > 0.01
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 140 } }

                                        Repeater {
                                            model: root.barWorkspaceCount
                                            delegate: Rectangle {
                                                required property int index
                                                readonly property bool isActive: root.barWorkspaceIndex === index
                                                width: isActive ? 12 : 4
                                                height: 4
                                                radius: 2
                                                color: isActive ? theme.accent : (p1Mouse.containsMouse ? theme.text : theme.borderLight)

                                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 140 } }

                                                MouseArea {
                                                    id: p1Mouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setBarWorkspace(index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ─────────────────────────────────────────────────
                            // 3. BAR-WORKSPACE 2: MPRIS MEDIA PLAYER
                            // ─────────────────────────────────────────────────
                            Item {
                                id: ws2Media
                                anchors.fill: parent
                                visible: opacity > 0.01
                                opacity: (root.barWorkspaceIndex === 2 && !root.showingWorkspaces && !root.isActionActive && !root.isToastActive) ? 1.0 : 0.0
                                transform: Translate {
                                    x: root.barWorkspaceIndex === 2 ? 0 : (root.barWorkspaceIndex > 2 ? -16 : 16)
                                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                }
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Row {
                                    id: mediaWorkspaceRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    readonly property var player: root.activeMprisPlayer
                                    readonly property bool hasMedia: player !== null

                                    // Album Art or Media Icon
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 22; height: 22

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            color: theme.surface
                                            clip: true

                                            Image {
                                                id: mediaArtImg
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectCrop
                                                source: (mediaWorkspaceRow.hasMedia && mediaWorkspaceRow.player.trackArtUrl) ? mediaWorkspaceRow.player.trackArtUrl : ""
                                                visible: status === Image.Ready
                                                smooth: true
                                                mipmap: true
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !mediaArtImg.visible
                                                text: mediaWorkspaceRow.hasMedia ? "󰎈" : "󰎊"
                                                font.pixelSize: 13
                                                color: mediaWorkspaceRow.hasMedia ? theme.accent : theme.textMuted
                                            }
                                        }
                                    }

                                    // Track Title & Artist
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: mediaWorkspaceRow.hasMedia ? (mediaWorkspaceRow.player.trackTitle || "Media Playing") : "No Media Active"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: mediaWorkspaceRow.hasMedia ? theme.text : theme.textMuted
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, 180)
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (mediaWorkspaceRow.hasMedia && mediaWorkspaceRow.player.trackArtist) ? `· ${mediaWorkspaceRow.player.trackArtist}` : ""
                                            font.pixelSize: 11
                                            color: theme.textMuted
                                            visible: text !== ""
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, 120)
                                        }
                                    }

                                    // Separator if hasMedia
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: mediaWorkspaceRow.hasMedia ? 1 : 0
                                        height: 14
                                        color: theme.borderLight
                                        visible: width > 0
                                    }

                                    // Playback Controls
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        visible: mediaWorkspaceRow.hasMedia

                                        // Previous Button
                                        Rectangle {
                                            width: 24; height: 24; radius: 12
                                            color: prevBtnMouse.containsMouse ? theme.surfaceHover : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒮"
                                                font.pixelSize: 13
                                                color: prevBtnMouse.containsMouse ? theme.accent : theme.text
                                            }
                                            MouseArea {
                                                id: prevBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (mediaWorkspaceRow.player) mediaWorkspaceRow.player.previous()
                                            }
                                        }

                                        // Play/Pause Button
                                        Rectangle {
                                            width: 24; height: 24; radius: 12
                                            color: playBtnMouse.containsMouse ? theme.surfaceHover : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: (mediaWorkspaceRow.player && mediaWorkspaceRow.player.isPlaying) ? "󰏤" : "󰐊"
                                                font.pixelSize: 14
                                                color: theme.accent
                                            }
                                            MouseArea {
                                                id: playBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (mediaWorkspaceRow.player) mediaWorkspaceRow.player.togglePlaying()
                                            }
                                        }

                                        // Next Button
                                        Rectangle {
                                            width: 24; height: 24; radius: 12
                                            color: nextBtnMouse.containsMouse ? theme.surfaceHover : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒭"
                                                font.pixelSize: 13
                                                color: nextBtnMouse.containsMouse ? theme.accent : theme.text
                                            }
                                            MouseArea {
                                                id: nextBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (mediaWorkspaceRow.player) mediaWorkspaceRow.player.next()
                                            }
                                        }
                                    }

                                    // Separator before pager dots (only when hovered)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: centerPill.isPillHovered ? 1 : 0
                                        height: 14
                                        color: theme.borderLight
                                        visible: width > 0
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on width { NumberAnimation { duration: 140 } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }

                                    // Mini Bar-Workspace Pager Indicator (only when hovered)
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        visible: opacity > 0.01
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 140 } }

                                        Repeater {
                                            model: root.barWorkspaceCount
                                            delegate: Rectangle {
                                                required property int index
                                                readonly property bool isActive: root.barWorkspaceIndex === index
                                                width: isActive ? 12 : 4
                                                height: 4
                                                radius: 2
                                                color: isActive ? theme.accent : (p2Mouse.containsMouse ? theme.text : theme.borderLight)

                                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 140 } }

                                                MouseArea {
                                                    id: p2Mouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setBarWorkspace(index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ─────────────────────────────────────────────────
                            // 4. BAR-WORKSPACE 3: SYSTEM RESOURCES
                            // ─────────────────────────────────────────────────
                            Item {
                                id: ws3Sysres
                                anchors.fill: parent
                                visible: opacity > 0.01
                                opacity: (root.barWorkspaceIndex === 3 && !root.showingWorkspaces && !root.isActionActive && !root.isToastActive) ? 1.0 : 0.0
                                transform: Translate {
                                    x: root.barWorkspaceIndex === 3 ? 0 : (root.barWorkspaceIndex > 3 ? -16 : 16)
                                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                }
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Row {
                                    id: sysresWorkspaceRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // 1. CPU Usage Block
                                    Rectangle {
                                        id: cpuBlock
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: cpuMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: cpuRow.implicitWidth + 10
                                        clip: true

                                        property bool isHov: cpuMouse.containsMouse

                                        Row {
                                            id: cpuRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰍛"
                                                font.pixelSize: 13
                                                color: theme.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: cpuBlock.isHov || centerPill.isPillHovered
                                                text: "CPU"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sysStats.cpuUsage
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 4; radius: 2; color: "#222222"
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                    width: parent.width * Math.min(1.0, sysStats.cpuPercent)
                                                    radius: 2; color: theme.accent
                                                    Behavior on width { NumberAnimation { duration: 120 } }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: cpuMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("sysresources")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 2. CPU Temperature Block
                                    Rectangle {
                                        id: tempBlock
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: tempMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: tempRow.implicitWidth + 10
                                        clip: true

                                        property bool isHov: tempMouse.containsMouse

                                        Row {
                                            id: tempRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sysStats.cpuTemp > 80 ? "󰈸" : (sysStats.cpuTemp > 65 ? "󰔏" : "󰔐")
                                                font.pixelSize: 13
                                                color: sysStats.cpuTemp > 80 ? theme.danger : (sysStats.cpuTemp > 65 ? theme.warning : theme.accent)
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: tempBlock.isHov || centerPill.isPillHovered
                                                text: "Temp"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: `${sysStats.cpuTemp}°C`
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: tempMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("sysresources")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 3. RAM Usage Block
                                    Rectangle {
                                        id: ramBlock
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: ramMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: ramRow.implicitWidth + 10
                                        clip: true

                                        property bool isHov: ramMouse.containsMouse

                                        Row {
                                            id: ramRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰘚"
                                                font.pixelSize: 13
                                                color: theme.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: ramBlock.isHov || centerPill.isPillHovered
                                                text: "RAM"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sysStats.memUsedStr
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 4; radius: 2; color: "#222222"
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                    width: parent.width * Math.min(1.0, sysStats.memPercent)
                                                    radius: 2; color: theme.accent
                                                    Behavior on width { NumberAnimation { duration: 120 } }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: ramMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("sysresources")
                                        }
                                    }

                                    // Separator
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: theme.borderLight }

                                    // 4. Swap Usage Block
                                    Rectangle {
                                        id: swapBlock
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        radius: 12
                                        color: swapMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        width: swapRow.implicitWidth + 10
                                        clip: true

                                        property bool isHov: swapMouse.containsMouse

                                        Row {
                                            id: swapRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰓡"
                                                font.pixelSize: 13
                                                color: theme.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: swapBlock.isHov || centerPill.isPillHovered
                                                text: "Swap"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.textMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sysStats.swapUsedStr
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: swapMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePopup("sysresources")
                                        }
                                    }

                                    // Separator before pager dots (only when hovered)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: centerPill.isPillHovered ? 1 : 0
                                        height: 14
                                        color: theme.borderLight
                                        visible: width > 0
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on width { NumberAnimation { duration: 140 } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }

                                    // Mini Bar-Workspace Pager Indicator (only when hovered)
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        visible: opacity > 0.01
                                        opacity: centerPill.isPillHovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 140 } }

                                        Repeater {
                                            model: root.barWorkspaceCount
                                            delegate: Rectangle {
                                                required property int index
                                                readonly property bool isActive: root.barWorkspaceIndex === index
                                                width: isActive ? 12 : 4
                                                height: 4
                                                radius: 2
                                                color: isActive ? theme.accent : (p3Mouse.containsMouse ? theme.text : theme.borderLight)

                                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 140 } }

                                                MouseArea {
                                                    id: p3Mouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setBarWorkspace(index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. Workspaces Changing View
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

                            // 3. Full-Bar Action View (Volume & Brightness HUD)
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

                                Rectangle {
                                    width: 76
                                    height: 4
                                    radius: 2
                                    color: "#222222"

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * Math.min(1.0, root.actionPercent)
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

                            // 4. In-Pill Notification Toast HUD
                            Item {
                                id: toastContainer
                                anchors.centerIn: parent
                                width: toastRow.implicitWidth
                                height: 26
                                visible: !root.showingWorkspaces && !root.isActionActive && root.isToastActive
                                opacity: visible ? 1.0 : 0.0

                                property bool isToastHovered: false

                                // Keep centerPill updated with our content width (even while hidden implicitWidth = 0)
                                onWidthChanged: if (width > 0) centerPill.toastContentWidth = width
                                Component.onCompleted: if (width > 0) centerPill.toastContentWidth = width

                                Row {
                                    id: toastRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 7

                                    // App/Notification Icon
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18; height: 18
                                        readonly property string toastIconSrc: root.getNotificationIcon(root.currentToast)

                                        Image {
                                            id: toastImg
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            source: parent.toastIconSrc
                                            visible: parent.toastIconSrc !== "" && status === Image.Ready
                                            smooth: true
                                            mipmap: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !toastImg.visible
                                            text: root.currentToast ? root.getAppIcon(root.currentToast.appName, root.currentToast.summary) : "󰂚"
                                            font.pixelSize: 14
                                            color: theme.accent
                                        }
                                    }

                                    // Summary (Bold, single line)
                                    Text {
                                        id: summaryText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.currentToast ? (root.currentToast.summary || "").replace(/[\r\n]+/g, " ") : ""
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: theme.text
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: Math.min(implicitWidth, 160)
                                    }

                                    // Bullet separator (if body exists)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: bodyText.visible && summaryText.text.length > 0
                                        text: "•"
                                        font.pixelSize: 10
                                        color: theme.textMuted
                                    }

                                    // Body (Single line, horizontal)
                                    Text {
                                        id: bodyText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.currentToast ? (root.currentToast.body || "").replace(/[\r\n]+/g, " ") : ""
                                        font.pixelSize: 11
                                        color: theme.textMuted
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: Math.min(implicitWidth, 220)
                                        visible: text.trim().length > 0
                                    }

                                    // Hover clear/cross button
                                    Rectangle {
                                        id: toastCloseBtn
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (toastContainer.isToastHovered || toastCloseMouse.containsMouse) ? 18 : 0
                                        height: 18
                                        radius: 9
                                        color: toastCloseMouse.containsMouse ? theme.surfaceHover : "transparent"
                                        clip: true
                                        visible: width > 0
                                        opacity: width > 0 ? 1.0 : 0.0

                                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        Behavior on opacity { NumberAnimation { duration: 120 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: toastCloseMouse.containsMouse ? theme.danger : theme.textMuted
                                        }

                                        MouseArea {
                                            id: toastCloseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.currentToast) root.currentToast.dismiss()
                                                root.dismissCurrentToast()
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        toastContainer.isToastHovered = true
                                        toastTimer.stop()
                                    }
                                    onExited: {
                                        toastContainer.isToastHovered = false
                                        if (root.currentToast && root.currentToast.urgency !== NotificationUrgency.Critical) {
                                            toastTimer.restart()
                                        }
                                    }
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) {
                                            let defAction = root.currentToast?.actions?.find(a => a.identifier === "default" || a.identifier === "open")
                                            if (defAction) defAction.invoke()
                                            root.dismissCurrentToast()
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (root.currentToast) root.currentToast.dismiss()
                                            root.dismissCurrentToast()
                                        }
                                    }
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
                    readonly property bool isShown: root.activePopup === "wifi" && !root.isPopupClosing
                    visible: root.displayedPopup === "wifi"
                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 480
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
                        y: connPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

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
                                        sysStats.launchProc.command = ["python3", sysStats.scriptPath, "launch-terminal", "nmtui"]
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
                    readonly property bool isShown: root.activePopup === "battery" && !root.isPopupClosing
                    visible: root.displayedPopup === "battery"
                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 400
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
                        y: batteryPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

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
                // PANEL B2: SYSTEM RESOURCES DETAILED POPUP (CPU, Temp, RAM, Swap, btop)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: sysresPanel
                    readonly property bool isShown: root.activePopup === "sysresources" && !root.isPopupClosing
                    visible: root.displayedPopup === "sysresources"
                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 440
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
                        y: sysresPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        // Panel Header
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰍛  System Resources"
                                font.pixelSize: 15
                                font.bold: true
                                color: theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: closeSysresHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: theme.textMuted }
                                MouseArea {
                                    id: closeSysresHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        // CPU Utilization & Temp
                        Rectangle {
                            Layout.fillWidth: true
                            height: 72
                            radius: 12
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "CPU Utilization"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: `${sysStats.cpuTemp}°C`
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: sysStats.cpuTemp > 80 ? theme.danger : (sysStats.cpuTemp > 65 ? theme.warning : theme.accent)
                                    }
                                    Text {
                                        text: sysStats.cpuUsage
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: theme.accent
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3; color: "#1c1c1c"
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * Math.max(0.01, Math.min(1.0, sysStats.cpuPercent))
                                        radius: 3
                                        color: sysStats.cpuPercent > 0.85 ? theme.danger : theme.accent
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                    }
                                }
                            }
                        }

                        // RAM (Memory) Utilization
                        Rectangle {
                            Layout.fillWidth: true
                            height: 72
                            radius: 12
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Memory (RAM)"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: `${sysStats.memUsedStr} / ${sysStats.memTotalStr} (${Math.round(sysStats.memPercent * 100)}%)`
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: theme.accent
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3; color: "#1c1c1c"
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * Math.max(0.01, Math.min(1.0, sysStats.memPercent))
                                        radius: 3
                                        color: sysStats.memPercent > 0.9 ? theme.danger : theme.accent
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                    }
                                }
                            }
                        }

                        // Swap Memory Utilization
                        Rectangle {
                            Layout.fillWidth: true
                            height: 72
                            radius: 12
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Swap Memory"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: `${sysStats.swapUsedStr} (${Math.round(sysStats.swapPercent * 100)}%)`
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: theme.accent
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3; color: "#1c1c1c"
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * Math.max(0.0, Math.min(1.0, sysStats.swapPercent))
                                        radius: 3
                                        color: sysStats.swapPercent > 0.8 ? theme.danger : theme.accent
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                    }
                                }
                            }
                        }

                        // Open System Monitor (btop)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 10
                            color: btopSysHover.containsMouse ? theme.surfaceHover : theme.surface
                            border.color: theme.border; border.width: 1

                            RowLayout {
                                anchors.centerIn: parent; spacing: 8
                                Text { text: "󰄪"; font.pixelSize: 14; color: theme.accent }
                                Text { text: "Open System Monitor (btop)"; font.pixelSize: 12; font.bold: true; color: theme.accent }
                            }

                            MouseArea {
                                id: btopSysHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.closePopup(false)
                                    sysStats.launchProc.command = ["python3", sysStats.scriptPath, "launch-terminal", "btop"]
                                    sysStats.launchProc.running = true
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL E: FOCUSED APP CONTEXT MENU
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: appContextPanel
                    readonly property bool isShown: root.activePopup === "appcontext" && !root.isPopupClosing
                    visible: root.displayedPopup === "appcontext"
                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    readonly property string appId: (sysStats.focusedApp || "").toLowerCase()
                    readonly property string appName: (sysStats.focusedAppName || "").toLowerCase()
                    readonly property bool isBrowser: appId.includes("chrome") || appId.includes("firefox") || appId.includes("brave") || appId.includes("zen") || appId.includes("chromium") || appId.includes("opera") || appId.includes("vivaldi") || appId.includes("edge") || appName.includes("chrome") || appName.includes("firefox") || appName.includes("browser")

                    width: 560
                    height: isBrowser ? 280 : 180
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
                        y: appContextPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        // Header with App Info
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item {
                                width: 22; height: 22
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: sysStats.focusedAppIconPath ? ("file://" + sysStats.focusedAppIconPath) : ""
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !sysStats.focusedAppIconPath
                                    text: root.getAppIcon(sysStats.focusedApp, sysStats.focusedAppName)
                                    font.pixelSize: 16
                                    color: theme.accent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: sysStats.focusedAppName || sysStats.focusedApp || "Application"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: theme.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: sysStats.focusedTitle || ""
                                    font.pixelSize: 10
                                    color: theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }

                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: closeAppCtxHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: theme.textMuted }
                                MouseArea {
                                    id: closeAppCtxHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: theme.border
                        }

                        // Browser Specific Actions
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: appContextPanel.isBrowser

                            // New Tab
                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                color: newTabHov.containsMouse ? theme.surfaceHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Text { text: "󰝰"; font.pixelSize: 14; color: theme.accent }
                                    Text { text: "New Tab"; font.pixelSize: 12; color: theme.text }
                                }

                                MouseArea {
                                    id: newTabHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closePopup(false)
                                        if (appContextPanel.appId.includes("firefox")) {
                                            Quickshell.execDetached(["firefox", "--new-tab", "about:newtab"])
                                        } else if (appContextPanel.appId.includes("brave")) {
                                            Quickshell.execDetached(["brave-browser", "chrome://newtab"])
                                        } else {
                                            Quickshell.execDetached(["google-chrome-stable", "chrome://newtab"])
                                        }
                                    }
                                }
                            }

                            // New Incognito / Private Tab
                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                color: newIncogHov.containsMouse ? theme.surfaceHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Text { text: "󰗹"; font.pixelSize: 14; color: theme.warning }
                                    Text { text: "New Incognito / Private Window"; font.pixelSize: 12; color: theme.text }
                                }

                                MouseArea {
                                    id: newIncogHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closePopup(false)
                                        if (appContextPanel.appId.includes("firefox")) {
                                            Quickshell.execDetached(["firefox", "--private-window"])
                                        } else if (appContextPanel.appId.includes("brave")) {
                                            Quickshell.execDetached(["brave-browser", "--incognito"])
                                        } else {
                                            Quickshell.execDetached(["google-chrome-stable", "--incognito"])
                                        }
                                    }
                                }
                            }

                            // New Window
                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                color: newWinHov.containsMouse ? theme.surfaceHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Text { text: "󰖲"; font.pixelSize: 14; color: theme.accent }
                                    Text { text: "New Window"; font.pixelSize: 12; color: theme.text }
                                }

                                MouseArea {
                                    id: newWinHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closePopup(false)
                                        if (appContextPanel.appId.includes("firefox")) {
                                            Quickshell.execDetached(["firefox", "--new-window"])
                                        } else if (appContextPanel.appId.includes("brave")) {
                                            Quickshell.execDetached(["brave-browser", "--new-window"])
                                        } else {
                                            Quickshell.execDetached(["google-chrome-stable", "--new-window"])
                                        }
                                    }
                                }
                            }
                        }

                        // General Window Actions: Fullscreen / Float
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 8
                            color: fsHov.containsMouse ? theme.surfaceHover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                Text { text: "󰊓"; font.pixelSize: 14; color: theme.accent }
                                Text { text: "Toggle Fullscreen"; font.pixelSize: 12; color: theme.text }
                            }

                            MouseArea {
                                id: fsHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.closePopup(false)
                                    Quickshell.execDetached(["niri", "msg", "action", "fullscreen-window"])
                                }
                            }
                        }

                        // Close Window Action (Danger)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 8
                            color: closeWinHov.containsMouse ? "#2b1419" : theme.surface
                            border.color: closeWinHov.containsMouse ? theme.danger : theme.border
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "✕"; font.pixelSize: 12; font.bold: true; color: theme.danger }
                                Text { text: "Close Window"; font.pixelSize: 12; font.bold: true; color: theme.danger }
                            }

                            MouseArea {
                                id: closeWinHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.closePopup(false)
                                    Quickshell.execDetached(["niri", "msg", "action", "close-window"])
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL C: ENLARGED UNIFIED BIG CLOCK & INTERACTIVE CALENDAR
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: calendarPanel
                    readonly property bool isShown: root.activePopup === "calendar" && !root.isPopupClosing
                    visible: root.displayedPopup === "calendar"
                    y: root.barPosition === "top" ? 0 : (parent.height - height)
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 560
                    height: 480
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
                        y: calendarPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    property var currentDate: new Date()
                    property int viewYear: currentDate.getFullYear()
                    property int viewMonth: currentDate.getMonth()

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        // Header with Clock, Date, and Close button
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2

                                Text {
                                    id: bigClockTime
                                    text: Qt.formatDateTime(new Date(), "hh:mm:ss A")
                                    font.pixelSize: 32
                                    font.weight: Font.Bold
                                    color: theme.text

                                    Timer {
                                        interval: 1000
                                        running: calendarPanel.isShown
                                        repeat: true
                                        onTriggered: bigClockTime.text = Qt.formatDateTime(new Date(), "hh:mm:ss A")
                                    }
                                }

                                Text {
                                    id: bigClockDate
                                    text: Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: theme.accent
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: closeCalHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: theme.textMuted }
                                MouseArea {
                                    id: closeCalHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: theme.border
                        }

                        // Month Navigation Bar
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: {
                                    let d = new Date(calendarPanel.viewYear, calendarPanel.viewMonth, 1)
                                    return Qt.formatDate(d, "MMMM yyyy")
                                }
                                font.pixelSize: 16
                                font.bold: true
                                color: theme.text
                            }

                            Item { Layout.fillWidth: true }

                            // Quick "Today" Jump button
                            Rectangle {
                                width: 56; height: 26; radius: 6
                                color: todayHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "Today"; font.pixelSize: 11; font.weight: Font.DemiBold; color: theme.text }
                                MouseArea {
                                    id: todayHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    onClicked: {
                                        let now = new Date()
                                        calendarPanel.viewYear = now.getFullYear()
                                        calendarPanel.viewMonth = now.getMonth()
                                    }
                                }
                            }

                            Rectangle {
                                width: 28; height: 26; radius: 6; color: prevHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "󰅁"; font.pixelSize: 13; color: theme.text }
                                MouseArea {
                                    id: prevHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    onClicked: {
                                        if (calendarPanel.viewMonth === 0) {
                                            calendarPanel.viewMonth = 11
                                            calendarPanel.viewYear--
                                        } else {
                                            calendarPanel.viewMonth--
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 28; height: 26; radius: 6; color: nextHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "󰅂"; font.pixelSize: 13; color: theme.text }
                                MouseArea {
                                    id: nextHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    onClicked: {
                                        if (calendarPanel.viewMonth === 11) {
                                            calendarPanel.viewMonth = 0
                                            calendarPanel.viewYear++
                                        } else {
                                            calendarPanel.viewMonth++
                                        }
                                    }
                                }
                            }
                        }

                        // Day Names
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

                        // 42-day Calendar Grid
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            rowSpacing: 4
                            columnSpacing: 4

                            Repeater {
                                model: 42

                                delegate: Rectangle {
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8

                                    readonly property int firstDay: new Date(calendarPanel.viewYear, calendarPanel.viewMonth, 1).getDay()
                                    readonly property int totalDays: new Date(calendarPanel.viewYear, calendarPanel.viewMonth + 1, 0).getDate()
                                    readonly property int dayNumber: index - firstDay + 1
                                    readonly property bool isValidDay: dayNumber >= 1 && dayNumber <= totalDays

                                    readonly property bool isToday: {
                                        let now = new Date()
                                        return isValidDay && dayNumber === now.getDate() && calendarPanel.viewMonth === now.getMonth() && calendarPanel.viewYear === now.getFullYear()
                                    }

                                    color: isToday ? theme.accent : (dayMouse.containsMouse && isValidDay ? theme.surfaceHover : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        visible: parent.isValidDay
                                        text: parent.isValidDay ? String(parent.dayNumber) : ""
                                        font.pixelSize: 12
                                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                                        color: parent.isToday ? "#000000" : theme.text
                                    }

                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent
                                        hoverEnabled: parent.isValidDay
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

                // ─────────────────────────────────────────────────────────────
                // PANEL F: NOTIFICATIONS HISTORY (Panel F inside overlayWindow)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: notificationsPanel
                    readonly property bool isShown: root.activePopup === "notifications" && !root.isPopupClosing
                    visible: root.displayedPopup === "notifications"

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
                        y: notificationsPanel.isShown ? 0 : (root.barPosition === "bottom" ? 16 : -16)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
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
                                text: "󰂚"
                                font.pixelSize: 18
                                color: theme.accent
                            }

                            Text {
                                text: "Notifications"
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
                                width: notifCountText.implicitWidth + 12

                                Text {
                                    id: notifCountText
                                    anchors.centerIn: parent
                                    text: `${notifServer.trackedNotifications.values.length} items`
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: theme.textMuted
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // DND Toggle Button
                            Rectangle {
                                height: 26
                                radius: 13
                                color: root.isDndActive ? theme.accentSurface : (dndHov.containsMouse ? theme.surfaceHover : theme.surface)
                                border.color: root.isDndActive ? theme.accent : theme.border
                                border.width: 1
                                width: dndRow.implicitWidth + 14

                                RowLayout {
                                    id: dndRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: root.isDndActive ? "󰂛" : "󰂚"
                                        font.pixelSize: 11
                                        color: root.isDndActive ? theme.accent : theme.textMuted
                                    }
                                    Text {
                                        text: root.isDndActive ? "DND On" : "DND Off"
                                        font.pixelSize: 11
                                        font.bold: root.isDndActive
                                        color: root.isDndActive ? theme.accent : theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: dndHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.isDndActive = !root.isDndActive
                                }
                            }

                            // Clear All Button
                            Rectangle {
                                height: 26
                                radius: 13
                                visible: notifServer.trackedNotifications.values.length > 0
                                color: clearNotifsHov.containsMouse ? "#2d1419" : theme.surface
                                border.color: clearNotifsHov.containsMouse ? theme.danger : theme.border
                                border.width: 1
                                width: clearNotifsRow.implicitWidth + 14

                                RowLayout {
                                    id: clearNotifsRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "󰆴"
                                        font.pixelSize: 11
                                        color: clearNotifsHov.containsMouse ? theme.danger : theme.textMuted
                                    }
                                    Text {
                                        text: "Clear"
                                        font.pixelSize: 11
                                        color: clearNotifsHov.containsMouse ? theme.danger : theme.textMuted
                                    }
                                }

                                MouseArea {
                                    id: clearNotifsHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let items = notifServer.trackedNotifications.values.slice()
                                        for (let i = 0; i < items.length; i++) {
                                            items[i].dismiss()
                                        }
                                        root.hasUnreadNotifications = false
                                    }
                                }
                            }

                            // Close Button
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: closeNotifHov.containsMouse ? theme.surfaceHover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: theme.textMuted }
                                MouseArea {
                                    id: closeNotifHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closePopup(false)
                                }
                            }
                        }

                        // Empty State or List Container
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1
                            clip: true

                            // Empty State
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: notifServer.trackedNotifications.values.length === 0

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "󰂚"
                                    font.pixelSize: 42
                                    color: theme.textMuted
                                    opacity: 0.35
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No Notifications"
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: theme.textMuted
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "You're all caught up"
                                    font.pixelSize: 12
                                    color: theme.textMuted
                                    opacity: 0.6
                                }
                            }

                            // Notification List
                            ListView {
                                id: notifListView
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                visible: notifServer.trackedNotifications.values.length > 0
                                model: notifServer.trackedNotifications.values.slice().reverse()

                                delegate: Rectangle {
                                    id: notifCard
                                    width: notifListView.width
                                    implicitHeight: cardContent.implicitHeight + 20
                                    radius: 10
                                    color: cardMouse.containsMouse ? theme.surfaceHover : "#0a0a0a"
                                    border.color: modelData.urgency === NotificationUrgency.Critical ? theme.danger : (cardMouse.containsMouse ? theme.borderLight : theme.border)
                                    border.width: 1

                                    RowLayout {
                                        id: cardContent
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 12

                                        // Left App Icon or Notification Image
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop
                                            width: 36; height: 36; radius: 8
                                            color: "#141414"
                                            border.color: theme.borderLight
                                            border.width: 1

                                            readonly property string notifIconSrc: root.getNotificationIcon(modelData)

                                            Image {
                                                id: notifImg
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                fillMode: Image.PreserveAspectFit
                                                source: parent.notifIconSrc
                                                visible: parent.notifIconSrc !== "" && status === Image.Ready
                                                smooth: true
                                                mipmap: true
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !notifImg.visible
                                                text: root.getAppIcon(modelData.appName, modelData.summary)
                                                font.pixelSize: 18
                                                color: theme.accent
                                            }
                                        }

                                        // Center Column (Header, Summary, Body, Actions)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            // Top Row: App Name, Urgency badge, Relative Time
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: modelData.appName || "Notification"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: theme.textMuted
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 160
                                                }

                                                // Critical Urgency Badge
                                                Rectangle {
                                                    visible: modelData.urgency === NotificationUrgency.Critical
                                                    height: 16; width: critText.implicitWidth + 8; radius: 4
                                                    color: "#38171e"
                                                    border.color: theme.danger; border.width: 1
                                                    Text {
                                                        id: critText
                                                        anchors.centerIn: parent
                                                        text: "CRITICAL"
                                                        font.pixelSize: 9; font.bold: true
                                                        color: theme.danger
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: root.getNotificationTimeAgo(modelData.id)
                                                    font.pixelSize: 10
                                                    color: theme.textMuted
                                                }
                                            }

                                            // Summary / Title
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.summary || ""
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: theme.text
                                                elide: Text.ElideRight
                                                visible: text !== ""
                                            }

                                            // Body
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.body || ""
                                                font.pixelSize: 11
                                                color: theme.textMuted
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 4
                                                elide: Text.ElideRight
                                                textFormat: Text.StyledText
                                                visible: text !== ""
                                            }

                                            // Actions
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                visible: modelData.actions && modelData.actions.length > 0
                                                Layout.topMargin: 4

                                                Repeater {
                                                    model: modelData.actions || []

                                                    Rectangle {
                                                        height: 24
                                                        radius: 6
                                                        width: actText.implicitWidth + 14
                                                        color: actMouse.containsMouse ? theme.surfaceActive : theme.surface
                                                        border.color: actMouse.containsMouse ? theme.accent : theme.border
                                                        border.width: 1

                                                        Text {
                                                            id: actText
                                                            anchors.centerIn: parent
                                                            text: modelData.text || modelData.identifier || "Action"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: actMouse.containsMouse ? theme.accent : theme.text
                                                        }

                                                        MouseArea {
                                                            id: actMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                modelData.invoke()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Right Dismiss Button
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop
                                            width: 24; height: 24; radius: 12
                                            color: cardDelMouse.containsMouse ? "#2d1419" : "transparent"
                                            border.color: cardDelMouse.containsMouse ? theme.danger : "transparent"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                font.pixelSize: 10
                                                color: cardDelMouse.containsMouse ? theme.danger : theme.textMuted
                                            }

                                            MouseArea {
                                                id: cardDelMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.dismiss()
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        z: -1
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let defAction = modelData.actions?.find(a => a.identifier === "default" || a.identifier === "open")
                                            if (defAction) defAction.invoke()
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
