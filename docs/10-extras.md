# 10 — Extras: legacy features, rebuilt

Dynamite fully replaces simple-bar. The features below come from simple-bar, are not in the Figma design, and get rebuilt **after the core shell works** (Phases 13–17 in `09-phases.md`). Each section says what the old one did, what was wrong with it, and how the new one works.

Rules for everything in this file:

- **No new visual language.** There are no Figma frames for these, so build them only from existing patterns: launcher rows (`06-overlays.md` → Launcher), the theme-picker carousel (→ Theme picker), CC tiles/toggles and the sub-page frame (`05-control-center.md`), settings rows (`07-settings.md`). Same tokens, same springs.
- **No Python on the hot path.** Read `/proc`, `/sys` and JSON in QML (`FileView`, `XMLHttpRequest`, `Process`). Python is allowed only for image work (Pillow), in `dynamite/scripts/`, run asynchronously.
- **Never build shell strings.** Every `Process.command` is an argv array. The legacy code used `shell=True` with interpolated IDs.
- **Dynamite must not import, call or read anything outside `dynamite/`**, except a one-time settings import from the legacy `../config.json` (see "Migration"). The legacy files are deleted in Phase 18.
- Screenshot every new mode with `dev/shot.sh` and include it in the phase report, since there's no reference to diff against.

Dropped on purpose: simple-bar's four "bar workspaces" and their timeout (the islands replace them) and the notification bell (the CC's notifications card replaces it).

## Contents

| # | Feature | Where it lives in Dynamite | Phase |
|---|---|---|---|
| 1 | Wallpapers + random awww transitions | island mode `wallpapers` (center island), Settings → Wallpaper | 13 |
| 2 | Theme generated from the wallpaper | a `wallpaper` entry in the theme picker | 13 |
| 3 | Terminal colors (Kitty/Foot) + opacity | background exporter on every theme change | 13 |
| 4 | Wallhaven browser | "Online" tab of the `wallpapers` mode | 14 |
| 5 | Clipboard history | island mode `clipboard` | 15 |
| 6 | Keybinding cheatsheet | island mode `keybinds` | 15 |
| 7 | Power profiles (TLP auto-switching) | CC control `power` + CC page `battery` | 16 |
| 8 | Caffeine (+ idle locking) | CC control `caffeine`; `IdleMonitor` in the shell | 16 |
| 9 | System resources | CC control `system` + CC page `system` | 17 |
| 10 | Weather | strip in the calendar (+ optional hover clock / lock screen) | 17 |
| 11 | Focused-app badge → window menu | island mode `window` (right-click the center island) | 17 |

New island modes: `wallpapers`, `clipboard`, `keybinds`, `window`. All four are **center-island, interactive, keyboard-exclusive** modes: add them to `interactive` and `wantsKeyboard` in `state/Island.qml` and to the `Exclusive` focus list. New `ccPage` values: `battery`, `system`.

---

## 1. Wallpapers

**Old:** `theme.py` listed `wallpaper_dir`, made PIL thumbnails, applied with `awww img` and a random transition (wipe/fade/grow/wave/outer/left/right/top/bottom, 1.2 s, 60 fps), saved the path in `config.json`, and the `awww-daemon.service` restored it at login through `ExecStartPost=theme.py init`.

**Problems:** one wallpaper for all outputs; 60 fps hard-coded (your panel is 144 Hz); every list call re-scanned and re-thumbnailed synchronously in Python; the restore path depends on a Python script inside the repo.

**New — `services/Wallpaper.qml` + `island/panels/WallpaperPicker.qml`:**

- **Mode `wallpapers`**, center island **802 × 262** (theme-picker width). Same anatomy as the theme picker: search row at y 21 (`search` icon, "Search wallpapers...", counter "12/48" right-aligned), then a **tab row** at y 56: two chips "Local" / "Online" (26 tall, radius 13, active `accent`/`onAccent`, inactive `chip`/`text`, the active chip slides with the `panel` spring), then the carousel at y 92: **16:9 cards 185 × 104**, 9 px gaps, selected card centered with a 2 px `accent` outline and the file name (Medium 10) under it. Footer hint at y 236: "Enter apply · Shift+Enter this display only · Space preview" Regular 9.5 `textMuted`.
- **Listing:** `FolderListModel` (`Qt.labs.folderlistmodel`) on `Config.wallpaper.dir`, `nameFilters: ["*.jpg","*.jpeg","*.png","*.webp","*.bmp"]`, sorted by modified time (newest first). Thumbnails are plain `Image`s with `sourceSize: Qt.size(370, 208)`, `asynchronous: true`, `cache: true` (Qt decodes JPEGs downscaled, so no thumbnail cache is needed).
- **Apply:** `awww img <path> -o <output> --transition-type <t> --transition-duration <Config.wallpaper.transitionSeconds> --transition-fps <that output's refresh rate from Niri>`. Enter applies to **all outputs**, Shift+Enter to the focused output only. `transition: "random"` picks from the same set as the old script (keep its angle/position choices). Improvement: when applied from the picker, `grow` uses `--transition-pos` at the island's position on screen, so the new wallpaper visibly grows out of the island.
- **Preview:** Space applies the selected wallpaper temporarily with a short fade; Esc restores the previous one; Enter keeps it.
- **Right-click a card:** Set on all displays, Set on this display, Use for theme (applies + switches the theme to `wallpaper`), Move to trash (`gio trash <path>`, confirm).
- **Slideshow (new):** `Config.wallpaper.slideshowMinutes` (0 = off). Shuffle without repeats until every file has been shown.
- **Persistence:** `Config.wallpaper.current` is a map `{ "<output>": "<path>", "*": "<path>" }`. On startup the service waits for `awww query` to succeed (retry every 200 ms, up to 5 s) and restores each output with a 1 s fade. This replaces the `ExecStartPost` line; the new `systemd/awww-daemon.service` only runs the daemon.
- The lock screen background (`06-overlays.md`) reads the focused output's entry.
- IPC: `wallpaper.set(path: string)`, `wallpaper.random()`, `wallpaper.next()`, `wallpaper.prev()`.

Accept: picker opens with the right size and springs; cards load without blocking typing; apply to one output vs all works on a 2-output setup (or two nested outputs); transition fps matches the output's refresh; slideshow rotates; wallpaper survives a nested-session restart without Python.

## 2. Theme from the wallpaper

**Old:** `extract_palette()` (Pillow) produced a simple-bar token set + 6 swatches, written to `colors.json` **inside the repo**, plus `~/.cache/simple-bar/colors.{json,css}`; `set-accent` and `set-theme-mode` (pitch black / tinted) re-ran it.

**Problems:** token set doesn't match Dynamite's; no contrast checks (accent text on dark cards could be unreadable); output lived in the git tree.

**New — `dynamite/scripts/palette.py` + the `wallpaper` theme:**

- Port the extraction from `../scripts/theme.py` into `dynamite/scripts/palette.py` (copy, then adapt; don't import the legacy file). CLI: `palette.py <image> --mode pitch_black|tinted [--accent '#RRGGBB']` → prints a **full Dynamite theme JSON** (every key from `02-design-tokens.md`, `"name": "wallpaper"`, `"label": "From wallpaper"`) plus a `"swatches"` array of 6 candidate accents.
- Write it to `~/.local/state/dynamite/themes/wallpaper.json` (never into the repo). `Theme` looks in `themes/` first, then in that state directory.
- **Ramp:** `island` stays `#000000`. `pitch_black` = the neutral ramp from Horizon with only `accent`/`accentContainer`/`onAccent` from the image. `tinted` = the ramp mixed 6–10% toward the dominant hue.
- **Contrast rules (new):** `onAccent` vs `accent` ≥ 4.5:1 (pick near-black or near-white), `accent` vs `panel` ≥ 3:1 (lighten/darken the accent in HSL until it passes), `text` vs `panel` ≥ 7:1. Reject swatches that can't pass.
- **Theme picker:** the `wallpaper` card shows the 6 swatches under its preview; ←/→ on that card's swatch row (Tab to enter it) re-runs with `--accent`. `Config.appearance.wallpaperAccent` remembers the choice.
- Re-run automatically after a wallpaper change **only when** `Config.appearance.theme === "wallpaper"`. Run with `Process`, debounce 300 ms, and swap the theme only when the new JSON is complete (write to a temp file, then rename).
- Also export `~/.cache/dynamite/colors.json` and `colors.css` (`--dyn-<token>` variables) for other apps, like the old `--sb-*` file.

Accept: switching wallpaper with the `wallpaper` theme active recolors the shell with the `fade` crossfade within ~1 s; contrast rules hold for 10 varied wallpapers (write a tiny check that loads each output JSON and asserts the ratios).

## 3. Terminal colors

**Old:** on every wallpaper change, wrote `~/.config/kitty/current-theme.conf` (with `background_opacity` from `terminal_opacity`) and `~/.config/foot/colors.ini`, ANSI colors chosen by binning swatch hues, then `pkill -USR1 kitty`.

**Problems:** only followed the wallpaper theme (picking "Gruvbox" didn't recolor terminals); ANSI colors had no contrast guarantee; string-templated inside Python.

**New — `services/TerminalThemes.qml` + `dynamite/templates/`:**

- Trigger on **any** theme change (debounced 300 ms), not just wallpaper changes.
- Templates in `dynamite/templates/kitty.conf` and `foot.ini` with `{{token}}` placeholders, filled in QML and written with `FileView.setText`. Only write a terminal's file if its config directory exists and `Config.terminal.<name>` is on.
- ANSI 0–15: derive from the theme. `color4`/`12` = accent, `color0`/`8` = `card`/`chip`, `color7`/`15` = `textSecondary`/`text`; red/green/yellow/blue/magenta/cyan from the theme's optional `"ansi"` object if present, else the old hue-binning over the swatches, else defaults (keep the old Catppuccin fallbacks). Every ANSI color must reach 3:1 against the terminal background; adjust lightness until it does.
- Background: `Theme.island` (pure black) or `Theme.window`, by `Config.terminal.background` (`"black"`/`"theme"`). Opacity: `Config.terminal.opacity` (default from the legacy `terminal_opacity`, 0.8).
- Reload: Kitty → `pkill -USR1 kitty` (argv form). Foot → new windows pick it up; if the installed `foot --version` supports live reload, use it, otherwise say so in the settings row.
- Optional extra templates (Ghostty, Alacritty) only if their config dirs exist; off by default.

Accept: switching between three themes recolors open Kitty windows each time; generated files diff cleanly against the template; disabling a terminal stops writing its file.

## 4. Wallhaven browser

**Old:** a separate panel with keyword search, sorting presets (Toplist/Hot/Latest/Random), 12 per page, Python `urllib`, download into the wallpaper dir and apply.

**Problems:** manual pagination; results not filtered for your screens; applying downloaded a full image you might not keep; Python on every page.

**New — the "Online" tab of `wallpapers`:**

- Requests from QML with `XMLHttpRequest` to `https://wallhaven.cc/api/v1/search` (`sorting`, `q`, `page`, `purity`, `categories`, `ratios`, `atleast`). Debounce typing 500 ms; stay under the API limit (45 req/min) with a simple request queue.
- **Sorting chips** under the search row: Toplist · Hot · Latest · Random (same chip style as the tabs).
- **Infinite scroll:** when the selection is within 6 cards of the end, fetch the next page and append. No page numbers.
- **Fit your screens (new):** `atleast=<focused output's WxH>` and `ratios=` its aspect ratio, toggled by `Config.wallhaven.fitScreen` (default on).
- **Match theme (new):** a toggle that adds `colors=<hex>` with the closest of Wallhaven's allowed color values to `Theme.accent`.
- Thumbnails load straight from `thumbs.large` URLs (`Image` with `asynchronous: true`).
- **Space = preview:** download to `~/.cache/dynamite/wallhaven/<id>.<ext>` with `curl -fL --max-time 30 -o <file> <url>` (argv), show a progress ring on the card, then apply temporarily (Esc reverts). **Enter = keep:** move the file into `Config.wallpaper.dir` as `wallhaven-<id>.<ext>` and apply it permanently. Clear cached previews older than a day on startup.
- `Config.wallhaven.apiKey` (optional, Settings → Wallpaper) is sent as `X-API-Key`; purity stays SFW (`100`) unless the user changes it in settings.
- Offline/errors: one-line message in the carousel area ("Wallhaven is unreachable"), retry button.

Accept: search, sorting, infinite scroll, preview → revert, preview → keep (file appears in the Local tab without a reload), errors handled with the network off.

## 5. Clipboard history

**Old:** Python called `cliphist list`, decoded **every** image to `/tmp` on each open, showed a list; selecting copied and auto-pasted with `wtype` (Ctrl+V); delete used a `shell=True` pipe; IPC `clipboard toggle` on Mod+V.

**Problems:** slow with many images; no search filters, no pins, no preview of long text; command-injection-prone delete; password-manager copies were stored.

**New — `services/Clipboard.qml` + `island/panels/ClipboardPanel.qml` (mode `clipboard`):**

- **Watchers already exist** on this machine: `cliphist.service` and `cliphist-images.service` (user units, started from Niri). Dynamite doesn't start its own; Phase 18 only checks they're enabled. Make sure they store with `cliphist store` so cliphist's handling of `CLIPBOARD_STATE=sensitive` (password managers) applies; if the installed cliphist doesn't support it, note that in the report.
- **Layout = launcher**: 514 wide, search row, divider, rows of 47 at pitch 46, max 6 visible, the island height follows `83 + 47·n` with the `panel` spring; the selection bar slides.
  - Text row: `content_paste` icon in a 28 px `chip` circle, first line SemiBold 13 (elided), "12 lines · 2 min ago" Regular 10.5 `textSecondary`.
  - Image row: a 28 × 28 rounded thumbnail instead of the icon, "Image · 1920×1080 · 240 KB".
  - Link row: `link` icon, the URL's host in SemiBold.
  - **Selected text row expands** to show up to 6 lines (row height springs with `panel`); a selected image row grows to a 160 px tall preview.
- **Filter chips** under the search row: All · Text · Images · Links · Pinned. Typing fuzzy-filters text entries.
- **Pins (new):** Ctrl+P pins/unpins. Pinned items are stored with their content in `~/.local/share/dynamite/clipboard-pins.json` (so `cliphist wipe` can't remove them) and listed first with a `push_pin` icon.
- **Lazy images:** decode only rows that become visible: `cliphist decode <id>` → `~/.cache/dynamite/clip/<id>.png` (Process with stdout to file), cached by id.
- **Keys:** Enter = copy + paste (close the island, wait 120 ms for focus to return, then `wtype -M ctrl -k v -m ctrl`), Shift+Enter = copy only, Delete = remove, Ctrl+Shift+Delete = clear all (confirm via the row label crossfading to "Clear all? Enter"). Copy images with `wl-copy --type image/png`.
- **Delete correctly:** `cliphist delete` reads the original `list` line on stdin; send it through `Process.write()`, never through a shell.
- Settings → Clipboard: auto-paste (on), show images (on), max items shown (100), clear history, clear pins.
- IPC: `clipboard.toggle()` (compat target, see `01-architecture.md`).

Accept: opens in < 150 ms with 500 entries including 50 images; search/filters/pins/delete/clear work; paste lands in the previously focused window; no `sh -c` anywhere in the clipboard code.

## 6. Keybinding cheatsheet

**Old:** a regex scan of `config.kdl` + `config.d/*.kdl` with heuristic categories, keycap chips, search; IPC `cheatsheet toggle` on Mod+Slash.

**Problems:** regexes miss multi-line blocks, `/-` slash-dash comments and nested `include`s (your config uses `include "config.d/…"` and `include "../user-hot-rules/…"`); no way to run a bind; duplicates silently ignored.

**New — `services/Keybinds.qml` (+ `services/kdl.js`) + `island/panels/KeybindsPanel.qml` (mode `keybinds`):**

- **Parser:** a small KDL tokenizer in `kdl.js` (strings, `//` and `/* */` comments, `/-` slash-dash, properties like `repeat=false`, `hotkey-overlay-title="…"`, `allow-when-locked=true`, children blocks). Start at `~/.config/niri/config.kdl`, follow `include` paths relative to the including file, and track which file each bind came from. Watch every visited file with `FileView { watchChanges: true }` and re-parse on change. Test it headlessly (`dev/kdl-test.qml`) against a copy of the real config.
- **Title:** `hotkey-overlay-title` if present; `hotkey-overlay-title=null` hides the bind. Otherwise derive one from the action (port the old `clean_action_title` rules: terminal, file manager, `qs … ipc call …` → the panel name, etc.).
- **Category:** the nearest preceding section comment (`// ══…` banner, as the old parser did), falling back to the old keyword mapping (Screenshots, Media & Audio, Workspaces, Windows & Navigation, Layout & Sizing, Shell & Panels, Apps & Launchers, Session & Power).
- **Layout:** launcher width 514, taller list (max 9 visible rows, pitch 46). Section headers (Regular 10.5 `textMuted`) stick to the top while scrolling. Each row: title SemiBold 13 at the left; keycaps at the right as chips (height 22, radius 6, `Theme.chip`, Medium 10.5, e.g. `Super` `Shift` `Q`, with `Mod` shown as `Super`).
- **Search** matches titles, actions and key names ("shift q" finds Mod+Shift+Q).
- **Run (new):** Enter performs the bind: niri actions via `niri msg action <action> <args…>`, `spawn`/`spawn-sh` via `niri msg action spawn -- …`. Binds that only make sense with a focused window run after the island closes.
- **Conflicts (new):** if the same chord is bound in two files, mark both rows with a `danger` dot and the other file name in the subtitle.
- Dynamite's own binds get a small `circle` (island) glyph before the title.
- IPC: `cheatsheet.toggle()` (compat target).

Accept: every bind in the real config appears (compare the count against `niri`'s hotkey overlay); editing a `.kdl` file updates the list live; Enter runs `focus-column-right` and a `spawn`; a deliberately duplicated chord shows the conflict mark.

## 7. Power profiles (TLP auto-switching)

**Old:** `shell.qml` polled every 60 s and on UPower changes: plugged in → performance; on battery > 50% → balanced; ≤ 50% → power-saver; a manual choice set an override flag; changes went through `control.py sync-power-profile` (`tlpctl`, polling until tlp-pd confirmed) and were announced with `notify-send`. TLP drop-in `tlp/simple-bar.conf` (`TLP_AUTO_SWITCH=1`, `TLP_PROFILE_AC=PRF`, `TLP_PROFILE_BAT=BAL`).

**Problems:** **bug:** every battery-percentage change cleared the manual override, so a manual choice lasted at most a minute or two; polling; no hysteresis at the 50% line; Python round trip; toasts via `notify-send` instead of the shell.

**New — `services/PowerProfile.qml`, CC control `power`, CC page `battery`:**

- **Event-driven only:** react to `UPower.onBattery` and `UPower.displayDevice.percentage` changes; no timer.
- **Rules:** AC → `performance`. Battery → `balanced` above `Config.power.saverAt` (50); `power-saver` at or below it. **Hysteresis:** once in power-saver on battery, go back to balanced only above `saverAt + Config.power.hysteresis` (5), which only happens while charging.
- **Manual override** lasts until the **next plug/unplug event** (or until "Automatic" is switched back on), not until the next percentage tick.
- `tlpctl` via `Process` (argv): read with `tlpctl get`, set with `tlpctl performance|balanced|power-saver`, then verify by re-reading up to 10 × 250 ms (tlp-pd acknowledges before it publishes, as the old code noted). Hide everything if `tlpctl` is missing.
- Announce changes through the **island toast** ("Power saver · Battery at 50%"), not `notify-send`. Respect Focus mode.
- Game mode forces performance and restores automatic mode on exit (replaces the plain "restore previous profile" in `05-control-center.md`).
- **CC control `power`:** toggle 1×1 (icon `bolt` / `balance` / `eco` for the current profile; tap cycles) or tile 3×1 (title "Power", subtitle "Balanced · Auto"); the tile body opens the `battery` page. Not in the default layout; added from the editor.
- **CC page `battery`** (island 514 × 446, shared sub-page frame, header "Battery"):
  - Summary card (440 × 96, radius 16, `card`): big percentage SemiBold 28, state line Regular 10.5 ("Charging · full in 1 h 20 m" / "On battery · 4 h 10 m left"), discharge rate "9.8 W" and health "Health 92%" (`UPower.displayDevice` `changeRate`, `healthPercentage` when available).
  - Profile segmented control (440 × 40, radius 20, `control`): Performance · Balanced · Power saver; the active `accent` pill slides with the `panel` spring.
  - Row "Automatic" + switch; row "Power saver at" + slider 20–80%.
  - "Open TLP status" link → `niri msg action spawn -- <terminal> -e tlp-stat -s` (terminal from Settings → System, default `kitty`).
- **TLP drop-in:** copy `../tlp/simple-bar.conf` to `dynamite/tlp/simple-bar.conf` unchanged (same install path `/etc/tlp.d/90-simple-bar.conf`, needs sudo; print the command, never run sudo).

Accept: unplug/plug and simulated percentage changes (expose a dev-only `power.debugBattery(percent, onBattery)` IPC) follow the rules including hysteresis; a manual choice survives percentage changes and resets on plug/unplug; toasts appear in the island.

## 8. Caffeine and idle

**Old:** `systemd-inhibit --what=idle:sleep … sleep infinity` started from Python, detected with `pgrep`, stopped with `pkill`; a notify-send toast. Separately, locking was manual (`swaylock` on Mod+Alt+L); no idle daemon runs.

**Problems:** the inhibitor process could outlive the shell or be orphaned; no timer; nothing locks the screen when idle.

**New — `services/Idle.qml`, CC control `caffeine`:**

- **Idle handling in the shell (new):** `IdleMonitor` (`Quickshell.Wayland`, verified in 0.3.1) with `respectInhibitors: true`:
  - after `Config.idle.lockAfter` (300 s) → `Lock.lock()`;
  - after `Config.idle.screenOffAfter` (600 s) → `niri msg action power-off-monitors`.
  - Before sleep (lid close, suspend from elsewhere): run `swayidle -w before-sleep '<qs ipc -p … call lock lock>'` as a `Process` child of the shell (dies with it). That's the only use of swayidle; drop it if `Lock` can watch logind's `PrepareForSleep` another way.
- **Caffeine:** `IdleInhibitor { window: <island window>; enabled: Idle.caffeine }`. Wayland-native, so Niri and the `IdleMonitor`s above both respect it, and it can't outlive the shell.
  - "Also block suspend" (`Config.caffeine.blockSleep`, off): additionally run `systemd-inhibit --what=sleep:handle-lid-switch --who=dynamite --why=Caffeine sleep infinity` as a **child `Process`** (so it dies with the shell; this is the one deliberate exception to "spawn through Niri").
  - **Durations (new):** tap = until off; the tile's subtitle chip cycles 30 min → 1 h → 2 h → until off; the remaining time shows as the subtitle ("Caffeine · 42 min"). Stored as `Config.caffeine.until` (epoch ms, `-1` = until off, `0` = off) so it survives a shell reload.
  - **Auto (new, both off by default):** keep awake while an MPRIS player is playing; keep awake while game mode is on.
- **CC control `caffeine`:** toggle 1×1 (`coffee`) or tile 3×1 ("Caffeine" / "Off", "Until off", "42 min"). Not in the default layout.
- IPC: `caffeine.toggle()`, `caffeine.for(minutes: int)`.
- Settings → Power & Battery: lock after, screen off after, caffeine options.

Accept: with a 20 s test `lockAfter`, the nested session locks when idle and doesn't while caffeine is on; timed caffeine expires and the tile updates; reloading the shell keeps the remaining time.

## 9. System resources

**Old:** `control.py status` every few seconds: `top` for CPU %, `/proc/meminfo` for RAM/swap, CPU temp = **max of every** `thermal_zone*` (falling back to hwmon `temp1_input`), shown in "bar workspace 3" with a details popup.

**Problems:** spawning Python + `top` on a timer even when nothing was visible; max-of-all-zones mixes in Wi-Fi/NVMe/ACPI sensors (this laptop has `coretemp`, `acpitz` and `nvme`).

**New — `services/SysStats.qml`, CC control `system`, CC page `system`:**

- **Read files directly** with `FileView` + `reload()`: `/proc/stat` (CPU % from deltas, per core too), `/proc/meminfo` (RAM, swap), `/proc/loadavg`, hwmon temps.
- **Sensor choice:** prefer hwmon `coretemp` "Package id 0" (this machine), then `k10temp` Tctl/Tdie, then `zenpower`, then `acpitz`. List detected sensors in Settings → System monitor so the user can pick (`Config.sysmon.tempSensor`, `"auto"`).
- **Poll only while visible:** 1 s while the `system` page is open, 3 s while a `system` tile is visible in an open CC, otherwise stopped. Keep a 60-sample history per metric for sparklines.
- **CC control `system`:** tile 3×1 or 4×1 (three mini meters: CPU %, RAM %, temperature, each a 4 px tall bar with the value Medium 10.5) or slider-sized 7×1 (adds sparklines). Tile body opens the page.
- **CC page `system`** (island 514 × 600): CPU card (total %, sparkline, per-core bars), Memory card (RAM used/total, swap), Temperature card (value, sparkline, colored `danger` above `Config.sysmon.warnTemp` 90°C), then **Top processes** (5 rows, from `ps -eo pid,comm,%cpu,%mem --sort=-%cpu`, only while the page is open; each row has an "End" pill: SIGTERM with a confirm step). Footer button "Open btop" → terminal + `btop` via Niri spawn.
- Optional GPU line if `/sys/class/drm/card*/device/gpu_busy_percent` exists.
- **Heat warning (new):** temperature ≥ `warnTemp` for 10 s → one toast; re-arm after it drops 5°C below.

Accept: CPU% matches `top` within a few percent; temperature matches `sensors` Package id 0; no polling when the CC is closed (verify with `strace -c` or by logging reload counts).

## 10. Weather

**Old:** `control.py weather` → Open-Meteo current conditions (temp, WMO code, is_day), 15 min cache in `~/.cache/simple-bar/weather.json`, location from `config.json` or **IP geolocation over plain HTTP** (`ip-api.com`), shown in bar workspace 0.

**Problems:** IP geolocation over HTTP leaks your location and is often wrong; current conditions only; Python per refresh.

**New — `services/Weather.qml`:**

- `XMLHttpRequest` to `https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=temperature_2m,apparent_temperature,weather_code,is_day&hourly=temperature_2m,weather_code,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&forecast_days=5&timezone=auto` (+ `temperature_unit=fahrenheit` when set).
- **Location:** Settings → Weather has a search field using `https://geocoding-api.open-meteo.com/v1/search?name=<q>&count=5`; picking a result stores `lat`, `lon`, `place`. Migrate `weather_lat`/`weather_lon` from the legacy config on first run. No IP geolocation by default; an explicit "Detect approximately" button may use an HTTPS geo-IP service.
- Refresh every 15 min, on resume from suspend, and when the network reconnects. Cache the last response in `~/.cache/dynamite/weather.json` and show it with an "updated 2 h ago" note when offline.
- WMO code → Material Symbols: 0 `sunny`/`clear_night`, 1–2 `partly_cloudy_day`/`partly_cloudy_night`, 3 `cloud`, 45–48 `foggy`, 51–67 & 80–82 `rainy`, 71–77 & 85–86 `weather_snowy`, 95–99 `thunderstorm`.
- **Where it shows:**
  - **Calendar (default on):** the calendar island grows by 64 px (`panel` spring) and gets a weather strip at the bottom: current icon + temperature SemiBold 15 + description Regular 10.5 at the left, then 5 day columns (weekday Medium 9.5, icon 14 px, max/min Medium 10.5) centered on the column grid. Clicking the strip expands it into the next 12 hours (another `panel` spring step).
  - **Hover clock (default off):** `Config.weather.inHoverClock` adds "31° ☁" (icon + Medium 13) to the right of the time.
  - **Lock screen (default off):** under the date, same style as the date at 60% opacity.
- Units C/F in Settings → Weather.

Accept: correct data for the stored location; offline shows the cached value; the calendar grows/shrinks smoothly when weather is turned on/off.

## 11. Window menu (was: focused-app badge)

**Old:** the bar showed the focused app's name/icon; its context menu had hard-coded browser actions (`firefox --new-tab`, `brave-browser --incognito`, `google-chrome-stable …`), Toggle Fullscreen and Close Window via `niri msg action`.

**Problems:** browser actions hard-coded per browser; actions applied to whatever was focused when clicked (not necessarily the window you meant); no float/move/kill.

**New — `island/panels/WindowMenu.qml` (mode `window`):**

- **Open:** right-click the center island (any non-interactive mode) or IPC `island.toggle("window")`. Capture the focused window **at open time** from `Niri.focusedWindow` (`id`, `app_id`, `title`, `pid`, `workspace_id`, `is_floating`) and act on that id.
- **Header** (launcher width 514): app icon 36 px (`DesktopEntries.heuristicLookup(app_id)`, verified in 0.3.1), app name SemiBold 14, window title Regular 10.5 `textSecondary` elided, a chip "Workspace 2 · eDP-1" at the right.
- **Rows** (launcher row style, keyboard navigable):
  1. The app's own **desktop actions** first (`entry.actions`: e.g. "New Window", "New Private Window" from the browser's `.desktop` file); run each action's `command` through Niri spawn. This replaces the hard-coded browser list.
  2. Fullscreen (toggle), Maximize column, Float / Tile (label reflects `is_floating`).
  3. Move to workspace ▸: the row expands inline (`panel` spring) into the output's workspaces; Enter moves the window.
  4. Move to monitor ▸ (only with 2+ outputs).
  5. Close window (`danger` text).
  6. Force quit (`danger`, confirm step, `kill -9 <pid>`).
- Pass the window id to Niri wherever the action supports it (check `niri msg action <name> --help`; e.g. `close-window --id`, `fullscreen-window --id`, `toggle-window-floating --id`, `move-window-to-workspace --window-id`).
- **Game bar (new):** in game mode, show the focused app's icon (20 px) and title (Medium 12, elided at 360 px) at x 16 in the 47 px bar.

Accept: actions apply to the window that was focused when the menu opened, even if focus changes; desktop actions appear for Firefox/Chromium-family apps from their `.desktop` files; force quit asks first.

## Launcher parity (small, Phase 17)

Simple-bar's launcher also had: Flatpak apps and `~/Desktop/*.desktop` launchers, web-app recognition, categories, and the calculator.

- Flatpak: make sure `DesktopEntries` sees `/var/lib/flatpak/exports/share` and `~/.local/share/flatpak/exports/share` (they're in `XDG_DATA_DIRS` in a normal session; verify in the nested one too).
- `~/Desktop/*.desktop`: scan with `FolderListModel` and parse the few keys needed (`Name`, `Exec`, `Icon`, `Comment`).
- Web apps (Chromium `--app=` / `crx_` entries): show the site name and a small `language` glyph.
- Categories: Tab cycles a category filter shown as a chip in the search row (All · Development · Internet · Media · System · …).
- Calculator: already specified in `06-overlays.md`.
- **Prefixes (new):** typing `;` at the start switches to `clipboard`, `?` to `keybinds`, `!` to `window`.

## Migration from the legacy config

On first run (when `~/.config/dynamite/settings.json` lacks the key), read `../config.json` if it exists and import:

| Legacy key | Dynamite key |
|---|---|
| `wallpaper` | `wallpaper.current["*"]` |
| `wallpaper_dir` | `wallpaper.dir` |
| `theme_mode` | `appearance.wallpaperMode` |
| `terminal_opacity` | `terminal.opacity` |
| `weather_lat`, `weather_lon` | `weather.lat`, `weather.lon` |
| `weather_units` | `weather.units` |

`position` (top/bottom) and `bar_workspace_timeout` are not imported. After Phase 18 the legacy file no longer exists, and this code becomes a no-op; leave it in, it's harmless.
