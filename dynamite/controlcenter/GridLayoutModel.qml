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

    readonly property var defaultItems: [
        { id: "wifi", kind: "tile", x: 0, y: 0, w: 3, h: 1 },
        { id: "focus", kind: "tile", x: 3, y: 0, w: 3, h: 1 },
        { id: "lock", kind: "toggle", x: 6, y: 0, w: 1, h: 1 },
        { id: "bluetooth", kind: "tile", x: 0, y: 1, w: 3, h: 1 },
        { id: "gamemode", kind: "tile", x: 3, y: 1, w: 3, h: 1 },
        { id: "nightlight", kind: "toggle", x: 6, y: 1, w: 1, h: 1 },
        { id: "sound", kind: "slider", x: 0, y: 2, w: 7, h: 1 },
        { id: "display", kind: "slider", x: 0, y: 3, w: 7, h: 1 },
        { id: "notifications", kind: "notifications", x: 0, y: 4, w: 7, h: 3 }
    ]

    // Which kinds and sizes each control supports: [kind, minW, maxW, minH, maxH].
    readonly property var capabilities: ({
        wifi: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        bluetooth: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        focus: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        gamemode: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        nightlight: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        lock: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        caffeine: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        power: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        power: [["toggle", 1, 1, 1, 1], ["tile", 2, 4, 1, 1]],
        sound: [["slider", 2, 9, 1, 1], ["slider", 1, 1, 2, 4]],
        display: [["slider", 2, 9, 1, 1], ["slider", 1, 1, 2, 4]],
        notifications: [["notifications", 4, 9, 2, 5]],
        nowplaying: [["nowplaying", 3, 3, 2, 2]],
        system: [["tile", 2, 4, 1, 1], ["system", 3, 4, 2, 2]]
    })

    readonly property int columns: Math.max(5, Math.min(9, Config.controlCenter.columns))
    readonly property var items: Config.controlCenter.items && Config.controlCenter.items.length
                                 ? Config.controlCenter.items : defaultItems
    readonly property int rows: Math.max(1, ...items.map(i => i.y + i.h))

    function span(cells: int): int { return cells * cell + (cells - 1) * gap }
    readonly property int width: 2 * pad + span(columns)
    readonly property int mainHeight: 2 * pad + span(rows)

    // The Display page sizes itself to its monitor cards (562 for two); its page sets this while open.
    property real displayHeight: Metrics.ccDisplayHeight

    function pageWidth(page: string): int { return page === "main" ? width : Metrics.ccWidth }
    function pageHeight(page: string): int {
        switch (page) {
        case "main": return mainHeight
        case "sound": return Metrics.ccSoundHeight
        case "display": return Math.min(Metrics.ccSoundHeight, displayHeight)
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
        if (item.x < 0 || item.y < 0 || item.x + item.w > cols) return false
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
    function reset(): void { Config.controlCenter.items = defaultItems }
    function sizeAllowed(id: string, kind: string, w: int, h: int): bool {
        const caps = capabilities[id] ?? []
        return caps.some(c => c[0] === kind && w >= c[1] && w <= c[2] && h >= c[3] && h <= c[4])
    }
    function firstFree(list: var, w: int, h: int, cols: int): var {
        for (let y = 0; y < 64; ++y)
            for (let x = 0; x + w <= cols; ++x)
                if (fits(list, { id: "__probe", x: x, y: y, w: w, h: h }, cols)) return { x: x, y: y }
        return null
    }
    // Pack items top-to-bottom, left-to-right in their current reading order.
    function tidy(list: var, cols: int): var {
        const sorted = list.slice().sort((a, b) => a.y - b.y || a.x - b.x)
        const placed = []
        for (const item of sorted) {
            const w = Math.min(item.w, cols)
            const spot = firstFree(placed, w, item.h, cols)
            placed.push(Object.assign({}, item, { x: spot.x, y: spot.y, w: w }))
        }
        return placed
    }
    function save(list: var): void { Config.controlCenter.items = list }
}
