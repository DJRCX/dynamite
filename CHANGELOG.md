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

## 4. Bar-Workspaces System (v2.0)

| Workspace | Purpose | Unhovered State | Hovered State | Click Interaction |
|---|---|---|---|---|
| **WS 0: Overview** | Primary desktop telemetry | Focused App Title, Clock + Date, Weather, Notification Bell | Reveals Launcher button, Balls, App Icon, Pager dots | • Focused App: Opens App Context Menu.<br>• Clock: Opens Unified Calendar.<br>• Bell: Opens Notifications History. |
| **WS 1: Status & Controls** | Hardware & connectivity shortcuts | Clean icon row: Wi-Fi, Bluetooth, Caffeine, Battery, Brightness, Volume | Reveals descriptive labels and values beside each icon | • Wi-Fi/BT: Opens Connectivity.<br>• Bat/Br/Vol: Opens Battery & Device.<br>• Caffeine: Toggles idle inhibitor. |
| **WS 2: Media Player** | MPRIS player interface | Album art, track title, artist name | Reveals Previous / Next track buttons | Toggles Play / Pause. |
| **WS 3: System Resources** | Live hardware vitals | CPU %, CPU Temp (°C), RAM usage, Swap usage | Reveals labels ("CPU", "Temp", "RAM", "Swap") | Opens detailed System Resources panel with `btop` launcher. |

* **Workspace Switching**: Bound to `Mod+Alt+Left` (previous) and `Mod+Alt+Right` (next) via Quickshell IPC.

---

## 5. File Diffs & Changes Summary

| File | Changes |
|---|---|
| [`shell.qml`](shell.qml) | • Implemented 4-Workspace Bar system with smooth horizontal transition animations.<br>• Added native `NotificationServer` and horizontal in-pill toast HUD with hover clear button.<br>• Unified all 8 overlay panels (560px, flush against bar, zero margin, flat connecting corners).<br>• Added Focused App Context Menu with browser-specific actions.<br>• Added DND bell icon state (`󰂛`).<br>• Bound `Mod+Alt+Arrow` IPC handlers. |
| [`scripts/control.py`](scripts/control.py) | • Added CPU temperature probing (`/sys/class/thermal`, `/sys/class/hwmon`).<br>• Added Swap memory calculation (`/proc/meminfo`).<br>• Added Caffeine inhibitor backend (`systemd-inhibit --what=idle:sleep ...`).<br>• Fixed detached subprocess execution to prevent EPIPE crashes in spawned apps. |
| [`config.json`](config.json) | • Stores active bar rest position (`"top"` or `"bottom"`). |
| [`install.sh`](install.sh) | • Added dependency verification for `systemd-inhibit` and audio/network utilities. |
| [`CHANGELOG.md`](CHANGELOG.md) | • Complete documentation of v2.0 features, bugs, root causes, and fixes. |
