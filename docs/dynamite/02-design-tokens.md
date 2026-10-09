# 02 — Design tokens

All values are at 1× scale on a 1920×1080 output. In Figma they live on **Foundations & Components** (color variables in the "Dynamite Theme" collection, mode "Horizon Mint").

## Colors (`theme/Theme.qml`, default theme "Horizon Mint")

`Theme` loads the active theme JSON from `themes/<Config.appearance.theme>.json` with `FileView` + `JsonAdapter` and exposes each key as a `color` property. Switching theme = changing `Config.appearance.theme`; every binding updates live.

| Token | Hex | Used for |
|---|---|---|
| `accent` | `#49E3AF` | active toggles, progress fills, today, primary buttons, selection bar |
| `accentContainer` | `#205543` | accent-tinted containers (rare) |
| `onAccent` | `#0B1A14` | text/icons on accent fills |
| `island` | `#000000` | every island background, game bar |
| `panel` | `#181614` | CC tiles/cards, power actions, polkit message box |
| `subpage` | `#1F1D1B` | inner card of CC sub-pages |
| `card` | `#262220` | rows inside sub-pages, notification items, "more" buttons |
| `chip` | `#322E2B` | inactive scale chips, device icon backgrounds |
| `raised` | `#2A2623` | off-state icon circles, back buttons, Cancel button |
| `track` | `#0D0B0A` | slider tracks inside cards |
| `window` | `#0A0806` | settings window background |
| `sidebar` | `#070707` | settings sidebar |
| `group` | `#141110` | settings header card and setting groups |
| `field` | `#1C1916` | settings search field |
| `control` | `#1A1816` | small round buttons: calendar prev/next, settings back/forward, layout chips, Tidy/Undo/Reset |
| `switchOff` | `#3B3734` | switch track when off |
| `knob` | `#F2EFEA` | slider knobs in settings |
| `text` | `#EDE7DD` | primary text, battery ring |
| `textSecondary` | `#A39B91` | subtitles, values |
| `textMuted` | `#6B655E` | section labels, placeholders, weekday headers |
| `danger` | `#E5534B` | Sundays, remove badges, destructive |

Derived colors (compute in `Theme`, never hard-code):

| Name | Formula |
|---|---|
| `trackOnIsland` | `Qt.alpha("#FFFFFF", 0.14)` — progress/OSD tracks drawn directly on black |
| `divider` | `Qt.alpha("#FFFFFF", 0.07)` |
| `ghostButton` | `Qt.alpha("#FFFFFF", 0.08)` — media play button |
| `batteryTrack` | `Qt.alpha(text, 0.16)` |
| `mediaTint` | `Qt.alpha(accent, 0.30)` |
| `mediaShade` | `Qt.alpha(Qt.rgba(accent.r*0.12, accent.g*0.12, accent.b*0.12, 1), 0.55)` (≈ `#0A1A15` for Horizon Mint) |
| `mix(a, b, t)` | helper: `Qt.rgba(a.r+(b.r-a.r)*t, …)` — used to animate colors with springs (see `03-motion.md`) |

### Other themes

The theme picker shows 19 themes (the screenshot shows `everforest`, `gruvbox`, `gruvbox-material`, `horizon`, `industrial`, position 8/19). Create one JSON per theme with the same keys. For named community palettes (Everforest, Gruvbox, Catppuccin, Tokyo Night, Nord, Rosé Pine, Kanagawa…), map their background ramp darkest→lightest onto `island`/`sidebar` → `window` → `track` → `panel` → `subpage` → `card` → `raised` → `chip`, their foreground onto `text`/`textSecondary`/`textMuted`, and their signature color onto `accent`. Keep `island` pure black in every theme; that's what makes the islands read as hardware.

A `wallpaper` theme generated from the current wallpaper is added later (Phase 13, `10-extras.md` §2). It lives in `~/.local/state/dynamite/themes/`, so `Theme` must look there after `themes/`.

Theme JSON shape:

```json
{
  "name": "horizon",
  "label": "Horizon",
  "accent": "#49E3AF", "accentContainer": "#205543", "onAccent": "#0B1A14",
  "island": "#000000", "panel": "#181614", "subpage": "#1F1D1B", "card": "#262220",
  "chip": "#322E2B", "raised": "#2A2623", "track": "#0D0B0A", "window": "#0A0806",
  "sidebar": "#070707", "group": "#141110", "field": "#1C1916", "control": "#1A1816",
  "switchOff": "#3B3734", "knob": "#F2EFEA", "text": "#EDE7DD", "textSecondary": "#A39B91",
  "textMuted": "#6B655E", "danger": "#E5534B",
  "preview": ["#49E3AF", "#181614", "#EDE7DD", "#E5534B"]
}
```

## Typography

Install `inter-font` (`sudo pacman -S inter-font`); JetBrainsMono Nerd Font is already installed. Inter weights map to Qt as Regular=400, Medium=500, SemiBold=600 (`Font.DemiBold`), Bold=700.

| Role | Family / weight / size | Color |
|---|---|---|
| Collapsed island time, game-bar time | Inter SemiBold 15 | `text` |
| Hover clock time | Inter SemiBold 22 | `text` |
| Lock time | Inter SemiBold 150 | `text` |
| Lock date | Inter Medium 24 | `text` |
| Media title | Inter SemiBold 17 | `text` |
| Media artist | Inter Regular 13 | `text` @ 72% |
| Media album / player | Inter Regular 11.5 | `text` @ 38% |
| Media times | Inter Medium 10.5 | `text` @ 70% / 50% |
| Sub-page title | Inter SemiBold 15 | `text` |
| Tile title / launcher result / device name (large) | Inter SemiBold 14 | `text` |
| Card title, device name, calendar month | Inter SemiBold 13 | `text` |
| Body (polkit message, toast summary is **Bold** 13) | Inter Regular 13 | `text` |
| Caption (subtitles, values, %) | Inter Regular/Medium 10.5 | `textSecondary` |
| Section label ("Saved", "Nearby", "Output") | Inter Regular 10.5 | `textMuted` |
| Weekday letters | Inter Medium 9.5–10 | `textMuted` |
| Power action label | Inter SemiBold 11.5 | `text` |
| Settings page title | Inter SemiBold 18 | `text` |
| Settings nav item | Inter Medium 12.5 | `text` |
| Settings row label / value | Inter Medium 12 / Regular 11 | `text` / `textSecondary` |
| Terminal / code | JetBrainsMono Nerd Font 16 | — |

Put these in `Theme` as `font` objects (e.g. `Theme.fonts.tileTitle`) so components never set `font.pixelSize` by hand.

## Metrics (`theme/Metrics.qml`)

Design constants (things the user can't change in settings):

| Token | Value | Notes |
|---|---|---|
| `windowHeight` | 780 | island layer surface height (tallest panel 18 + 717 + shadow) |
| `collapsedGap` | 10 | horizontal gap between the three collapsed islands |
| `expandedGap` | 18.5 | gap between an expanded center island and the side circles |
| `mediaGap` | 15 | gap between the expanded media island's right edge and the center pill |
| `circle` | 33 | album/status circle diameter |
| `pillRadiusThreshold` | 67 | islands ≤ 67 px tall are full pills (`radius = height/2`), taller use `Config.island.radiusExpanded` (31) |
| `panelPad` | 14 | inner padding of CC / media / power islands |
| `ccCell` | 60 | control-center grid cell |
| `ccGap` | 11 | grid gap |
| `ccWidth` | 514 | 14 + 7×60 + 6×11 + 14 |
| `subpageInsetX` / `subpageInsetY` | 22 / 20 | inner card inset in CC sub-pages |
| `subpageWidth` | 470 | |
| `rowRadius` | 14 | device rows, notification items |
| `cardRadius` | 20 | CC slider cards, media tinted card |
| `subpageRadius` | 22 | |
| `monitorCardRadius` | 16 | display cards, power actions |
| `ringWidth` | 2.3 | battery ring stroke |
| `iconSm` / `iconMd` | 15 / 17 | |

### Shadows

Every expanded island has a drop shadow: offset (0, 6), blur 18, black at 32% opacity. Use `MultiEffect { shadowEnabled: true; shadowVerticalOffset: 6; blurMax: 36; shadowBlur: 0.5; shadowColor: "#52000000" }` on the island item. Collapsed islands have no visible shadow (fade the shadow opacity with the island's expansion progress).

### Blur

- Lock screen wallpaper: blur radius 48, then a dim layer (black 25%).
- Media card album background: the album art scaled to cover, blur radius 70.

Use `MultiEffect { blurEnabled: true; blurMax: 64; blur: 1.0 }`; stack two passes if one isn't soft enough.

## Icons

Use the installed **Material Symbols Rounded** variable font via a tiny `components/Icon.qml`:

```qml
import QtQuick
import qs.theme

Text {
    property string name
    property real size: 15
    property bool filled: false
    text: name
    color: Theme.text
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 500, "opsz": 20 })
    renderType: Text.NativeRendering
}
```

Names: `wifi`, `wifi_off`, `bluetooth`, `dark_mode` (night light), `lock`, `sports_esports` (game mode), `do_not_disturb_on` (focus), `volume_up`, `light_mode`, `chevron_left`, `chevron_right`, `skip_previous`, `play_arrow`, `pause`, `skip_next`, `power_settings_new`, `restart_alt`, `logout`, `bedtime` (suspend), `search`, `headphones`, `desktop_windows`, `mic`, `settings`, `add`, `remove`, `person`. Extras add: `wallpaper`, `image`, `content_paste`, `push_pin`, `link`, `keyboard`, `bolt`, `balance`, `eco`, `battery_full`, `coffee`, `memory`, `thermostat`, `sunny`, `clear_night`, `partly_cloudy_day`, `partly_cloudy_night`, `cloud`, `foggy`, `rainy`, `weather_snowy`, `thunderstorm`, `open_in_full`, `close`, `language`, `circle`.

The Figma file uses Lucide line icons; Material Symbols Rounded at weight 500 is the closest installed match. Small glyph differences are acceptable.

## User settings (`config/Config.qml`)

Stored in `~/.config/dynamite/settings.json` via `FileView { path; watchChanges: true; onAdapterUpdated: writeAdapter() }` + `JsonAdapter` with nested `JsonObject`s. Defaults below are the values shown in the original settings screens.

```text
island.notchMode            false   attach the center island to the top edge (y=0, flat top corners)
island.barHeight            33      collapsed island height
island.collapsedWidth       96
island.expandedHeight       125     clock hover target height incl. stage lift (measured island: 116 + 7 lift ≈ 123)
island.gap                  11      gap from the screen's top edge
island.innerPadding         3       padding inside collapsed circles (battery ring inset)
island.radius               20      collapsed radius (clamped to height/2, so 16.5 at 33 px)
island.radiusExpanded       31
island.statusCircle         true
island.albumCircleWhilePlaying true  only show the album circle while an MPRIS player exists
island.stageLift            7       expanded islands sit this much lower (y = gap + lift = 18)
gameMode.barHeight          47
gameMode.clusterGap         173     see 05-control-center.md → Game mode
motion.*                            spring tokens, see 03-motion.md
appearance.theme            "horizon"
appearance.wallpaper        ""      path; reuse the legacy config's wallpaper on first run
clock.use24h                true    island shows "00:47"; lock screen shows "0:47"
launcher.maxResults         6
notifications.toastSeconds  4
notifications.dnd           false   the CC "Focus" tile
controlCenter.columns       7       5–9
controlCenter.items         [...]   see 05-control-center.md → Layout model
display.nightLight          false
display.nightLightTemp      3700
lock.blur                   48
```

Keys for the extras (`10-extras.md`), added in Phases 13–17. Values marked "legacy" are imported once from `../config.json`:

```text
wallpaper.dir               "~/Pictures/Wallpapers"   legacy wallpaper_dir
wallpaper.current           {}      { "<output>": path, "*": path }; legacy wallpaper → "*"
wallpaper.transition        "random"  random | fade | grow | wipe | wave | outer | left | right | top | bottom
wallpaper.transitionSeconds 1.2
wallpaper.slideshowMinutes  0       0 = off
appearance.wallpaperMode    "pitch_black"   pitch_black | tinted (legacy theme_mode)
appearance.wallpaperAccent  ""      chosen swatch for the wallpaper theme
terminal.kitty              true
terminal.foot               true
terminal.opacity            0.8     legacy terminal_opacity
terminal.background         "black" black | theme
wallhaven.apiKey            ""
wallhaven.purity            "100"   SFW
wallhaven.categories        "110"   general + anime (legacy default)
wallhaven.fitScreen         true
clipboard.autoPaste         true
clipboard.showImages        true
clipboard.maxItems          100
power.auto                  true
power.saverAt               50
power.hysteresis            5
idle.lockAfter              300     seconds, 0 = never
idle.screenOffAfter         600
caffeine.until              0       epoch ms; -1 = until off; 0 = off
caffeine.blockSleep         false
caffeine.whilePlaying       false
caffeine.inGameMode         false
sysmon.tempSensor           "auto"
sysmon.warnTemp             90
weather.lat / weather.lon   null    legacy weather_lat / weather_lon
weather.place               ""
weather.units               "celsius"
weather.inCalendar          true
weather.inHoverClock        false
weather.onLockScreen        false
system.terminal             "kitty" used for btop / tlp-stat
```
