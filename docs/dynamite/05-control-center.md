# 05 — Control center

Reference screenshots: main `2356-21`, Wi-Fi `2356-53`, Bluetooth `2357-04`, Bluetooth scanning `2357-20`, Sound `2357-34`, Display `2358-11`, Game mode `2358-33`. Figma frames 05–11.

The control center (CC) lives **inside the status island**: clicking the status circle morphs that circle into a 514 px panel (see `04-island.md`). Media controls are deliberately *not* in the CC; they live in the album island ("separation of concerns").

## Grid

- Island 514 wide; content inset `Metrics.panelPad` (14) on every side.
- Grid of `Config.controlCenter.columns` columns (default 7; allowed 5–9) of 60 px cells with 11 px gaps → 7 × 60 + 6 × 11 = 486 px. With other column counts the cell size stays 60 and the island width becomes `28 + n·60 + (n−1)·11`.
- Rows are 60 px with 11 px gaps; the island height is `28 + rows·60 + (rows−1)·11` (514 for 7 rows).
- Items occupy whole cells: `w × h` in cells. Pixel size = `w·60 + (w−1)·11` by `h·60 + (h−1)·11`. So 1×1 = 60, 3×1 = 202 × 60, 7×1 = 486 × 60, 7×3 = 486 × 202.

### Layout model (`controlcenter/GridLayoutModel.qml`, persisted in `Config.controlCenter.items`)

```json
[
  { "id": "wifi",          "kind": "tile",          "x": 0, "y": 0, "w": 3, "h": 1 },
  { "id": "focus",         "kind": "tile",          "x": 3, "y": 0, "w": 3, "h": 1 },
  { "id": "lock",          "kind": "toggle",        "x": 6, "y": 0, "w": 1, "h": 1 },
  { "id": "bluetooth",     "kind": "tile",          "x": 0, "y": 1, "w": 3, "h": 1 },
  { "id": "gamemode",      "kind": "tile",          "x": 3, "y": 1, "w": 3, "h": 1 },
  { "id": "nightlight",    "kind": "toggle",        "x": 6, "y": 1, "w": 1, "h": 1 },
  { "id": "sound",         "kind": "slider",        "x": 0, "y": 2, "w": 7, "h": 1 },
  { "id": "display",       "kind": "slider",        "x": 0, "y": 3, "w": 7, "h": 1 },
  { "id": "notifications", "kind": "notifications", "x": 0, "y": 4, "w": 7, "h": 3 }
]
```

That's the default (the screenshot). Each control `id` declares which sizes it supports, and its look adapts to the size:

| Control | Kinds/sizes | Small (1×1) | Wide (≥2×1) |
|---|---|---|---|
| wifi, bluetooth, focus, gamemode, nightlight, lock | `toggle` 1×1, `tile` 2–4 × 1 | icon-only circle | icon circle + title + subtitle |
| sound, display | `slider` 2–9 × 1, or 1×2…1×4 (vertical) | — | label + "more" chevron + slider; label hidden when width < 4 cells |
| notifications | 4–9 × 2–5 | — | list |
| nowplaying (optional, "Now Playing 3×2" in the editor) | 3×2 | — | mini player |

Vertical sliders (1 × n) are allowed; the walkthrough shows dragging sound/display into tall iOS-style sliders.

Note the known bug from the walkthrough: at 8–9 columns the "Display"/"Sound" labels collide with the slider. Avoid it by hiding the label when the card is narrower than 4 cells, and by laying out label and slider in a `ColumnLayout` instead of absolute y offsets.

## Items

### Tile (`tiles/Tile.qml`) — e.g. 202 × 60
- Background `Theme.panel`, radius 30 (full pill).
- Icon circle 42 px at (8, 9): `Theme.accent` when on (icon `Theme.onAccent`), `Theme.raised` when off (icon `Theme.text`). Icon 15 px.
- Title at (60, 15): SemiBold 14 `text`. Subtitle at (60, 33): Regular 10.5 `textSecondary` (SSID, "On"/"Off", device name).
- Click the **icon circle** to toggle. Click the **rest of the tile** to open its sub-page (Wi-Fi, Bluetooth); for tiles without a page it toggles too.
- On/off color change uses the spring-mixed color pattern (`03-motion.md` §3).

### Toggle circle (`tiles/ToggleCircle.qml`) — 60 × 60
Radius 30. Off: `Theme.panel` with a `text` icon. On: `Theme.accent` with an `onAccent` icon (Night Light in the screenshot is on). Lock is a momentary action (locks immediately).

### Slider card (`tiles/SliderCard.qml`) — 486 × 60
- Background `Theme.panel`, radius 20.
- Label "Sound"/"Display" at (14, 7): SemiBold 13.
- "More" button at (449, 4): 22 px circle `Theme.card` with `chevron_right` 11 px → opens the sub-page.
- Slider at (9, 29): 468 × 22, radius 11, track `Theme.track`, fill `Theme.accent` with an 11 px radius, a small icon (`volume_up`/`light_mode`) drawn at the left inside the fill in `onAccent`.
- Dragging sets the value live; scroll wheel ±5%. Sound slider = default sink volume; Display slider = brightness of the focused output (through the ramp).

### Notifications card (`tiles/NotificationsCard.qml`) — 486 × 202
- Background `Theme.panel`, radius 20. Header at y 12: "Notifications" Regular 10.5 `textSecondary` (left) and "Clear all" Medium 10.5 `textSecondary` (right, clickable).
- Items from y 36: 468 × 68, radius 14, `Theme.card`. Each: 36 px app avatar circle (`Theme.subpage` with the app icon or the app name's first letter in `accent`), app name (Regular 10.5 `textSecondary`), summary (Bold 13 `text`), body (Regular 10.5 `textSecondary`, 2 lines max).
- Swipe right or hover-× to dismiss one; new items spring in from the top (`panel` spring on y and opacity).
- When the card is taller than its content it stays at its grid size. If the user "expands the panel" (walkthrough), the card can grow by changing its grid height in the editor.

## Sub-pages (`pages/SubPage.qml` + one file per page)

All sub-pages share a frame:

- The status island resizes to the page height (`island` spring). Inside, an inner card at (22, 20), width 470, radius 22, color `Theme.subpage`, height = island height − 40.
- **Header row** at y 21 (relative to the card), height 24. Everything in this row is **vertically centered on one line**: back button (24 px circle `Theme.raised`, `chevron_left` 12 px) at x 14, title (SemiBold 15) at x 46, optional master switch (40 × 22, `components/Switch.qml`) right-aligned at x 414. The walkthrough calls out misaligned header items as the bug that was fixed. Use a single `RowLayout` with `Layout.alignment: Qt.AlignVCenter`.
- Content starts at y 69. Section labels ("Saved", "Nearby", "Output", "Input", "Apps") are Regular 10.5 `textMuted`.
- Backspace or the back button → main grid.

### Switch (`components/Switch.qml`) — 40 × 22
Radius 11. On: track `accent`, knob 16 px `onAccent` at x 21. Off: track `Theme.switchOff`, knob `textSecondary` at x 3. Knob x and color ride the `panel` spring.

### Wi-Fi (`pages/WifiPage.qml`) — island 514 × 514
- Header: "Wi-Fi" + master switch (`Network.wifiEnabled`).
- Connected network card at y 69: 440 × 65, radius 14, `Theme.card`: signal icon in a 30 px `accent` circle, SSID SemiBold 13, "Connected · <security>" Regular 10.5, disconnect action at right.
- "Networks" section at y 149, with a pulsing 5 px `accent` dot + "Scanning" (Medium 10.5 `textSecondary`) right-aligned while the scanner is on.
- Network rows 440 × 48, radius 14, `Theme.card`, 5 px apart: signal icon (30 px `chip` circle), SSID SemiBold 13, security/known Regular 10.5, chevron. Clicking a secured unknown network expands the row (`panel` spring) into a password field + Connect button.
- The list scrolls inside the card (`ListView` with `clip: true`, `boundsBehavior: Flickable.StopAtBounds`).

### Bluetooth (`pages/BluetoothPage.qml`) — island 514 × 514
- Header: "Bluetooth" + master switch (`Bluetooth.defaultAdapter.enabled`).
- "Saved" section at y 70; device rows from y 96: 440 × 48, radius 14, `Theme.card`, 5 px apart. Each: 30 px `chip` icon circle (`headphones` etc. from `device.icon`), name SemiBold 13, status Regular 10.5 ("Connected · 80%" with battery when available, or "Saved"), and an **action pill** at the right (74 × 28, radius 14): "Disconnect" (`raised`) when connected, "Connect" (`accent` / `onAccent`) otherwise.
- **Connect/disconnect animation**: while `device.state` is connecting/disconnecting, the pill shows a small spinner and its label crossfades; when it lands, the pill color springs to the new state and the row's status text crossfades.
- "Nearby" section at y 210 with the scanning dot + "Scanning" right-aligned while `adapter.discovering`; discovery starts when the page opens and stops when it closes. Empty state: "Looking for devices… put the device in pairing mode" Regular 10.5 `textSecondary`. Nearby rows have a "Pair" pill.

### Sound (`pages/SoundPage.qml`) — island 514 × 717
- "Output" at y 69, then output devices as 440 × 38 rows (radius 12) from y 96, ~44 px pitch. The default sink row uses `Theme.accent` text + a check icon; others `Theme.card`.
- Output volume slider at y 327: 399 × 25, radius 12.5, with the percentage (Medium 10.5 `textSecondary`) at x 415.
- "Input" at y 367, input devices from y 394, input volume slider at y 535.
- "Apps" at y 576: one 440 × 56 row per playing stream (app icon, app name, its own volume slider).
- Clicking a device row makes it the default (`wpctl set-default <id>`).

### Display (`pages/DisplayPage.qml`) — island 514 × 562
One **monitor card** per Niri output (440 × 160, radius 16, `Theme.card`, 17 px apart), from y 69:

- Header: 30 px icon circle (`accent` for the focused output, `chip` otherwise), name ("eDP-1") SemiBold 14, summary "1920×1200 · 144 Hz · 1×" Regular 10.5 `textSecondary`; "focused" Medium 11 `accent` at the right for the focused output.
- Brightness slider at y 53: 378 × 25, radius 12.5, percentage at x 388. Drives the **smooth ramp** (`08-services.md` → Brightness). This is the feature the walkthrough highlights: brightness moves like a phone's, never in steps, for both laptop panels and DDC monitors.
- Scale chips at y 87: "1.0×", "1.25×", "1.5×", "1.75×", "2.0×"; 26 tall, radius 13, 5 px apart; active chip `accent`/`onAccent`, others `chip`/`text`. Applies via `niri msg output <name> scale <s>`.
- Resolution row at y 129: "Resolution" Regular 11 `textMuted`, current mode "1920×1200 @ 144 Hz" SemiBold 11.5 right-aligned. Clicking expands an inline, scrollable list of the output's modes (`panel` spring on the card height); picking one runs `niri msg output <name> mode <WxH@R>`.

Below the monitors, a **Night Light** card (440 × 85, radius 16): 30 px `accent` icon circle, "Night Light" SemiBold 14, "3700 K" Regular 10.5, master switch at the right, and a temperature slider (419 × 25) at y 51, range 2500–6500 K.

## Game mode

Turned on from the Game Mode tile (or `gamemode toggle` IPC). Screenshot `2358-33`, Figma frame 11.

- The three islands shrink away; a **full-width black bar** 47 px tall (`Config.gameMode.barHeight`) grows down from the top edge. It shows the time centered (SemiBold 15).
- The layer surface's exclusive zone becomes 47, so windows sit flush under the bar.
- The album and status circles sit **inside the bar**, vertically centered, `Config.gameMode.clusterGap` (173 px) from the screen center on either side. (This is our reading of the "Cluster gap" setting; the screenshot only shows the clock because the CC is open.) Clicking them opens the media player / CC as usual.
- The CC opens **centered under the bar** at `y = barHeight + lift` (54), x centered on the screen.
- Side effects: enable DND (Focus), switch the TLP profile to performance (`tlpctl performance`), and restore both on exit.
