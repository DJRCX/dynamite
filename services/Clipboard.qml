pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.state

Singleton {
    id: root
    property var entries: []
    property var pins: []
    property string filter: "All"
    property string query: ""
    property string error: ""
    property string lastId: ""
    property string previewId: ""
    property string previewText: ""
    property bool pasteWhenReady: false
    readonly property string shareDir: Quickshell.env("HOME") + "/.local/share/dynamite"
    readonly property string pinsPath: shareDir + "/clipboard-pins.json"
    function refresh(): void { reader.running = true }
    function visibleEntries(q: string, f: string): var {
        const needle = q.trim().toLowerCase()
        const pinned = entries.filter(e => pins.some(p => p.id === e.id || p.text === e.text))
        const rest = entries.filter(e => !pinned.some(p => p.id === e.id || p.text === e.text))
        let all = pinned.concat(rest)
        if (f === "Pinned") all = pinned
        else if (f === "Text") all = all.filter(e => !e.image && !e.link)
        else if (f === "Images") all = all.filter(e => e.image)
        else if (f === "Links") all = all.filter(e => e.link)
        return needle ? all.filter(e => e.text.toLowerCase().includes(needle)) : all
    }
    function parseList(raw: string): void {
        const lines = raw.replace(/\n$/, "").split("\n")
        const list = []
        for (const line of lines) {
            const tab = line.indexOf("\t")
            if (tab < 1) continue
            const id = line.slice(0, tab), value = line.slice(tab + 1)
            const image = /\[\[ binary data/i.test(value) || /image\/(png|jpeg|webp)/i.test(value)
            const match = value.match(/https?:\/\/[^\s)]+/)
            const content = image ? "Image · " + value.replace(/^\[\[ binary data[^\]]*\]\]\s*/i, "") : value
            list.push({ id, text: content, raw: line, image, link: !!match, host: match ? match[0].replace(/^https?:\/\//, "").split("/")[0] : "", lines: value.split("\n").length })
        }
        root.entries = list.slice(0, Math.max(500, Config.clipboard.maxItems))
    }
    function pin(entry: var): void {
        let next = pins.slice()
        const i = next.findIndex(p => p.id === entry.id || p.text === entry.text)
        if (i >= 0) next.splice(i, 1)
        else next.unshift({ id: entry.id, text: entry.text, image: entry.image, link: entry.link })
        root.pins = next
        savePins.entries = next
        pinsFile.writeAdapter()
    }
    function paste(id: string, autoPaste: bool): void {
        lastId = id
        pasteWhenReady = autoPaste
        decoder.command = ["cliphist", "decode", id]
        decoder.running = true
    }
    function preview(id: string): void {
        previewId = id
        previewText = ""
        previewer.command = ["cliphist", "decode", id]
        previewer.running = true
    }
    function remove(entry: var): void {
        startStdin(["cliphist", "delete"], entry.raw + "\n", true)
    }
    function clearHistory(): void { clearConfirm = true }
    property bool clearConfirm: false
    function confirmClear(): void { clearer.running = true; clearConfirm = false }
    function schedulePaste(): void { pasteTimer.restart() }
    function copyText(text: string, autoPaste: bool): void {
        pasteWhenReady = autoPaste
        startStdin(["wl-copy"], text, false, autoPaste)
    }
    Process {
        id: reader
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.parseList(text) }
    }
    Process { id: decoder; command: ["cliphist", "decode", ""]; stdout: StdioCollector { onStreamFinished: root.startStdin(["wl-copy"], text, false, root.pasteWhenReady) } }
    Process { id: previewer; command: ["cliphist", "decode", ""]; stdout: StdioCollector { onStreamFinished: root.previewText = text } }
    function startStdin(args: var, payload: string, refreshAfter: bool, pasteAfter: bool): void {
        const proc = stdinWriter.createObject(root, { command: args, payload, refreshAfter, pasteAfter, stdinEnabled: true })
        if (proc) proc.running = true
    }
    Component {
        id: stdinWriter
        Process {
            property string payload: ""
            property bool refreshAfter: false
            property bool pasteAfter: false
            stdinEnabled: true
            onStarted: { write(payload); stdinEnabled = false }
            onExited: {
                if (refreshAfter) root.refresh()
                if (pasteAfter && Config.clipboard.autoPaste) root.schedulePaste()
                destroy()
            }
        }
    }
    Timer { id: pasteTimer; interval: 120; onTriggered: {
        if (root.pasteWhenReady && Config.clipboard.autoPaste) {
            Island.close()
            pasteDelay.restart()
        }
    } }
    Timer { id: pasteDelay; interval: 120; onTriggered: Quickshell.execDetached(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"]) }
    Process { id: clearer; command: ["cliphist", "wipe"]; onExited: root.refresh() }
    Process { id: mkdir; command: ["mkdir", "-p", root.shareDir]; running: true }
    FileView { id: pinsFile; path: root.pinsPath; watchChanges: true; printErrors: false
        onLoaded: { try { root.pins = JSON.parse(text()).entries || [] } catch (e) { root.pins = [] } }
        JsonAdapter { id: savePins; property var entries: [] }
    }
    Component.onCompleted: refresh()
}
