pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root
    property var workspaces: []
    property var windows: []
    property var activeWindowIds: ({})
    property var focusedWindowId: null
    property bool focusedFullscreen: false
    property bool inOverview: false
    readonly property var focusedWorkspace: workspaces.find(ws => ws.is_focused) ?? null
    readonly property string focusedOutput: focusedWorkspace?.output ?? ""
    readonly property var focusedWindow: windows.find(w => w.id === focusedWindowId) ?? null

    function isFullscreenOnOutput(win: var, output: string): bool {
        if (!win) return false
        return ToplevelManager.toplevels.values.some(top =>
            top.fullscreen && top.appId === win.app_id && top.title === win.title
            && top.screens.some(target => target.name === output))
    }

    function isFullscreen(win: var): bool {
        if (!win) return false
        const workspace = workspaces.find(ws => ws.id === win.workspace_id)
        if (!workspace) return false
        return isFullscreenOnOutput(win, workspace.output)
    }

    function isOutputFullscreen(output: string): bool {
        const active = workspaces.find(ws => ws.output === output && ws.is_active)
        if (!active) return false
        const fallbackId = active.is_focused && focusedWindow?.workspace_id === active.id ? focusedWindowId : null
        const activeId = activeWindowIds[active.id] ?? fallbackId
        const activeWindow = windows.find(win => win.id === activeId) ?? null
        return isFullscreenOnOutput(activeWindow, output)
    }

    function updateFullscreen(win: var): void {
        focusedFullscreen = win ? isFullscreen(win) : false
    }

    function workspacesOn(output: string): var {
        return workspaces.filter(ws => ws.output === output).sort((a, b) => a.idx - b.idx)
    }

    function action(args: var): void {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args))
    }

    function handle(event: var): void {
        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces
            updateFullscreen(focusedWindow)
        } else if (event.WorkspaceActivated) {
            const id = event.WorkspaceActivated.id
            const focused = event.WorkspaceActivated.focused
            const target = workspaces.find(ws => ws.id === id)
            if (!target) return
            workspaces = workspaces.map(ws => {
                const copy = Object.assign({}, ws)
                if (ws.output === target.output) copy.is_active = ws.id === id
                if (focused) copy.is_focused = ws.id === id
                return copy
            })
            updateFullscreen(focusedWindow)
        } else if (event.WorkspaceActiveWindowChanged) {
            const change = event.WorkspaceActiveWindowChanged
            const next = Object.assign({}, activeWindowIds)
            next[change.workspace_id] = change.active_window_id
            activeWindowIds = next
        } else if (event.WindowsChanged) {
            windows = event.WindowsChanged.windows
            focusedWindowId = windows.find(w => w.is_focused)?.id ?? null
            updateFullscreen(windows.find(w => w.id === focusedWindowId) ?? null)
        } else if (event.WindowOpenedOrChanged) {
            const win = event.WindowOpenedOrChanged.window
            const rest = windows.filter(w => w.id !== win.id)
            windows = rest.concat([win])
            if (win.is_focused) focusedWindowId = win.id
            if (win.is_focused || win.id === focusedWindowId) updateFullscreen(win)
        } else if (event.WindowClosed) {
            const id = event.WindowClosed.id
            windows = windows.filter(w => w.id !== id)
            if (focusedWindowId === id) { focusedWindowId = null; focusedFullscreen = false }
        } else if (event.WindowFocusChanged) {
            focusedWindowId = event.WindowFocusChanged.id
            updateFullscreen(windows.find(w => w.id === focusedWindowId) ?? null)
        } else if (event.WindowFocusTimestampChanged) {
            const update = event.WindowFocusTimestampChanged
            windows = windows.map(win => win.id === update.id
                ? Object.assign({}, win, { focus_timestamp: update.focus_timestamp }) : win)
        } else if (event.OverviewOpenedOrClosed) {
            inOverview = !!event.OverviewOpenedOrClosed.is_open
        }
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (!line.length) return
                try { root.handle(JSON.parse(line)) }
                catch (error) { console.warn("[Dynamite] niri event parse failed:", error) }
            }
        }
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: stream.running = true
    }
}
