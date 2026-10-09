# 07 — Settings app

Reference `0002-34` (Bar & Island) and `0002-19` (Control Center). Figma frames 20–21.

A `FloatingWindow` (title "Dynamite Settings", app id `dynamite-settings`) opened via `settings open <page>` IPC or a gear button. Add a Niri window rule so it opens floating, centered, 1320 × 970:

```kdl
window-rule {
    match app-id="^dynamite-settings$"
    open-floating true
    default-column-width { fixed 1320; }
    default-window-height { fixed 970; }
}
```

Every control writes straight to `Config` (which saves to disk). The shell reacts live; there's no Apply button. Changing a geometry setting animates the island to its new shape with the `island` spring, so the user sees the effect immediately.

## Window chrome

- Background `Theme.window`, radius 16, 1 px border `Qt.alpha("#FFFFFF", 0.06)`.
- **Sidebar** 232 px wide, `Theme.sidebar`:
  - Search field at (11, 11), 198 × 31, radius 9, `Theme.field`, placeholder "Search Settings" Regular 12 `textMuted`. Filters the nav items and rows (matching rows get an `accent` outline pulse when you jump to them).
  - Nav items from y 54, 198 × 38, radius 10, 5 px apart: icon in a 26 px circle at (9, 6), label Medium 12.5 `text` at x 45. The selected item has a `Theme.card` background and an `accent` icon circle; the others use `accentContainer` circles. The selection background slides between items with the `panel` spring.
  - Items: **Bar & Island**, **Clock & Date**, **Appearance**, **Motion**, **Launcher**, **Notifications**, **Control Center**, **Lock Screen**, **System**.
- Back/forward history buttons: 24 px `Theme.control` circles at (239, 11) and (275, 11).
- Content column: x 243, width 1054, scrolls; thin scrollbar (3 px, `Qt.alpha("#FFFFFF", 0.22)`) at x 1313.

## Page anatomy

- **Header card** at y 46: 1054 × 156, radius 12, `Theme.group`. A 56 px circle (`accentContainer`, or `accent` for the active page's icon) centered at the top (y 23), title SemiBold 18 centered at y 88, description Regular 12 `textSecondary` centered at y 118.
- **Groups**: 1054 wide, radius 12, `Theme.group`, 13 px below the previous block. An optional group label above it (Regular 10.5 `textMuted`, e.g. "Game mode").
- **Rows** inside a group, separated by 1 px dividers (`Qt.alpha("#FFFFFF", 0.05)`, inset 15 px):
  - *Toggle row*, 44 tall: label Medium 12 `text` at (15, 15); `Switch` right-aligned at x 999.
  - *Slider row*, 62 tall: label at (15, 13); value ("33 px") Regular 11 `textSecondary` right-aligned to x 1039; track at (15, 42), 1024 × 4, radius 2, `Theme.raised`; fill `accent`; knob 14 px `Theme.knob`. Dragging updates `Config` continuously.
  - *Choice row*: segmented chips (see "Layout" below).

## Pages

### Bar & Island
Group "Island": Notch mode (toggle), Bar height (20–48 px), Collapsed width (60–200), Expanded height (90–200), Gap from screen edge (0–30), Inner padding (0–8), Corner radius (0–24), Corner radius (expanded) (12–40), Status circle (toggle), Album art circle while a player is open (toggle), Stage lift on hover (0–16).
Group "Game mode": Bar height (32–64), Cluster gap (80–400).

### Clock & Date
24-hour clock, leading zero, show seconds in the hover clock, week starts on (Sun/Mon), Sundays in red.

### Appearance
Theme (opens the theme picker inline as a grid), media tint strength (0–60%, default 30%). Wallpaper and terminal colors get their own page in Phase 13 (below).

### Motion
Three spring editors (Island, Panel, Fade). Each shows Qt `spring`/`damping` sliders, the equivalent physical stiffness/damping and damping ratio ζ, and a **live preview**: a small island that morphs back and forth every 1.5 s using the edited spring. Plus "Reduce motion" (toggle) and "Reset to defaults".

### Launcher
Max results (4–10), show descriptions, calculator (toggle), clear launch history.

### Notifications
Toast duration (2–10 s), Focus mode (= DND), show on lock screen (toggle), per-app mute list (apps seen so far).

### Control Center — the layout editor
This page is the walkthrough's centerpiece: a drag-and-drop editor inspired by Android 16 / iOS / One UI quick settings.

- Header: "Control Center", "Arrange, resize, add and remove the controls."
- "Layout" label (Regular 10.5 `textMuted`) at y 213, then a row at y 239:
  - **Columns** segmented control: pill 117 × 27, `Theme.control`, chips 5 6 7 8 9 (Medium 11); the active chip is a 20 px `accent` circle with Bold 11 `onAccent` text. The active circle slides with the `panel` spring.
  - Buttons **Tidy**, **Undo**, **Reset**: pills 27 tall, radius 13.5, `Theme.control`, SemiBold 12.
  - Hint right-aligned: "Drag to move · corner to resize · right-click for sizes" Regular 10.5 `textMuted`.
- **Live preview** at (529, 276) relative to the window (centered in the content column): the real CC grid at 1:1, rendered by the same components as the island, plus one extra row of **empty slots** (60 × 60 circles, `Qt.alpha("#FFFFFF", 0.04)`) to drop into.
- **Editing interactions**:
  - *Select*: click → 1 px `accent` outline; a 16 px `danger` remove badge (with `remove` icon) at the item's top-left corner.
  - *Move*: drag picks the item up. It becomes a compact "drag chip" (e.g. "Night Light", 88 × 23 pill, `Theme.raised`) under the cursor while the other items reflow around the target cell with the `panel` spring.
  - *Resize*: drag the bottom-right corner; snaps to whole cells; only sizes the control supports (`05-control-center.md` → Layout model). Labels hide as tiles shrink.
  - *Right-click*: a menu of allowed sizes ("1×1", "3×1", "7×1", "1×3"…).
  - If a drop doesn't fit, show "Doesn't fit here" (Regular 10.5 `danger`) next to the cursor and spring the item back.
  - **Tidy** compacts everything up/left without changing order. **Undo** pops a 20-step history. **Reset** restores the default layout.
- "Add a control" (Regular 10.5 `textMuted`) at y 844, then a row of add-chips: pill 33 tall, radius 16.5, `Theme.control`, icon + name SemiBold 12.5 + size hint Regular 10.5 `textMuted` (e.g. "Now Playing 3×2"). Drag a chip into the grid or click it to drop it into the first free spot. Only controls not already placed are listed.
- Footer hint at y 914: "Drag a control to move it, drag its corner to resize, or drop it outside the grid to remove it." Regular 10.5 `textMuted`.
- Changing the column count re-flows the layout. Items wider than the new count clamp to the column count.

Implement the grid logic in `GridLayoutModel.qml` as pure functions (`canPlace(item, x, y)`, `reflow(items, moving, target)`, `tidy(items)`), separate from the UI. They're the easiest place for bugs, and they can be checked with a tiny headless `qml6` script.

### Lock Screen
Blur radius (0–96), dim (0–60%), show notifications count, clock size (100–200).

### System
Startup (enable/disable the systemd unit, via `systemctl --user enable/disable simple-bar.service` only; never start, stop or restart it), terminal used for btop/tlp-stat (`system.terminal`), reload shell (`Quickshell.reload(false)`), open the config folder, version info.

### Extras pages (Phases 13–17, `10-extras.md`)

Same page anatomy and row types. Add each to the sidebar in its phase, after "System" in this order:

- **Wallpaper** (13–14): wallpaper folder (folder picker), transition (dropdown incl. Random), transition length (0.3–3 s), slideshow (Off/5/15/30/60 min), wallpaper theme mode (Pitch black / Tinted), group "Terminals": Kitty (toggle), Foot (toggle), opacity (0.5–1.0), background (Black / Theme). Group "Wallhaven": API key (masked field), content (SFW / SFW + Sketchy), fit my screens (toggle).
- **Clipboard** (15): auto-paste (toggle), show images (toggle), items shown (20–500), Clear history (button, confirm), Clear pins (button, confirm).
- **Power & Battery** (16): automatic profiles (toggle), power saver at (20–80%), group "Idle": lock after (Never/1/2/5/10/15/30 min), screen off after (same list), group "Caffeine": also block suspend (toggle), keep awake while media plays (toggle), keep awake in game mode (toggle).
- **Weather** (17): location (search field with result list), units (°C / °F), show in calendar / hover clock / lock screen (toggles).
- **System monitor** (17): temperature sensor (dropdown of detected sensors + Auto), warning temperature (70–100°C).
