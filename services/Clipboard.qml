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
    property var imagePaths: ({})
    property var imageQueue: []
    property string decodingImageId: ""
    property var pendingImagePaste: null
    readonly property string shareDir: Quickshell.env("HOME") + "/.local/share/dynamite"
    readonly property string pinsPath: shareDir + "/clipboard-pins.json"
    readonly property string imageCacheDir: Quickshell.env("HOME") + "/.cache/dynamite/clip"
    function refresh(): void { reader.running = true }
    function imagePath(id: string): string {
        const entry = entries.find(e => e.id === id)
        const ext = entry?.imageFormat || "png"
        return imageCacheDir + "/" + String(id).replace(/[^0-9]/g, "") + "." + ext
    }
    function cachedImage(id: string): string { return imagePaths[id] || "" }
    function requestImage(id: string): void {
        if (!Config.clipboard.showImages || imagePaths[id] || decodingImageId === id || imageQueue.includes(id)) return
        imageQueue = imageQueue.concat([id])
        startNextImage()
    }
    function startNextImage(): void {
        if (!imageCacheReady || decodingImageId || imageQueue.length === 0) return
        decodingImageId = imageQueue[0]
        imageQueue = imageQueue.slice(1)
        imageDecoder.command = ["cliphist", "decode", decodingImageId]
        imageDecoder.running = true
    }
    function finishImageWrite(): void {
        const id = imageWriter.currentId
        const paths = Object.assign({}, imagePaths)
        paths[id] = imageWriter.path
        imagePaths = paths
        if (pendingImagePaste?.id === id) {
            const request = pendingImagePaste
            pendingImagePaste = null
            copyImage(id, request.autoPaste)
        }
        decodingImageId = ""
        startNextImage()
    }
    function copyImage(id: string, autoPaste: bool): void {
        if (!imagePaths[id]) {
            pendingImagePaste = { id, autoPaste }
            requestImage(id)
            return
        }
        imageCopier.command = ["python3", Quickshell.shellDir + "/services/ClipboardImage.py", imagePaths[id], imageMime(id)]
        imageCopier.pasteAfter = autoPaste
        imageCopier.running = true
    }
    function imageMime(id: string): string {
        const entry = entries.find(e => e.id === id)
        return "image/" + (entry?.imageFormat === "jpg" ? "jpeg" : entry?.imageFormat || "png")
    }
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
            const imageMeta = value.match(/\[\[\s*binary data\s+(\d+)\s+bytes\s+([a-z0-9]+)(?:\s+(\d+)x(\d+))?/i)
            const imageFormat = imageMeta ? imageMeta[2].toLowerCase() : "png"
            const dimensions = imageMeta?.[3] && imageMeta?.[4] ? imageMeta[3] + "×" + imageMeta[4] : ""
            const bytes = imageMeta ? Number(imageMeta[1]) : 0
            const size = bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : bytes >= 1024 ? Math.round(bytes / 1024) + " KB" : bytes ? bytes + " B" : ""
            const imageDescription = [dimensions, size].filter(Boolean).join(" · ") || "cached item"
            const content = image ? "Image · " + imageDescription : value
            list.push({ id, text: content, raw: line, image, imageFormat, link: !!match, host: match ? match[0].replace(/^https?:\/\//, "").split("/")[0] : "", lines: value.split("\n").length })
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
        const entry = entries.find(e => e.id === id)
        if (entry?.image) copyImage(id, autoPaste)
        else {
            decoder.command = ["cliphist", "decode", id]
            decoder.running = true
        }
    }
    function preview(id: string): void {
        previewId = id
        previewText = ""
        const entry = entries.find(e => e.id === id)
        if (entry?.image) requestImage(id)
        else {
            previewer.command = ["cliphist", "decode", id]
            previewer.running = true
        }
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
    Process {
        id: imageDecoder
        command: ["cliphist", "decode", ""]
        stdout: StdioCollector { onStreamFinished: imageWriter.writeImage(root.decodingImageId, this.data) }
        onExited: (code) => {
            if (code !== 0) {
                root.error = "Couldn't decode clipboard image"
                root.decodingImageId = ""
                root.startNextImage()
            }
        }
    }
    FileView {
        id: imageWriter
        property string currentId: ""
        printErrors: false
        function writeImage(id: string, bytes: var): void {
            currentId = id
            path = root.imagePath(id)
            setData(bytes)
        }
        onSaved: root.finishImageWrite()
        onSaveFailed: root.error = "Couldn't cache clipboard image"
    }
    Process {
        id: imageCopier
        command: ["wl-copy"]
        property bool pasteAfter: false
        onExited: (code) => {
            if (code === 0 && pasteAfter && Config.clipboard.autoPaste) root.schedulePaste()
            else if (code !== 0) root.error = "Couldn't copy clipboard image"
        }
    }
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
    property bool imageCacheReady: false
    Process { id: mkdir; command: ["mkdir", "-p", root.shareDir, root.imageCacheDir]; running: true
        onExited: code => { root.imageCacheReady = code === 0; if (root.imageCacheReady) root.startNextImage() }
    }
    FileView { id: pinsFile; path: root.pinsPath; watchChanges: true; printErrors: false
        onLoaded: { try { root.pins = JSON.parse(text()).entries || [] } catch (e) { root.pins = [] } }
        JsonAdapter { id: savePins; property var entries: [] }
    }
    Component.onCompleted: refresh()
}
