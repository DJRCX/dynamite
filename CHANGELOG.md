# 📜 simple-bar — Development Log, Features, Bugs & Fixes

A comprehensive record of all features implemented, bugs investigated, root causes identified, and fixes applied to **simple-bar**.

---

## 📌 Table of Contents
1. [Overview & Architecture](#overview--architecture)
2. [Major Features Implemented](#major-features-implemented)
3. [Bugs Encountered & Fixes Applied](#bugs-encountered--fixes-applied)
4. [File Diffs & Changes Summary](#file-diffs--changes-summary)

---

## 1. Overview & Architecture

**simple-bar** is a floating dynamic status bar and quick-settings system for Wayland compositors (specifically **Niri**, **Hyprland**, and **Sway**), built using [Quickshell](https://quickshell.outfoxxed.me/) (Qt Quick/QML) and a Python asynchronous hardware bridge (`scripts/control.py`).

### Key Components:
* [`shell.qml`](shell.qml): Declarative layer-shell UI consisting of:
  * **Dynamic Center Pill**: Displays clock, date, workspace tracker, focused application title, or transient hardware OSDs.
  * **Status Balls**: Wi-Fi/Bluetooth ball (left) and Battery/Power ball (right) that smoothly emerge on hover.
  * **Modal Panels**: Quick Settings / Connectivity, Battery & Power, Calendar, Application Launcher, and Clipboard History.
* [`scripts/control.py`](scripts/control.py): Asynchronous IPC and hardware queries (`wpctl`, `brightnessctl`, `nmcli`, `bluetoothctl`, `cliphist`, system stats).
* [`config.json`](config.json): User configuration (bar rest position, themes, etc.).

---

## 2. Major Features Implemented

### 🎨 Wallpaper Management & Dynamic Theming Service
* **Zero-Dependency Python PIL Color Engine (`scripts/theme.py`)**:
  * Extracts dominant vibrant accents, secondary tones, and contrast-checked text tokens directly from the desktop wallpaper image.
  * Generates 6-color representative swatches for interactive accent customization in the UI.
  * Supports **Pitch Black + Wallpaper Accent** mode (preserves `#000000` pitch black background while tinting active elements) and **Vibrant Tinted Dark** mode (subtly tints panel surfaces and cards).
* **Randomized Animated Transitions via `awww`**:
  * Dynamic transition engine supporting `wipe` (random angles 30°–315°), `fade`, `grow` (random focal centers), `wave`, `outer`, and directional wipes.
  * Smooth 60fps rendering with 1.2s duration.
* **Wallhaven.cc Online Explorer with 12-Image Pagination**:
  * Direct integration with the Wallhaven API (`https://wallhaven.cc/api/v1/search`) without requiring API keys for public SFW wallpapers.
  * In-pill search box, category filters (`Toplist`, `Hot`, `Latest`, `Random`), and aspect ratio optimization (`16x9`, `16x10`).
  * **12-Image Pagination**: Translates UI pages to Wallhaven 24-item API responses (`api_page = ((ui_page - 1) // 2) + 1`), with local response caching and dynamic API pinging across boundaries.
  * Includes First (`󰁍󰁍`), Prev (`󰁍 Prev`), Page Indicator (`Page X of Y (12 / page)`), and Next (`Next 󰁔`) controls.
  * 1-Click apply flow: downloads full-res files into `~/Pictures/Wallpapers/`, applies them via `awww` with randomized transition, and extracts color palette immediately.
* **Live Dynamic Terminal Theming (Kitty & Foot)**:
  * Generates `~/.config/kitty/current-theme.conf` (included by `~/.config/kitty/kitty.conf`) and `~/.config/foot/colors.ini` automatically upon any theme or wallpaper change.
  * Maps full 16-color ANSI terminal palette harmonized with wallpaper swatches.
  * Sends `pkill -USR1 kitty` on update, live-reloading all running Kitty windows without closing sessions or tabs.
* **Persistent Autostart & Wallpaper Memory**:
  * Added `awww-daemon.service` user unit with `ExecStartPost` hook triggering `python3 scripts/theme.py init`.
  * Restores the last active wallpaper from `config.json` automatically on login, ensuring `awww-daemon` is always running and the desktop background is preserved across reboots.
  * Added to Niri's `config.d/50-startup.kdl` and enabled under `graphical-session.target`.
* **Instant Reactivity via `wm-stream` IPC**:
  * Background wallpaper monitor detects external wallpaper changes (via terminal or external script) within 2 seconds and emits `{"type": "theme", ...}` events over stdout.
  * Quickshell UI dynamically rebinds colors live with zero restart required.
* **Dedicated 560px Flush Flyout Panel (`wallpaperPanel`)**:
  * Segmented tabs for Local Library and Wallhaven Online.
  * Instant access via Workspace 1 status pill button (`󰸉`) and IPC handler (`qs ipc call wallpaper toggle`).

### 🚀 Integrated Application Launcher
* **Categorized App Drawer**: Displays applications categorized into `All`, `System`, `Development`, `Internet`, `Media`, `Office`, and `Utility`.
* **Full Keyboard Navigation**:
  * Arrow keys (`Down` / `Up`), `Tab`, and `Shift+Tab` smoothly cycle through matched apps.
  * `Return` launches the highlighted app and immediately closes the modal.
  * Auto-scrolling list view (`ListView.Contain`) ensures the active item always remains visible.
  * `Escape` or clicking outside dismisses the launcher.
* **Auto-Search Reset**: Search query, filter pills, and selection automatically reset upon every open/close cycle to prevent cached searches or empty views.

### 📋 Visual Clipboard History Manager
* **Dual-Format History**: Interacts with `cliphist` to manage both text snippets and image entries.
* **Image Thumbnails**: High-resolution image preview generation with dimensions (`1920x1080`), file sizes, and thumbnail previews.
* **Search & Filters**: Instant full-text search across copied text, image metadata, and quick filter pills (`All`, `Text`, `Images`).
* **One-Click & Keyboard Actions**: Copy/paste back into active window (`Enter`), individual item deletion (`Delete` icon), and full history wipe with confirmation.

### 🔊 Integrated Center-Pill Hardware OSD
* **In-Bar Feedback**: Volume and brightness hotkey adjustments are rendered directly within the center bar pill rather than in detached side popups or overlays.
* **Smart Pill Transformation**: Temporarily swaps the clock/date out for a clean volume/brightness icon and percentage slider, smoothly reverting back 1.5s after adjustments cease.

### ⚡ Power Management & Lock Screen Actions
* **Dedicated Power Controls**: Added four core system actions to the Battery / Quick Settings panel:
  * 🔒 **Lock**: Spawns screen locker (`swaylock` / configured locker).
  * 💤 **Sleep**: Triggers `systemctl suspend`.
  * 🔄 **Restart**: Triggers `systemctl reboot`.
  * ⏻ **Power Off**: Triggers `systemctl poweroff`.
* **Non-Blocking Execution**: Actions run asynchronously via `control.py power-action <cmd>` to ensure the UI thread never freezes.

### 🎨 Native Desktop Color Icons
* Replaced fallback monochrome/symbolic icons in the app launcher with full-color official application icons across system themes (`hicolor`, `breeze`, `Adwaita`, `/usr/share/pixmaps/`, `/usr/share/icons/`).
* Fixed missing icons for Chromium PWAs (Grok, WhatsApp Web) and standalone apps.

### 📍 Configurable Bar Rest Position (Top & Bottom)
* Added real-time switching between **Top** and **Bottom** bar positions.
* State persists in `config.json` and updates via IPC (`qs ipc call bar setTop` / `setBottom`) or through the Quick Settings panel.

---

## 3. Bugs Encountered & Fixes Applied

### 🐛 Bug 1: Popup Windows Stretching Full Screen (~960px Tall)
* **Symptom**: Opening **Clipboard History** or **Applications** caused the modal card to stretch nearly 1000px vertically, covering almost the entire display.
* **Root Cause**:
  In `shell.qml`, panel positioning used dynamic anchor bindings:
  ```qml
  anchors.top: root.barPosition === "top" ? parent.top : undefined
  anchors.bottom: root.barPosition === "bottom" ? parent.bottom : undefined
  ```
  In Qt Quick, assigning `undefined` to an `AnchorLine` does **not** clear or unbind the anchor constraint. When `barPosition` was `"bottom"`, **both** `anchors.top` and `anchors.bottom` remained bound simultaneously to the overlay surface boundaries, completely overriding `height: 540` / `height: 520`.
* **Fix**:
  Replaced ambiguous `undefined` anchor lines with explicit vertical coordinates across all panels:
  ```qml
  y: root.barPosition === "top" ? 0 : (parent.height - height)
  anchors.horizontalCenter: parent.horizontalCenter
  ```
  Modals now render at their strict designed dimensions (`540px` and `520px`).

---

### 🐛 Bug 2: Fidgety Hover Balls Popping From the Right
* **Symptom**: Moving the mouse over the bar caused both the Left (Wi-Fi) and Right (Battery) status balls to jump out from the right side and slide across the bar rather than emerging cleanly from their respective sides.
* **Root Cause**:
  A previous attempt to support vertical (Left/Right) screen orientations switched ball positioning from Qt Quick anchors to manual `x` and `y` coordinate bindings. Because `centerPill.width` animated outward symmetrically from the center, `centerPill.x` shifted during expansion, causing `leftBall.x` to temporarily move rightward.
* **Fix**:
  * Stripped experimental vertical (Left/Right) bar modes.
  * Reverted balls back to native Qt Quick anchor lines:
    * `leftBall`: `anchors.right: centerPill.left`, `anchors.rightMargin: pillCluster.showBalls ? 10 : -theme.ballRadius`
    * `rightBall`: `anchors.left: centerPill.right`, `anchors.leftMargin: pillCluster.showBalls ? 10 : -theme.ballRadius`
  * Both balls now emerge cleanly and symmetrically from behind the center pill.

---

### 🐛 Bug 3: App Launcher Search Bar Getting Bugged / Stale Queries
* **Symptom**: Reopening the launcher retained previous search terms, frequently resulting in empty lists or requiring manual backspacing before typing.
* **Root Cause**: The search query property remained bound across visibility toggles without an explicit reset trigger.
* **Fix**:
  Added a centralized `resetSearch()` method called on `isShownChanged` and `visibleChanged`:
  ```qml
  function resetSearch() {
      searchQuery = ""
      activeCategory = "All"
      selectedIndex = 0
      if (searchInput) {
          searchInput.text = ""
          searchInput.forceActiveFocus()
      }
      currentApps = getFilteredApps()
  }
  ```

---

### 🐛 Bug 4: Persistent "Desktop" Badge in Center Pill
* **Symptom**: When no window was active, the bar displayed an unnecessary `Desktop` badge.
* **Root Cause**: Window tracking reported `sysStats.focusedApp = "Desktop"` as a fallback string.
* **Fix**:
  Added a check `sysStats.focusedApp.toLowerCase() !== "desktop"` to completely hide the app badge when no application window is focused.

---

### 🐛 Bug 5: Quickshell Process Termination on Terminal Exit
* **Symptom**: Closing the terminal session where `qs` was initially tested killed the bar.
* **Root Cause**: Process was tied to the interactive terminal session rather than an independent systemd user service.
* **Fix**:
  * Configured and enabled `simple-bar.service` under `~/.config/systemd/user/`.
  * Added autostart entry in `~/.config/niri/config.d/50-startup.kdl`.

---

### 🐛 Bug 6: Notification Toast Collapsing Center Pill into a Ball
* **Symptom**: When a desktop notification arrived, the center pill shrank into an awkward circle/ball with the text overflowing vertically above and below.
* **Root Cause**:
  * The toast container’s `implicitWidth` evaluated to `0` while invisible, causing width recalculation to collapse when transitioning.
  * In addition, `toastRow` rendered summaries and multiline bodies vertically in a `ColumnLayout` without bounding height constraints, spilling text outside the 26px pill boundary.
* **Fix**:
  * Added a dedicated `toastContentWidth` property that persistently stores content dimensions.
  * Replaced the multi-line layout with a strict horizontal `Row` (`height: 26`) that sanitizes newlines via `.replace(/[\r\n]+/g, " ")`, truncates with `maximumLineCount: 1` and `elide: Text.ElideRight`, inserts an inline bullet separator (`•`), and displays a smooth hover dismiss button (`✕`).

---

### 🐛 Bug 7: Detached Floating Panels with Visible Gaps
* **Symptom**: Several quick-settings panels (Connectivity, Battery, System Resources, App Context) floated detached from the bar with 6px gaps, asymmetric offsets (`-120px` / `+120px`), and mismatched widths (360px–380px), breaking the unified pill aesthetic.
* **Root Cause**: Modals were designed as individual floating flyouts rather than adhering to the flush-edge unified panel system established by the application launcher and clipboard panels.
* **Fix**:
  * Updated `centerPill.hasOpenPanel` to trigger dynamically whenever any popup is open (`root.activePopup !== "" && !root.isPopupClosing`), expanding the center pill to a full `560px` width and flattening the adjoining corners.
  * Standardized all 8 overlay panels (`connPanel`, `batteryPanel`, `sysresPanel`, `appContextPanel`, `calendarPanel`, `appsPanel`, `clipboardPanel`, `notificationsPanel`) to `width: 560`, `anchors.horizontalCenter: parent.horizontalCenter`, and `y: root.barPosition === "top" ? 0 : (parent.height - height)` with matching zero-gap top/bottom radii and cubic easing animations.

---

### 🐛 Bug 8: System Freeze on Service Restart
* **Symptom**: Executing `systemctl --user restart simple-bar.service` inadvertently closed running graphical applications because the service was bound to compositor lifecycle targets.
* **Fix**:
  * Hot-reload workflows now rely strictly on Quickshell's native automatic file watcher upon editing `shell.qml`, eliminating the need to ever restart the user systemd unit during desktop sessions.

---

### 🐛 Bug 9: Duplicate Hardware Telemetry in Battery Flyout
* **Symptom**: CPU and RAM resource meters duplicated functionality inside the Battery quick settings panel, creating unnecessary clutter and blank space.
* **Fix**:
  * Extracted CPU, RAM, and Swap monitoring into dedicated **Workspace 3 (System Resources)** and a unified **System Resources** panel.
  * Removed the redundant bars from `batteryPanel` and tightened its height to 400px.

---

### 🐛 Bug 10: Workspace 0 Status Balls Failed to Open Flyouts on Click
* **Symptom**: Clicking `leftBall` (Wi-Fi/Bluetooth) or `rightBall` (Battery/Power) in the primary overview workspace did not open any panels.
* **Root Cause**: `leftBallMouse` and `rightBallMouse` directly assigned `root.activePopup = "wifi"` / `"battery"` instead of calling `root.togglePopup(...)`. This bypassed updating `root.displayedPopup`, leaving `connPanel` and `batteryPanel` hidden (`visible: root.displayedPopup === "..."`).
* **Fix**: Updated both click handlers to invoke `root.togglePopup("wifi")` and `root.togglePopup("battery")`.

---

### 🐛 Bug 11: Notification Pill Click Triggered Action Without Showing Details
* **Symptom**: Clicking an in-pill notification toast immediately executed its default action and dismissed the toast, preventing users from reading multi-line message contents.
* **Fix**: Updated `onClicked` in `toastContainer`: left-click now dismisses the toast from the pill and immediately opens the full **Notifications History Panel** (`root.openPopup("notifications")`) to view complete details, actions, and timestamps. Right-click dismisses the notification.

---

### 🐛 Bug 12: Duplicate QML ID Collision in Wallhaven Pagination
* **Symptom**: Quickshell configuration reload failed with `@shell.qml[6659:45]: id is not unique`.
* **Root Cause**: MouseArea and RowLayout IDs (`prevHov`, `nextHov`, `firstHov`, `prevRow`, `nextRow`) collided with month navigation controls in `calendarPanel`.
* **Fix**: Prefixed all pagination IDs with `whPg` (`whPgFirstHov`, `whPgPrevRow`, `whPgPrevHov`, `whPgNextRow`, `whPgNextHov`).

---

### 🐛 Bug 13: Terminal Emulators (Kitty) Lost Theme
* **Symptom**: Kitty terminal launched unstyled with fallback default colors after desktop theming was introduced.
* **Root Cause**: `~/.config/kitty/kitty.conf` included `current-theme.conf`, which did not exist on disk and was never populated by any theme manager.
* **Fix**: Added `export_terminal_themes()` to `scripts/theme.py`, dynamically writing `~/.config/kitty/current-theme.conf` and `~/.config/foot/colors.ini` with 16-color ANSI mappings, and triggering `pkill -USR1 kitty` for zero-restart live reload.

---

## 4. Bar-Workspaces System (v2.0)

| Workspace | Purpose | Unhovered State | Hovered State | Click Interaction |
|---|---|---|---|---|
| **WS 0: Overview** | Primary desktop telemetry | Focused App Title, Clock + Date, Weather, Notification Bell | Reveals Launcher button, Balls, App Icon, Pager dots | • Focused App: Opens App Context Menu.<br>• Clock: Opens Unified Calendar.<br>• Bell: Opens Notifications History. |
| **WS 1: Status & Controls** | Hardware & connectivity shortcuts | Clean icon row: Wi-Fi, Bluetooth, Caffeine, Battery, Brightness, Volume | Reveals descriptive labels and values beside each icon | • Wi-Fi/BT: Opens Connectivity.<br>• Bat/Br/Vol: Opens Battery & Device.<br>• Caffeine: Toggles idle inhibitor.<br>• Themes: Opens Wallpaper Manager. |
| **WS 2: Media Player** | MPRIS player interface | Album art, track title, artist name | Reveals Previous / Next track buttons | Toggles Play / Pause. |
| **WS 3: System Resources** | Live hardware vitals | CPU %, CPU Temp (°C), RAM usage, Swap usage | Reveals labels ("CPU", "Temp", "RAM", "Swap") | Opens detailed System Resources panel with `btop` launcher. |

* **Workspace Switching**: Bound to `Mod+Alt+Left` (previous) and `Mod+Alt+Right` (next) via Quickshell IPC.

---

## 5. File Diffs & Changes Summary

| File | Changes |
|---|---|
| [`shell.qml`](shell.qml) | • Added 560px flush `wallpaperPanel` with Local Library and Wallhaven tabs.<br>• Added Wallhaven 12-per-page pagination controls (`First`, `Prev`, `Next`, page counter).<br>• Fixed status balls click handlers to use `togglePopup()`.<br>• Enhanced in-pill notification click to expand full notification details.<br>• Added dynamic `themeManager` property bindings for live color updates. |
| [`scripts/theme.py`](scripts/theme.py) | • Core wallpaper manager, Pillow color extraction, semantic token generator.<br>• Wallhaven API integration with aspect ratio/purity filters and sub-page slicing.<br>• Terminal theme generator for Kitty (`current-theme.conf`) and Foot (`colors.ini`) with `pkill -USR1 kitty`.<br>• Startup `init_wallpaper()` for daemon readiness check and remembered wallpaper restoration. |
| [`scripts/control.py`](scripts/control.py) | • Added CLI dispatchers: `get-wallpapers`, `set-wallpaper`, `random-wallpaper`, `search-wallhaven`, `apply-wallhaven`, `get-theme`, `set-accent`, `set-theme-mode`, `init-wallpaper`.<br>• Added `monitor_wallpaper()` thread in `stream-wm` to broadcast live color updates.<br>• Added `init_wallpaper()` call on bar startup. |
| [`systemd/awww-daemon.service`](systemd/awww-daemon.service) | • User service template for `awww-daemon` with `ExecStartPost` initialization hook. |
| [`systemd/simple-bar.service`](systemd/simple-bar.service) | • User service template for `simple-bar` with `Wants=awww-daemon.service`. |
| [`config.json`](config.json) | • Stores `position`, `wallpaper`, `wallpaper_dir`, `theme_mode`. |
| [`install.sh`](install.sh) | • Added systemd user services installation and enabling step.<br>• Added executable permissions for `scripts/theme.py`. |
| [`README.md`](README.md) & [`CHANGELOG.md`](CHANGELOG.md) | • Comprehensive documentation for wallpaper service, terminal theming, and autostart. |
