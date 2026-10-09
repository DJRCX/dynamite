pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var workspaces: []
    property var windows: []
    property var focusedWindowId: null
    readonly property var focusedWorkspace: workspaces.find(ws => ws.is_focused) ?? null
    readonly property string focusedOutput: focusedWorkspace?.output ?? ""
    readonly property var focusedWindow: windows.find(w => w.id === focusedWindowId) ?? null

    function workspacesOn(output: string): var {
        return workspaces.filter(ws => ws.output === output).sort((a, b) => a.idx - b.idx)
    }

    function action(args: var): void {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args))
    }

    function handle(event: var): void {
        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces
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
        } else if (event.WindowsChanged) {
            windows = event.WindowsChanged.windows
            focusedWindowId = windows.find(w => w.is_focused)?.id ?? null
        } else if (event.WindowOpenedOrChanged) {
            const win = event.WindowOpenedOrChanged.window
            const rest = windows.filter(w => w.id !== win.id)
            windows = rest.concat([win])
            if (win.is_focused) focusedWindowId = win.id
        } else if (event.WindowClosed) {
            const id = event.WindowClosed.id
            windows = windows.filter(w => w.id !== id)
            if (focusedWindowId === id) focusedWindowId = null
        } else if (event.WindowFocusChanged) {
            focusedWindowId = event.WindowFocusChanged.id
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
