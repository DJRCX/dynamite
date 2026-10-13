pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root
    property var results: []
    property bool loading: false
    property string error: ""
    property string query: ""
    property string sort: "toplist"
    property int page: 1
    property bool hasMore: false
    property var selected: null
    property string previousWallpaper: ""
    property bool previewing: false
    property string pendingUrl: ""
    property string pendingPath: ""
    property string pendingAction: ""
    property string pendingTheme: ""

    function search(searchText: string, sortBy: string, addResults: bool): void {
        if (loading) return
        if (!addResults) { query = searchText; sort = sortBy || "toplist"; page = 1; results = []; error = "" }
        loading = true
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            loading = false
            if (xhr.status !== 200) { error = "Wallhaven is unreachable"; hasMore = false; return }
            try {
                const response = JSON.parse(xhr.responseText)
                results = addResults ? results.concat(response.data || []) : (response.data || [])
                hasMore = Boolean(response.meta && response.meta.current_page < response.meta.last_page)
            } catch (e) { error = "Wallhaven returned an invalid response"; hasMore = false }
        }
        xhr.open("GET", "https://wallhaven.cc/api/v1/search?q=" + encodeURIComponent(query) +
                 "&purity=" + encodeURIComponent(Config.wallhaven.purity) +
                 "&categories=" + encodeURIComponent(Config.wallhaven.categories) +
                 "&sorting=" + encodeURIComponent(sort) + "&order=desc&page=" + page)
        if (Config.wallhaven.apiKey) xhr.setRequestHeader("X-API-Key", Config.wallhaven.apiKey)
        xhr.send()
    }
    function loadMore(): void { if (hasMore && !loading) { page += 1; search(query, sort, true) } }
    function choose(item: var): void { selected = item }
    function sourceUrl(item: var, original: bool): string {
        return original ? item.path : (item.thumbs?.large || item.path)
    }
    function preview(item: var): void {
        if (!item) return
        if (!previewing) {
            previousWallpaper = Config.wallpaper.current["*"] || ""
            previewing = true
        }
        selected = item
        startDownload(sourceUrl(item, false), previewDir() + "/preview-" + safeId(item.id) + extension(item.path), "preview")
    }
    function revert(): void {
        if (!previewing) return
        if (previousWallpaper) Wallpaper.set(previousWallpaper, "")
        previewing = false
        previousWallpaper = ""
        pendingAction = ""
    }
    function keep(item: var, themeName: string): void {
        if (!item) return
        if (mkdir.running || download.running || categorize.running) return
        pendingTheme = themeName
        const path = previewDir() + "/keep-" + safeId(item.id) + extension(item.path)
        startDownload(sourceUrl(item, true), path, "keep")
    }
    function previewDir(): string { return Quickshell.env("HOME") + "/.cache/dynamite/wallhaven" }
    function safeId(value: string): string { return String(value).replace(/[^A-Za-z0-9_-]/g, "_") }
    function extension(url: string): string {
        const found = String(url).match(/\.(jpe?g|png|webp)(?:\?|$)/i)
        return found ? "." + found[1].toLowerCase().replace("jpeg", "jpg") : ".jpg"
    }
    function startDownload(url: string, path: string, action: string): void {
        pendingUrl = url; pendingPath = path; pendingAction = action
        if (action !== "keep") pendingTheme = ""
        mkdir.command = ["mkdir", "-p", path.substring(0, path.lastIndexOf("/"))]
        mkdir.running = true
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", "/tmp"]
        onExited: (code) => {
            if (code !== 0) { root.error = "Could not create wallpaper cache"; return }
            download.command = ["curl", "-L", "--fail", "--silent", "--show-error", "-o", root.pendingPath, root.pendingUrl]
            download.running = true
        }
    }
    Process {
        id: download
        command: ["curl"]
        onExited: (code) => {
            if (code !== 0) { root.error = "Wallpaper download failed"; return }
            root.error = ""
            if (root.pendingAction === "preview") Wallpaper.set(root.pendingPath, "")
            else if (root.pendingAction === "keep") {
                categorize.exec(["python3", Quickshell.shellDir + "/scripts/theme_manager.py", "add-background",
                                 root.pendingTheme, root.pendingPath])
                return
            }
            root.pendingAction = ""
        }
    }
    Process {
        id: categorize
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const path = text.trim()
                    if (!path) throw new Error("empty saved path")
                    Wallpaper.set(path, "")
                    root.previewing = false
                    root.previousWallpaper = ""
                    root.pendingAction = ""
                    root.pendingTheme = ""
                    Themes.refresh()
                } catch (error) {
                    root.error = "Could not save the downloaded wallpaper"
                }
            }
        }
        onExited: (code) => { if (code !== 0) root.error = "Could not save the downloaded wallpaper" }
    }
}
