# 04 — The islands

Reference screenshots: collapsed `2026-10-08__2354-42.png`, media `2354-53`, hover clock `2355-08`, calendar `2355-18` (all in `/home/djrcx/Projects/figma/Screenshots of the design/`). Figma frames 01–04.

## Geometry model

Let `W` be the screen width, `cx = W / 2`, `g = Config.island.gap` (11), `lift = Config.island.stageLift` (7), `h0 = Config.island.barHeight` (33), `c = Metrics.circle` (33).

Each of the three islands is a `SpringRect` (see `03-motion.md`) whose **target** rectangle is a pure function of `Island.mode`. Write these functions once in `IslandWindow.qml` (or a small `IslandGeometry.qml` helper) and bind the islands to them.

### Center island

| Mode | Size (w × h) | y | radius |
|---|---|---|---|
| `collapsed` | `Config.island.collapsedWidth` × `h0` (96 × 33) | `g` (11) | `h/2` |
| `clock` | 254 × 116 | `g + lift` (18) | 31 |
| `calendar` | 335 × 277 | 18 | 31 |
| `launcher` | 514 × (content, 366 for 6 results, 130 for 1) | 18 | 31 |
| `power` | 514 × 110 | 18 | 31 |
| `osd` | 280 × 44 | 18 | 22 (pill) |
| `toast` | 450 × 67 | 18 | 33.5 (pill) |
| `polkit` | 430 × 266 | 18 | 31 |
| `themes` | 802 × 220 | 18 | 31 |
| `media`, `cc` | same as `collapsed` | 11 | 16.5 |

Always horizontally centered: `x = cx − w/2`. Radius rule: `h ≤ 67 ? h/2 : Config.island.radiusExpanded`.

With `Config.island.notchMode` on, `y = 0` in every mode, the top corners are square (use `ClippingRectangle`'s per-corner radii), and the visible height grows by `g`.

### Side circles (album left, status right)

```text
gap   = centerExpanded ? Metrics.expandedGap (18.5) : Metrics.collapsedGap (10)
album.x  = center.x − gap − c
status.x = center.x + center.w + gap
y = g (11) for both — the circles never lift
```

These were checked against every screenshot (e.g. launcher: center 703…1217, album x 652, status x 1236).

Because `center.x` and `center.w` are themselves animating, bind the circles to the **animated** values (`centerIsland.x`, `centerIsland.width`), not the targets. They then ride the center island's spring exactly, overshoot included.

### Album island in `media` mode

Target: 410 × 213, `y = 18`, radius 31, right edge at `center.x − Metrics.mediaGap` (15) → `x = center.x − 15 − 410` (487 on a 1920 screen).

### Status island in `cc` mode

Target: 514 × (page height), `x` = its collapsed x (`center.x + 96 + 10` = 1018), `y = 11`, radius 31. Page heights: main 514, Wi-Fi 514, Bluetooth 514, Sound 717, Display 562. (The Wi-Fi and Bluetooth screenshots were taken mid-animation, which is why they look offset; use the settled values here.)

### Visibility

- Album circle: visible when `Media.activePlayer` exists, or always if `Config.island.albumCircleWhilePlaying` is false. When it hides, it shrinks to 0×0 around its center with the `island` spring; the center pill does **not** move (the layout stays symmetric around `cx`).
- Status circle: visible when `Config.island.statusCircle`.
- In game mode all three shrink away (`05-control-center.md` → Game mode).

## Collapsed contents

### Center pill (`panels/CollapsedClock.qml`)
Time `HH:mm` (24 h, leading zero: "00:47"), Inter SemiBold 15, `Theme.text`, centered. Use `SystemClock { precision: SystemClock.Minutes }`.

### Status circle (`components/StatusCircle.qml`)

A 33 px black circle containing:

- **Battery ring.** Outer diameter 27 (inset `Config.island.innerPadding` = 3), stroke 2.3, centered. A full-circle track in `Theme.batteryTrack`, and the level arc in `Theme.text`. The arc is **centered at 12 o'clock and grows both ways**, so the head and tail meet at the bottom when full (80% leaves a 72° gap centered at 6 o'clock).
- **Wi-Fi glyph** 12 px, centered, `Theme.text` (use `wifi`, `wifi_off`, or a strength variant).
- While charging, the arc color is `Theme.accent`. Below 15% (not charging) it's `Theme.danger`.

```qml
import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.config
import qs.services
import qs.components

Item {
    id: root
    width: 33; height: 33
    readonly property real ring: Metrics.ringWidth
    readonly property real r: (width - 2 * Config.island.innerPadding) / 2 - ring / 2
    property real sweep: 360 * Battery.fraction
    Behavior on sweep { Spring { token: Motion.panel } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: Theme.batteryTrack; strokeWidth: root.ring
            PathAngleArc { centerX: 16.5; centerY: 16.5; radiusX: root.r; radiusY: root.r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"; strokeWidth: root.ring; capStyle: ShapePath.RoundCap
            strokeColor: Battery.charging ? Theme.accent : (Battery.fraction < 0.15 ? Theme.danger : Theme.text)
            // Qt angles: 0° = 3 o'clock, clockwise. Center the arc on 12 o'clock (-90°).
            PathAngleArc { centerX: 16.5; centerY: 16.5; radiusX: root.r; radiusY: root.r
                           startAngle: -90 - root.sweep / 2; sweepAngle: root.sweep }
        }
    }
    Icon { anchors.centerIn: parent; name: Network.wifiIcon; size: 12 }
}
```

### Album circle (`components/AlbumCircle.qml`)
The current track's art (`Media.activePlayer.trackArtUrl`) cropped to a 33 px circle (`ClippingRectangle` radius 16.5, `Image { fillMode: Image.PreserveAspectCrop }`). No tint at this size. Fallback: `Theme.panel` with a `music_note` icon.

## Hover clock (`panels/HoverClock.qml`) — 254 × 116

- Time "00:47", Inter SemiBold 22, centered horizontally, top at y 24.
- **Week strip** below (y 57–97): 7 day columns, 28 px apart, centered on today. Each column has a weekday letter (Medium 9.5) above the date number (Medium 13).
- **Today**: a 33 × 40 rounded box (radius 9, color `Theme.panel`) behind the column; weekday as "SAT" (Bold 9.5, `Theme.text`), date "12" in **Bold 17, `Theme.accent`**.
- **Falloff**: the other columns fade with distance from today, like a dial. Opacity of the number at offsets −3…+3: 0.10, 0.40, 0.70, today, 0.90, 0.45, 0.10. Letters at roughly 60% of their number's opacity.
- **Sundays** use `Theme.danger` (at the same falloff opacity).
- Click anywhere → `Island.open("calendar")`.

## Calendar (`panels/Calendar.qml`) — 335 × 277

- Header row at y 14: prev/next month buttons, 28 px circles in `Theme.control` with `chevron_left`/`chevron_right` 12 px, at x 14 and x 293. Month title "September 2026" SemiBold 13, centered.
- Weekday header at y 53: S M T W T F S, Medium 10, `Theme.textMuted`. Column centers 44 px apart, first at x 36.
- 6 rows of dates, row pitch 32 px starting at y 82, Medium 12 `Theme.text`. Days from adjacent months at 20% opacity.
- **Today**: a 26 px `Theme.accent` circle behind the number; number Bold 12, `Theme.onAccent`.
- Prev/next animate the grid: the old month slides 24 px and fades out, the new month slides in from the other side (`panel` spring). Scroll wheel also changes months.
- Pointer leaves for 350 ms → collapse. Click outside → collapse.

## Media player (`panels/MediaPlayer.qml`) — album island at 410 × 213

The island is black with 14 px padding around a **tinted card** (382 × 185, radius 20):

1. **Album blur**: the art scaled to cover the card (overscan it: −60, −80, 502 × 345), blur radius 70.
2. **Accent tint**: full-card `Theme.mediaTint` (accent at 30%).
3. **Shade**: full-card `Theme.mediaShade` (accent darkened to ~12%, at 55%).

Why the tint matters (from the walkthrough): untinted album art never matches the theme. Tinting the blurred background with the accent makes any cover feel part of the system. Don't skip it, and recompute it when the theme changes.

On top of the card:

| Element | Position (card coords) | Spec |
|---|---|---|
| Album art | 15, 14 · 120 × 120 | radius 10, `PreserveAspectCrop` |
| Title | 150, 18 | SemiBold 17, `text`, elide right at card width − 164 |
| Artist | 150, 41 | Regular 13, `text` @ 72% |
| Album | 150, 60 | Regular 11.5, `text` @ 38% |
| Player name ("Spotify") | 150, 76 | Regular 11.5, `text` @ 38% |
| Progress track | 150, 106 · 218 × 4 | radius 2, `trackOnIsland`; fill `accent`; draggable (seek on release) |
| Elapsed / total | 150, 115 / right-aligned to 368 | Medium 10.5, `text` @ 70% / 50% |
| Prev · Play/Pause · Next | centers at x 229, 281, 334; y 150 | play button is a 42 px circle `ghostButton`; icons 11–14 px `text` |

Position updates: `Media.activePlayer.position` only updates when you ask. Run a `Timer { interval: 1000; running: Island.mode === "media" && player.isPlaying; onTriggered: player.positionChanged() }`.

Multiple players: prefer the one that's playing; otherwise the most recently active. Scroll on the card switches players.
