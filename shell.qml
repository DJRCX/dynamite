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

    // Active flyout state: "", "wifi", "battery", "calendar"
    property string activePopup: ""

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

        // Status poll process
        property Process statusProc: Process {
            command: ["python3", sysStats.scriptPath, "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let data = JSON.parse(text)
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

        function refresh() {
            if (!statusProc.running) {
                statusProc.running = true
            }
        }

        // Actions
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

        property Timer volTimer: Timer {
            interval: 30
            repeat: false
            onTriggered: {
                volProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${sysStats.volume}%`]
                volProc.running = true
            }
        }

        function toggleMute() {
            sysStats.volumeMuted = !sysStats.volumeMuted
            muteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
            muteProc.running = true
        }

        function adjustVolume(delta) {
            setVolume(sysStats.volume + delta)
            commitVolume()
        }

        // Native Fast Brightness Controls
        function setBrightness(pct) {
            let val = Math.max(1, Math.min(100, Math.round(pct)))
            sysStats.brightness = val
            brTimer.restart()
        }

        function commitBrightness() {
            brTimer.stop()
            brightProc.command = ["brightnessctl", "set", `${sysStats.brightness}%`]
            brightProc.running = true
        }

        property Timer brTimer: Timer {
            interval: 30
            repeat: false
            onTriggered: {
                brightProc.command = ["brightnessctl", "set", `${sysStats.brightness}%`]
                brightProc.running = true
            }
        }

        function adjustBrightness(delta) {
            setBrightness(sysStats.brightness + delta)
            commitBrightness()
        }

        property Process actionProc: Process {
            onExited: sysStats.refresh()
        }

        property Process volProc: Process {}
        property Process muteProc: Process {}
        property Process brightProc: Process {}
        property Process launchProc: Process {}

        property Timer updateTimer: Timer {
            interval: 3500
            running: true
            repeat: true
            onTriggered: sysStats.refresh()
        }

        Component.onCompleted: sysStats.refresh()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 1. TOP STATUS BAR (Pitch Black, Exclusive Zone)
    // ═════════════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }

                implicitHeight: theme.barHeight
                color: "transparent"

                WlrLayershell.namespace: "quickshell:single-pill-bar"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.exclusiveZone: theme.barHeight
                exclusionMode: ExclusionMode.Normal

                // Dismiss popup when clicking empty space on the top bar
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
                    height: theme.barHeight
                    width: showBalls ? (centerPill.width + leftBall.width + rightBall.width + 36) : (centerPill.width + 12)

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    property bool isHovered: false
                    readonly property bool showBalls: isHovered || (root.activePopup !== "")

                    Connections {
                        target: root
                        function onActivePopupChanged() {
                            if (root.activePopup === "" && !clusterHover.hovered) {
                                pillCluster.isHovered = false
                            }
                        }
                    }

                    Timer {
                        id: collapseTimer
                        interval: 250
                        onTriggered: {
                            if (!clusterHover.hovered) {
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
                    // CENTER PILL: Clock, Date & Volume Scroll
                    // ─────────────────────────────────────────────────────────
                    Rectangle {
                        id: centerPill
                        z: 10
                        anchors.centerIn: parent
                        height: theme.pillHeight
                        radius: theme.pillRadius
                        color: centerPillMouse.containsMouse || root.activePopup === "calendar" ? theme.surfaceHover : theme.bg
                        border.color: root.activePopup === "calendar" ? theme.accent : theme.border
                        border.width: 1

                        width: pillContentRow.implicitWidth + 36

                        // Volume scrolling feedback state
                        property bool showingVolume: false
                        property Timer volTimer: Timer {
                            interval: 1400
                            onTriggered: centerPill.showingVolume = false
                        }

                        RowLayout {
                            id: pillContentRow
                            anchors.centerIn: parent
                            spacing: 10

                            // Clock + Date View
                            RowLayout {
                                visible: !centerPill.showingVolume
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
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: theme.textMuted
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

                            // Volume Scroll View
                            RowLayout {
                                visible: centerPill.showingVolume
                                spacing: 8

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

                        MouseArea {
                            id: centerPillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePopup = root.activePopup === "calendar" ? "" : "calendar"

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
                                color: sysStats.wifiConnected ? theme.accent : theme.textMuted
                            }

                            // Dynamic hover text showing Wi-Fi and Bluetooth connection state
                            RowLayout {
                                visible: leftBall.isBallHovered
                                spacing: 8

                                Text {
                                    text: sysStats.wifiPowered ? (sysStats.wifiConnected ? sysStats.wifiSsid : "Disconnected") : "Wi-Fi: Off"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: theme.text
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                }

                                Rectangle {
                                    width: 1
                                    height: 12
                                    color: theme.borderLight
                                }

                                Text {
                                    text: "󰂯"
                                    font.pixelSize: 13
                                    color: sysStats.btConnected ? theme.accent : (sysStats.btPowered ? theme.textMuted : theme.danger)
                                }

                                Text {
                                    text: sysStats.btPowered ? (sysStats.btConnected ? sysStats.btDevice : "BT: Ready") : "BT: Off"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: theme.text
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
                    top: theme.barHeight
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:pill-popups"
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                // Click-outside background to dismiss popup
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.activePopup = ""
                }

                // ─────────────────────────────────────────────────────────────
                // PANEL A: CONNECTIVITY & QUICK CONTROLS (Wi-Fi, Bluetooth, Sliders)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: connPanel
                    visible: root.activePopup === "wifi"
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -120
                    width: 380
                    height: 450
                    radius: 18
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    // Consume clicks inside the panel so it doesn't dismiss
                    MouseArea {
                        anchors.fill: parent
                    }

                    property string activeTab: "wifi" // "wifi" or "bt"

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
                                width: 26
                                height: 26
                                radius: 13
                                color: closeHover.containsMouse ? theme.surfaceHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 12
                                    color: theme.textMuted
                                }
                                MouseArea {
                                    id: closeHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePopup = ""
                                }
                            }
                        }

                        // ─── TAB SELECTOR: Wi-Fi vs Bluetooth ───
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 10
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                spacing: 2

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: connPanel.activeTab === "wifi" ? theme.surfaceActive : "transparent"
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰤨"; font.pixelSize: 14; color: connPanel.activeTab === "wifi" ? theme.accent : theme.textMuted }
                                        Text { text: "Wi-Fi"; font.pixelSize: 12; font.bold: connPanel.activeTab === "wifi"; color: connPanel.activeTab === "wifi" ? theme.text : theme.textMuted }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: connPanel.activeTab = "wifi"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: connPanel.activeTab === "bt" ? theme.surfaceActive : "transparent"
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰂯"; font.pixelSize: 14; color: connPanel.activeTab === "bt" ? theme.accent : theme.textMuted }
                                        Text { text: "Bluetooth"; font.pixelSize: 12; font.bold: connPanel.activeTab === "bt"; color: connPanel.activeTab === "bt" ? theme.text : theme.textMuted }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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
                            spacing: 8

                            // Header Controls
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: sysStats.wifiConnected ? `Connected: ${sysStats.wifiSsid}` : (sysStats.wifiPowered ? "Wi-Fi Networks" : "Wi-Fi Disabled")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: sysStats.wifiConnected ? theme.accent : theme.text
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 170
                                }
                                Item { Layout.fillWidth: true }

                                // Rescan button
                                Rectangle {
                                    width: 60; height: 26; radius: 6
                                    color: rescanHov.containsMouse ? theme.surfaceHover : theme.surface
                                    border.color: theme.border; border.width: 1
                                    visible: sysStats.wifiPowered
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: 4
                                        Text { text: "󰑐"; font.pixelSize: 11; color: theme.textMuted }
                                        Text { text: "Scan"; font.pixelSize: 10; font.bold: true; color: theme.text }
                                    }
                                    MouseArea {
                                        id: rescanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: sysStats.rescanWifi()
                                    }
                                }

                                // Toggle Wifi Power button
                                Rectangle {
                                    width: 72; height: 26; radius: 6
                                    color: wifiPwrHov.containsMouse ? (sysStats.wifiPowered ? theme.danger : theme.success) : (sysStats.wifiPowered ? theme.accentSurface : theme.surface)
                                    Text {
                                        anchors.centerIn: parent
                                        text: sysStats.wifiPowered ? "Turn Off" : "Turn On"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: sysStats.wifiPowered ? theme.accent : theme.text
                                    }
                                    MouseArea {
                                        id: wifiPwrHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: sysStats.toggleWifi()
                                    }
                                }
                            }

                            // If Wi-Fi is powered off
                            Rectangle {
                                visible: !sysStats.wifiPowered
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 10; color: theme.surface; border.color: theme.border; border.width: 1
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 8
                                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰤮"; font.pixelSize: 32; color: theme.textMuted }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: "Wi-Fi is turned off"; font.pixelSize: 13; color: theme.textMuted }
                                }
                            }

                            // Available Networks Scrollable List
                            ListView {
                                id: wifiList
                                visible: sysStats.wifiPowered
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                model: sysStats.wifiNetworks

                                delegate: Rectangle {
                                    required property var modelData
                                    width: wifiList.width
                                    height: 42
                                    radius: 8
                                    color: itemHov.containsMouse ? theme.surfaceHover : (modelData.inUse ? theme.accentSurface : theme.surface)
                                    border.color: modelData.inUse ? theme.accent : theme.border
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Text {
                                            text: modelData.signal > 70 ? "󰤨" : (modelData.signal > 45 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟"))
                                            font.pixelSize: 15
                                            color: modelData.inUse ? theme.accent : theme.textMuted
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: modelData.ssid
                                                font.pixelSize: 12
                                                font.bold: modelData.inUse
                                                color: modelData.inUse ? theme.accent : theme.text
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 170
                                            }
                                            Text {
                                                text: `${modelData.security} • ${modelData.signal}%`
                                                font.pixelSize: 10
                                                color: theme.textMuted
                                            }
                                        }

                                        Rectangle {
                                            width: 74; height: 26; radius: 6
                                            color: modelData.inUse ? (btnHov.containsMouse ? "#3a171d" : "#261014") : (btnHov.containsMouse ? theme.surfaceHover : theme.surface)
                                            border.color: modelData.inUse ? theme.danger : theme.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.inUse ? "Disconnect" : "Connect"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: modelData.inUse ? theme.danger : theme.accent
                                            }
                                            MouseArea {
                                                id: btnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.inUse) {
                                                        sysStats.disconnectWifi()
                                                    } else {
                                                        sysStats.connectWifi(modelData.ssid)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: itemHov; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                    }
                                }
                            }

                            // Network Manager CLI shortcut
                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                color: nmtuiHov.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.border; border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒋 Open Network Connections (nmtui)"
                                    font.pixelSize: 11
                                    color: theme.accent
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
                            spacing: 8

                            // Header Controls
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: sysStats.btConnected ? `Connected: ${sysStats.btDevice}` : (sysStats.btPowered ? "Bluetooth Devices" : "Bluetooth Disabled")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: sysStats.btConnected ? theme.accent : theme.text
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 200
                                }
                                Item { Layout.fillWidth: true }

                                // Toggle Bluetooth Power button
                                Rectangle {
                                    width: 72; height: 26; radius: 6
                                    color: btPwrHov.containsMouse ? (sysStats.btPowered ? theme.danger : theme.success) : (sysStats.btPowered ? theme.accentSurface : theme.surface)
                                    Text {
                                        anchors.centerIn: parent
                                        text: sysStats.btPowered ? "Turn Off" : "Turn On"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: sysStats.btPowered ? theme.accent : theme.text
                                    }
                                    MouseArea {
                                        id: btPwrHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: sysStats.toggleBt()
                                    }
                                }
                            }

                            // If Bluetooth is powered off
                            Rectangle {
                                visible: !sysStats.btPowered
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 10; color: theme.surface; border.color: theme.border; border.width: 1
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 8
                                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰂲"; font.pixelSize: 32; color: theme.textMuted }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: "Bluetooth is turned off"; font.pixelSize: 13; color: theme.textMuted }
                                }
                            }

                            // Paired Devices List
                            ListView {
                                id: btList
                                visible: sysStats.btPowered
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                model: sysStats.btDevices

                                delegate: Rectangle {
                                    required property var modelData
                                    width: btList.width
                                    height: 42
                                    radius: 8
                                    color: btItemHov.containsMouse ? theme.surfaceHover : (modelData.connected ? theme.accentSurface : theme.surface)
                                    border.color: modelData.connected ? theme.accent : theme.border
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Text {
                                            text: "󰂯"
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
                                                color: modelData.connected ? theme.accent : theme.text
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 170
                                            }
                                            Text {
                                                text: modelData.connected ? "Connected" : "Paired device"
                                                font.pixelSize: 10
                                                color: modelData.connected ? theme.success : theme.textMuted
                                            }
                                        }

                                        Rectangle {
                                            width: 74; height: 26; radius: 6
                                            color: modelData.connected ? (btBtnHov.containsMouse ? "#3a171d" : "#261014") : (btBtnHov.containsMouse ? theme.surfaceHover : theme.surface)
                                            border.color: modelData.connected ? theme.danger : theme.border
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

                            // Bluetooth Manager Shortcut Button (Requirement 5!)
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
                // PANEL B: BATTERY & DEVICE RESOURCES (Fixed Battery % + Sliders)
                // ─────────────────────────────────────────────────────────────
                Rectangle {
                    id: batteryPanel
                    visible: root.activePopup === "battery"
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 120
                    width: 360
                    height: 480
                    radius: 18
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    // Consume clicks inside the panel so it doesn't dismiss
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
                        spacing: 12

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

                        // Battery Section (Requirement 4 - Accurate Percentage)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 104
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

                                // Accurate Battery Progress Bar
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

                        // Sliders in Battery Panel (Volume & Brightness - Ultra Smooth)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 98
                            radius: 12
                            color: theme.surface
                            border.color: theme.border
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                // 1. Volume Slider
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // Speaker / Mute icon button
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

                                    // Volume Track & Knob
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
                                        color: sysStats.volumeMuted ? theme.danger : theme.text
                                        Layout.minimumWidth: 38
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                // 2. Brightness Slider
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

                                    // Brightness Track & Knob
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

                        // CPU Stats Bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 10
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "CPU Usage"; font.pixelSize: 12; font.weight: Font.Medium; color: theme.text }
                                    Item { Layout.fillWidth: true }
                                    Text { text: sysStats.cpuUsage; font.pixelSize: 12; font.bold: true; color: theme.accent }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3; color: "#1c1c1c"
                                    Rectangle { height: parent.height; width: parent.width * sysStats.cpuPercent; radius: 3; color: theme.accent }
                                }
                            }
                        }

                        // RAM Stats Bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 10
                            color: theme.surface
                            border.color: theme.border; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Memory (RAM)"; font.pixelSize: 12; font.weight: Font.Medium; color: theme.text }
                                    Item { Layout.fillWidth: true }
                                    Text { text: `${sysStats.memUsedStr} / ${sysStats.memTotalStr}`; font.pixelSize: 12; font.bold: true; color: theme.accent }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3; color: "#1c1c1c"
                                    Rectangle { height: parent.height; width: parent.width * sysStats.memPercent; radius: 3; color: theme.accent }
                                }
                            }
                        }

                        // Button to launch btop monitor
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
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
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360
                    height: 390
                    radius: 20
                    color: theme.bg
                    border.color: theme.border
                    border.width: 1

                    // Consume clicks inside the panel so it doesn't dismiss
                    MouseArea {
                        anchors.fill: parent
                    }

                    // Calendar month state
                    property var currentDate: new Date()
                    property int viewYear: currentDate.getFullYear()
                    property int viewMonth: currentDate.getMonth()

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        // Big Clock Header
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

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: theme.border
                        }

                        // Calendar Navigation (Month + Prev/Next buttons)
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

                        // Weekday Labels
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

                        // Calendar 7x5/7x6 Day Grid
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
            }
        }
    }
}
