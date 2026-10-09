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
    function keep(item: var): void {
        if (!item) return
        const directory = wallpaperDir()
        const path = directory + "/wallhaven-" + safeId(item.id) + extension(item.path)
        startDownload(sourceUrl(item, true), path, "keep")
    }
    function wallpaperDir(): string {
        const override = Quickshell.env("DYNAMITE_WALLPAPER_DIR")
        if (override) return override
        return Config.wallpaper.dir.replace(/^~/, Quickshell.env("HOME"))
    }
    function previewDir(): string { return Quickshell.env("HOME") + "/.cache/dynamite/wallhaven" }
    function safeId(value: string): string { return String(value).replace(/[^A-Za-z0-9_-]/g, "_") }
    function extension(url: string): string {
        const found = String(url).match(/\.(jpe?g|png|webp)(?:\?|$)/i)
        return found ? "." + found[1].toLowerCase().replace("jpeg", "jpg") : ".jpg"
    }
    function startDownload(url: string, path: string, action: string): void {
        pendingUrl = url; pendingPath = path; pendingAction = action
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
                Wallpaper.set(root.pendingPath, "")
                root.previewing = false
                root.previousWallpaper = ""
            }
            root.pendingAction = ""
        }
    }
}
