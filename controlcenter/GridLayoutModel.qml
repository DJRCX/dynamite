pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.theme

// The CC grid: layout data from Config.controlCenter.items plus pure placement functions (used by the editor).
Singleton {
    id: root
    readonly property int cell: 60
    readonly property int gap: 11
    readonly property int pad: 14
    readonly property int pitch: cell + gap
    readonly property int maxRows: 64

    readonly property var defaultItems: [
        { id: "wifi", kind: "tile", x: 0, y: 0, w: 3, h: 1 },
        { id: "focus", kind: "tile", x: 3, y: 0, w: 3, h: 1 },
        { id: "lock", kind: "toggle", x: 6, y: 0, w: 1, h: 1 },
        { id: "bluetooth", kind: "tile", x: 0, y: 1, w: 3, h: 1 },
        { id: "gamemode", kind: "tile", x: 3, y: 1, w: 3, h: 1 },
        { id: "nightlight", kind: "toggle", x: 6, y: 1, w: 1, h: 1 },
        { id: "sound", kind: "slider", x: 0, y: 2, w: 7, h: 1 },
        { id: "display", kind: "slider", x: 0, y: 3, w: 7, h: 1 },
        { id: "notifications", kind: "notifications", x: 0, y: 4, w: 7, h: 3 },
        { id: "tray", kind: "tray", x: 0, y: 7, w: 7, h: 1 }
    ]

    // [kind, minW, maxW, minH, maxH]. Every control can grow by whole cells;
    // minimums keep each control's contents usable.
    readonly property var capabilities: ({
        wifi: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        bluetooth: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        focus: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        gamemode: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        nightlight: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        lock: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        caffeine: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        power: [["toggle", 1, 9, 1, 64], ["tile", 2, 9, 1, 64]],
        sound: [["slider", 1, 9, 1, 64]],
        display: [["slider", 1, 9, 1, 64]],
        notifications: [["notifications", 4, 9, 2, 64]],
        tray: [["tray", 3, 9, 1, 64]],
        nowplaying: [["nowplaying", 3, 9, 2, 64]],
        system: [["tile", 2, 9, 1, 64], ["system", 3, 9, 2, 64]]
    })

    readonly property int columns: Math.max(5, Math.min(9, Config.controlCenter.columns))
    readonly property var items: Config.controlCenter.items && Config.controlCenter.items.length
                                 ? Config.controlCenter.items : defaultItems
    readonly property int rows: Math.max(1, ...items.map(i => i.y + i.h))
    function rowsFor(list: var): int { return Math.max(1, ...list.map(i => i.y + i.h)) }

    function span(cells: int): int { return cells * cell + (cells - 1) * gap }
    readonly property int width: 2 * pad + span(columns)
    readonly property int mainHeight: 2 * pad + span(rows)
    function heightFor(list: var): int { return 2 * pad + span(rowsFor(list)) }

    // The Display page sizes itself to its monitor cards (562 for two); its page sets this while open.
    property real displayHeight: Metrics.ccDisplayHeight

    function pageWidth(page: string): int { return page === "main" ? width : Metrics.ccWidth }
    function pageHeight(page: string): int {
        switch (page) {
        case "main": return mainHeight
        case "sound": return Metrics.ccSoundHeight
        case "display": return Math.min(Metrics.ccSoundHeight, displayHeight)
        case "nightlight": return Metrics.ccHeight
        case "battery": return 446
        case "system": return 600
        default: return Metrics.ccHeight
        }
    }

    function rect(item: var): var {
        return { x: pad + item.x * pitch, y: pad + item.y * pitch, w: span(item.w), h: span(item.h) }
    }

    // --- pure placement helpers ---
    function overlaps(a: var, b: var): bool {
        return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
    }
    function fits(list: var, item: var, cols: int): bool {
        if (item.x < 0 || item.y < 0 || item.x + item.w > cols || item.y + item.h > maxRows) return false
        return !list.some(other => other.id !== item.id && overlaps(other, item))
    }
    function canPlace(item: var, x: int, y: int): bool {
        const candidate = Object.assign({}, item, { x: x, y: y })
        return fits(items, candidate, columns)
    }
    function reflow(list: var, moving: var, target: var, cols: int): var {
        const rest = list.filter(item => item.id !== moving.id)
        const candidate = Object.assign({}, moving, { x: target.x, y: target.y })
        if (!fits(rest, candidate, cols)) return null
        return rest.concat([candidate]).sort((a, b) => a.y - b.y || a.x - b.x)
    }
    function clampSize(id: string, kind: string, w: int, h: int, x: int, y: int, cols: int): var {
        const limits = (capabilities[id] ?? []).find(c => c[0] === kind)
        if (!limits) return { w: 0, h: 0 }
        const minW = limits[1]
        const maxW = Math.min(limits[2], cols - x)
        const minH = limits[3]
        const maxH = Math.min(limits[4], maxRows - y)
        return { w: Math.max(minW, Math.min(maxW, Math.round(w))),
                 h: Math.max(minH, Math.min(maxH, Math.round(h))) }
    }
    // Resize keeps the selected item anchored, then packs colliding controls
    // into the next available cells while leaving other positions untouched.
    function resizeLayout(list: var, resizing: var, w: int, h: int, cols: int, x: int, y: int): var {
        const candidate = Object.assign({}, resizing, { x: x, y: y, w: w, h: h })
        if (!sizeAllowed(candidate.id, candidate.kind, w, h) || !fits([], candidate, cols)) return null
        const placed = [candidate]
        const rest = list.filter(item => item.id !== resizing.id)
            .slice().sort((a, b) => a.y - b.y || a.x - b.x)
        for (let item of rest) {
            if (item.w > cols) item = Object.assign({}, item, { w: cols })
            if (fits(placed, item, cols)) {
                placed.push(item)
                continue
            }
            const spot = nearestFree(placed, item, cols)
            if (!spot) return null
            placed.push(Object.assign({}, item, { x: spot.x, y: spot.y }))
        }
        return placed.sort((a, b) => a.y - b.y || a.x - b.x)
    }
    function reset(): void { Config.controlCenter.items = defaultItems }
    function sizeAllowed(id: string, kind: string, w: int, h: int): bool {
        const caps = capabilities[id] ?? []
        return caps.some(c => c[0] === kind && w >= c[1] && w <= c[2] && h >= c[3] && h <= c[4])
    }
    function firstFree(list: var, w: int, h: int, cols: int): var {
        for (let y = 0; y + h <= maxRows; ++y)
            for (let x = 0; x + w <= cols; ++x)
                if (fits(list, { id: "__probe", x: x, y: y, w: w, h: h }, cols)) return { x: x, y: y }
        return null
    }
    function nearestFree(list: var, item: var, cols: int): var {
        const startY = Math.max(0, Math.min(item.y, maxRows - item.h))
        const xs = []
        for (let x = 0; x + item.w <= cols; ++x) xs.push(x)
        xs.sort((a, b) => Math.abs(a - item.x) - Math.abs(b - item.x) || a - b)
        for (let y = startY; y + item.h <= maxRows; ++y)
            for (const x of xs)
                if (fits(list, { id: "__probe", x: x, y: y, w: item.w, h: item.h }, cols))
                    return { x: x, y: y }
        return null
    }
    // Pack items top-to-bottom, left-to-right in their current reading order.
    function tidy(list: var, cols: int): var {
        const sorted = list.slice().sort((a, b) => a.y - b.y || a.x - b.x)
        const placed = []
        for (const item of sorted) {
            const w = Math.min(item.w, cols)
            const spot = firstFree(placed, w, item.h, cols)
            if (!spot) continue
            placed.push(Object.assign({}, item, { x: spot.x, y: spot.y, w: w }))
        }
        return placed
    }
    // Preserve valid positions when the configured grid narrows; only relocate
    // controls that no longer fit their column or collide after width clamping.
    function fitColumns(list: var, cols: int): var {
        const placed = []
        const sorted = list.slice().sort((a, b) => a.y - b.y || a.x - b.x)
        for (let item of sorted) {
            const w = Math.min(item.w, cols)
            if (w !== item.w) item = Object.assign({}, item, { w: w })
            if (fits(placed, item, cols)) {
                placed.push(item)
                continue
            }
            const spot = nearestFree(placed, item, cols)
            if (spot) placed.push(Object.assign({}, item, { x: spot.x, y: spot.y }))
        }
        return placed
    }
    function save(list: var): void { Config.controlCenter.items = list }

    // Add the new tray card to existing saved layouts once, while still allowing the user to remove it later.
    function ensureTray(): void {
        const saved = Config.controlCenter.items
        if (!saved || !saved.length || saved.some(item => item.id === "tray")) return
        const size = capabilities.tray[0]
        const spot = firstFree(saved, size[1], size[3], columns)
        if (spot) Config.controlCenter.items = saved.concat([{ id: "tray", kind: size[0], x: spot.x, y: spot.y, w: size[1], h: size[3] }])
    }
    Component.onCompleted: Qt.callLater(() => root.ensureTray())
    Connections {
        target: Config.controlCenter
        function onItemsChanged(): void { Qt.callLater(() => root.ensureTray()) }
    }
}
