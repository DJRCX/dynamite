pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.config

// Fuzzy search, frequency ranking, Flatpak desktop entries, and user-pinned Desktop launchers.
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/dynamite"
    readonly property var categories: ["All", "Development", "Internet", "Media", "System", "Office", "Games", "General"]
    property var counts: ({})
    property var desktopLaunchers: []
    property var desktopBuild: []
    property int desktopIndex: 0
    property int desktopLoadedCount: -1
    readonly property string desktopDir: Quickshell.env("HOME") + "/Desktop"
    readonly property var baseEntries: DesktopEntries.applications.values.filter(entry => !entry.noDisplay)
    readonly property var entries: {
        const out = [], seen = new Set()
        for (const entry of desktopLaunchers.concat(baseEntries)) {
            const key = (entry.name || "").toLowerCase()
            if (!key || seen.has(key)) continue
            seen.add(key)
            out.push(entry)
        }
        return out.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
    }

    function categoryFor(entry: var): string {
        if (entry.category) return entry.category
        const values = (entry.categories || []).map(v => String(v).toLowerCase())
        if (values.some(v => v.includes("development"))) return "Development"
        if (values.some(v => v.includes("network") || v.includes("internet") || v.includes("webbrowser"))) return "Internet"
        if (values.some(v => v.includes("audio") || v.includes("video") || v.includes("graphics") || v.includes("media"))) return "Media"
        if (values.some(v => v.includes("system") || v.includes("settings"))) return "System"
        if (values.some(v => v.includes("office"))) return "Office"
        if (values.some(v => v.includes("game"))) return "Games"
        return "General"
    }
    function isWebApp(entry: var): bool {
        if (entry.isWebApp) return true
        const exec = (entry.command || []).join(" ").toLowerCase()
        const file = String(entry.id || "").toLowerCase()
        return exec.includes("--app=") || exec.includes("--app-id=") || exec.includes("crx_") || file.includes("chrome-")
    }

    // Desktop Exec is tokenized without a shell; field codes have no value when launched from this picker.
    function parseExec(raw: string): var {
        let source = raw.replace(/%%/g, "%").replace(/%[fFuUdDnNickvm]/g, "")
        const parts = []; let token = "", quoted = false, escaped = false
        for (let i = 0; i < source.length; i++) {
            const ch = source[i]
            if (escaped) { token += ch; escaped = false; continue }
            if (ch === "\\") { escaped = true; continue }
            if (ch === '"') { quoted = !quoted; continue }
            if (/\s/.test(ch) && !quoted) {
                if (token) { parts.push(token); token = "" }
            } else token += ch
        }
        if (escaped) token += "\\"
        if (token) parts.push(token)
        return parts
    }

    function parseDesktopFile(raw: string, path: string): var {
        let inEntry = false
        const values = ({})
        for (const rawLine of raw.split(/\r?\n/)) {
            const line = rawLine.trim()
            if (line === "[Desktop Entry]") { inEntry = true; continue }
            if (line.startsWith("[") && inEntry) break
            if (!inEntry || line.startsWith("#")) continue
            const split = line.indexOf("=")
            if (split < 1) continue
            const key = line.slice(0, split), value = line.slice(split + 1)
            if (["Name", "Exec", "Icon", "Comment", "Categories", "NoDisplay", "Hidden"].includes(key) && values[key] === undefined)
                values[key] = value
        }
        const command = parseExec(values.Exec || "")
        if (!values.Name || command.length === 0 || values.Hidden === "true") return null
        const categories = (values.Categories || "").split(";").filter(Boolean)
        const category = categoryFor({ categories })
        const entry = {
            id: path,
            name: values.Name,
            icon: values.Icon || "apps",
            iconPath: values.Icon && values.Icon.startsWith("/") ? values.Icon : "",
            comment: values.Comment || category,
            genericName: "",
            keywords: [],
            categories,
            category,
            command,
            execString: values.Exec || "",
            workingDirectory: "",
            runInTerminal: false,
            isWebApp: /--app(?:-id)?=|crx_/i.test(values.Exec || "") || /\/chrome-/i.test(path),
        }
        if (values.NoDisplay === "true" && !path.includes("/Desktop/")) return null
        return entry
    }
    function loadDesktopFiles(): void {
        if (desktopLoadedCount === desktopFiles.count || desktopReader.running) return
        desktopLoadedCount = desktopFiles.count
        desktopIndex = 0
        desktopBuild = []
        if (desktopFiles.count) readNextDesktopFile()
        else desktopLaunchers = []
    }
    function readNextDesktopFile(): void {
        if (desktopIndex >= desktopFiles.count) { desktopLaunchers = desktopBuild.slice(); return }
        desktopReader.command = ["cat", desktopFiles.get(desktopIndex, "filePath")]
        desktopReader.running = true
    }
    function acceptDesktopFile(raw: string): void {
        const entry = parseDesktopFile(raw, desktopFiles.get(desktopIndex, "filePath"))
        if (entry) desktopBuild = desktopBuild.concat([entry])
    }
    function categoryMatches(entry: var, selected: string): bool {
        return selected === "All" || categoryFor(entry) === selected
    }
    function fieldScore(text: string, query: string, fuzzy: bool): real {
        if (!text) return 0
        const t = text.toLowerCase()
        if (t.startsWith(query)) return 100
        const at = t.indexOf(query)
        if (at > 0) return /[\s\-_.]/.test(t[at - 1]) ? 80 : 60
        if (!fuzzy) return 0
        let pos = -1, gaps = 0
        for (const ch of query) {
            const next = t.indexOf(ch, pos + 1)
            if (next < 0) return 0
            if (pos >= 0) gaps += next - pos - 1
            pos = next
        }
        return Math.max(0, 30 - 3 * gaps)
    }
    function score(entry: var, query: string): real {
        const command = (entry.command || []).join(" ")
        return Math.max(fieldScore(entry.name, query, true),
                        0.8 * fieldScore(entry.genericName, query, false),
                        0.6 * fieldScore((entry.keywords || []).join(" "), query, false),
                        0.4 * fieldScore(entry.comment, query, false),
                        0.35 * fieldScore(command, query, false))
    }
    function search(query, category) {
        const q = query.trim().toLowerCase()
        const candidates = entries.filter(entry => categoryMatches(entry, category))
        if (q === "") return candidates
        const scored = []
        for (const entry of candidates) {
            const s = score(entry, q)
            if (s > 0) scored.push({ entry, score: s + 8 * Math.log(1 + (counts[entry.id] || 0)) })
        }
        return scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name)).map(item => item.entry)
    }

    function launch(entry: var): void {
        let command = (entry.command || []).slice()
        if (!command.length) return
        if (entry.runInTerminal) command = [Config.system.terminal, "-e"].concat(command)
        Quickshell.execDetached(["niri", "msg", "action", "spawn", "--"].concat(command))
        const next = Object.assign({}, counts)
        next[entry.id] = (next[entry.id] || 0) + 1
        counts = next
        countsFile.setText(JSON.stringify(counts))
    }
    function calculate(query: string): string {
        const raw = query.trim()
        if (!raw || !/\d/.test(raw)) return ""
        let expression = raw.replace(/^=/, "").replace(/=$/, "").trim()
        if (!/[+\-*/%^!xX()]|\b(sqrt|abs|round|floor|ceil|sin|cos|tan|log|ln|exp|pi|e)\b/i.test(expression)) return ""
        expression = expression.replace(/(\d),(\d)/g, "$1.$2")
            .replace(/([\d.]+)%\s*(?:of|\*)\s*([\d.]+)/gi, "($1/100)*$2")
            .replace(/([\d.]+)\s*\+\s*([\d.]+)%/g, "($1*(1+($2/100)))")
            .replace(/([\d.]+)\s*-\s*([\d.]+)%/g, "($1*(1-($2/100)))")
            .replace(/([\d.]+)%/g, "($1/100)")
            .replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/gi, "Math.E")
            .replace(/\b(sqrt|abs|round|floor|ceil|sin|cos|tan|log|exp|ln)\s*\(/gi, (_, fn) => "Math." + (fn.toLowerCase() === "ln" ? "log" : fn.toLowerCase()) + "(")
            .replace(/([0-9])\s*[xX]\s*([0-9])/g, "$1*$2")
            .replace(/([0-9])\s*\(/g, "$1*(").replace(/\)\s*([0-9])/g, ")*$1")
            .replace(/([0-9]+)!/g, (_, digits) => {
                const n = Number(digits); if (n > 170) return "Infinity"
                let value = 1; for (let i = 2; i <= n; i++) value *= i
                return String(value)
            })
        const allowed = expression.replace(/Math\.(?:PI|E|sqrt|abs|round|floor|ceil|sin|cos|tan|log|exp)/g, "")
        if (/[a-zA-Z_$]/.test(allowed) || !/^[\d\s.+\-*/()%]*$/.test(allowed)) return ""
        try {
            const value = Function('"use strict"; return (' + expression + ")")()
            return typeof value === "number" && isFinite(value) ? String(Math.round(value * 1e10) / 1e10) : ""
        } catch (error) { return "" }
    }
    function copy(text: string): void { Quickshell.execDetached(["wl-copy", "--", text]) }

    FolderListModel {
        id: desktopFiles
        folder: "file://" + root.desktopDir
        nameFilters: ["*.desktop"]
        showDirs: false
        sortField: FolderListModel.Name
    }
    Connections { target: desktopFiles; function onCountChanged() { root.loadDesktopFiles() } }
    Process {
        id: desktopReader
        command: []
        stdout: StdioCollector { onStreamFinished: root.acceptDesktopFile(text) }
        onExited: { root.desktopIndex++; root.readNextDesktopFile() }
    }
    Process { running: true; command: ["mkdir", "-p", root.stateDir]; onExited: countsFile.reload() }
    FileView {
        id: countsFile
        path: root.stateDir + "/launch-counts.json"
        printErrors: false
        onLoaded: { try { root.counts = JSON.parse(text()) } catch (error) { root.counts = {} } }
    }
    Component.onCompleted: {
        Qt.callLater(root.loadDesktopFiles)
        if (Quickshell.env("DYNAMITE_DEV") === "1") {
            const dataDirs = (Quickshell.env("XDG_DATA_DIRS") || "").split(":")
            const userFlatpak = Quickshell.env("HOME") + "/.local/share/flatpak/exports/share"
            const systemFlatpak = "/var/lib/flatpak/exports/share"
            if (!dataDirs.includes(userFlatpak) || !dataDirs.includes(systemFlatpak))
                console.warn("[Dynamite] Flatpak desktop exports are absent from XDG_DATA_DIRS")
        }
    }
}
