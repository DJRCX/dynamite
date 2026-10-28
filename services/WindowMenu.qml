pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.state

Singleton {
    id: root
    property var captured: null
    property string expanded: ""
    property int selectedWorkspaceIndex: 0
    property bool confirmingForceQuit: false
    property var outputs: []
    readonly property var appEntry: captured ? DesktopEntries.heuristicLookup(captured.app_id || "") : null
    readonly property var desktopActions: appEntry?.actions ?? []
    readonly property string capturedOutput: captured ? (Niri.workspaces.find(ws => ws.id === captured.workspace_id)?.output ?? "") : ""
    readonly property var targetWorkspaces: capturedOutput ? Niri.workspacesOn(capturedOutput) : []

    function capture(): void {
        captured = Niri.focusedWindow ? Object.assign({}, Niri.focusedWindow) : null
        expanded = ""
        selectedWorkspaceIndex = 0
        confirmingForceQuit = false
        outputsReader.running = true
    }
    function action(name: string): void {
        if (!captured || captured.id === undefined) return
        const id = String(captured.id)
        if (name === "fullscreen-window" || name === "toggle-window-floating" || name === "close-window")
            Niri.action([name, "--id", id])
        else if (name === "maximize-column") {
            focusTarget.command = ["niri", "msg", "action", "focus-window", "--id", id]
            focusTarget.running = true
        }
        else if (name.startsWith("workspace:"))
            Niri.action(["move-window-to-workspace", "--window-id", id, name.slice(10)])
        else if (name.startsWith("monitor:"))
            Niri.action(["move-window-to-monitor", "--id", id, name.slice(8)])
        else if (name.startsWith("desktop:")) {
            const actionIndex = Number(name.slice(8))
            const command = desktopActions[actionIndex]?.command
            if (command?.length) Quickshell.execDetached(["niri", "msg", "action", "spawn", "--"].concat(command))
        }
    }
    function forceQuit(): void {
        if (!captured || captured.id === undefined || !confirmingForceQuit) return
        const pid = Number(captured.pid)
        if (!Number.isInteger(pid) || pid <= 1) {
            confirmingForceQuit = false
            console.warn("[Dynamite] force quit cancelled because the target process is unavailable")
            return
        }
        const liveWindow = Niri.windows.find(win => win.id === captured.id)
        if (!liveWindow || Number(liveWindow.pid) !== pid
                || liveWindow.app_id !== captured.app_id) {
            console.warn("[Dynamite] force quit cancelled because the target window changed")
            confirmingForceQuit = false
            return
        }
        // XWayland can report its shared server PID for unrelated X11 clients.
        // In that case, ask Niri to close only the selected window instead.
        const sharedAcrossApps = Niri.windows.some(win => win.id !== captured.id
            && Number(win.pid) === pid && win.app_id !== captured.app_id)
        if (sharedAcrossApps) {
            Niri.action(["close-window", "--id", String(captured.id)])
            console.info("[Dynamite] used window-scoped close because the process is shared by other apps")
            confirmingForceQuit = false
            return
        }
        killProcess.command = ["/usr/bin/kill", "-KILL", "--", String(pid)]
        killProcess.running = true
        confirmingForceQuit = false
    }

    Process {
        id: outputsReader
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.outputs = Object.keys(JSON.parse(text)) }
                catch (error) { root.outputs = [] }
            }
        }
    }
    Process {
        id: focusTarget
        command: []
        onExited: (code) => { if (code === 0) Quickshell.execDetached(["niri", "msg", "action", "maximize-column"]) }
    }
    Process { id: killProcess; command: []; onExited: (code) => { if (code !== 0) console.warn("[Dynamite] force quit failed", code) } }
}
