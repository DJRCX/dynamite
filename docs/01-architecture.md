# 01 — Architecture

Target stack (verified on this machine): **Quickshell 0.3.1**, **Qt 6.11**, **Niri 26.04**, Arch/CachyOS.

## Directory layout

Create everything under `dynamite/` at the repo root. Each subdirectory is importable as a module via Quickshell's `qs.` prefix (e.g. `import qs.theme`, `import qs.services`).

**Dynamite replaces simple-bar completely.** `dynamite/` is only a staging folder so the legacy bar keeps running while Dynamite is built. In Phase 18 (`09-phases.md`) the legacy files are deleted and the *contents* of `dynamite/` move to the repo root. So:

- Never hard-code the `dynamite/` path. Use `Quickshell.shellDir` in QML and `$(dirname "$0")` in scripts, so everything still works after the move.
- Never import, call or read legacy files (`../shell.qml`, `../scripts/`, `../colors.json`). If Dynamite needs something from them, copy it into `dynamite/` and adapt it. The one exception is the one-time settings import from `../config.json` (`10-extras.md` → Migration).
- Everything the final repo needs (installer, systemd units, TLP drop-in, Niri snippet, README, AGENTS.md) is written inside `dynamite/` too.

```text
dynamite/
├── shell.qml                  # ShellRoot: instantiates windows, IPC, lock, polkit, notifications
├── theme/
│   ├── Theme.qml              # Singleton: active palette (from themes/*.json)
│   ├── Metrics.qml            # Singleton: sizes, radii, gaps (fixed design numbers)
│   └── Motion.qml             # Singleton: spring tokens
├── config/
│   └── Config.qml             # Singleton: user settings (FileView + JsonAdapter, live-saved)
├── themes/
│   ├── horizon-mint.json      # default
│   └── …                      # one JSON per theme (see 02-design-tokens.md)
├── services/                  # Singletons wrapping system state (08-services.md)
│   ├── Niri.qml  Audio.qml  Battery.qml  Network.qml  Bluetooth.qml  Media.qml
│   ├── Notifs.qml  Displays.qml  Brightness.qml  NightLight.qml  Apps.qml  Power.qml
│   ├── Wallpaper.qml  TerminalThemes.qml  Wallhaven.qml  Clipboard.qml        # extras (10-extras.md)
│   ├── Keybinds.qml  kdl.js  PowerProfile.qml  Idle.qml  SysStats.qml  Weather.qml
├── state/
│   └── Island.qml             # Singleton: the island state machine (below)
├── components/                # Small reusable widgets
│   ├── Icon.qml  Switch.qml  Slider.qml  PillButton.qml  CircleButton.qml
│   ├── StatusCircle.qml  AlbumCircle.qml  SpringRect.qml  Shadow.qml
├── island/
│   ├── IslandWindow.qml       # PanelWindow per screen; hosts the 3 islands + game bar
│   ├── Scrim.qml              # transparent click-outside catcher
│   ├── CenterIsland.qml  AlbumIsland.qml  StatusIsland.qml
│   └── panels/                # Content that lives inside an expanded island
│       ├── CollapsedClock.qml  HoverClock.qml  Calendar.qml  MediaPlayer.qml
│       ├── Launcher.qml  PowerMenu.qml  Osd.qml  Toast.qml  PolkitPrompt.qml  ThemePicker.qml
│       └── WallpaperPicker.qml  ClipboardPanel.qml  KeybindsPanel.qml  WindowMenu.qml   # extras
├── controlcenter/
│   ├── ControlCenter.qml      # grid host + page stack
│   ├── GridLayoutModel.qml    # layout data (columns, items, sizes)
│   ├── tiles/  ToggleCircle.qml  Tile.qml  SliderCard.qml  NotificationsCard.qml  NowPlayingCard.qml  SystemCard.qml
│   └── pages/  WifiPage.qml  BluetoothPage.qml  SoundPage.qml  DisplayPage.qml  SubPage.qml  BatteryPage.qml  SystemPage.qml
├── lock/
│   └── LockScreen.qml         # WlSessionLock + PamContext
├── settings/
│   ├── SettingsWindow.qml     # FloatingWindow
│   └── pages/ …               # one file per sidebar entry
├── scripts/                   # Dynamite's own helpers, e.g. palette.py (never call ../scripts)
├── templates/                 # kitty.conf, foot.ini (terminal color templates)
├── systemd/                   # simple-bar.service, awww-daemon.service (final versions, Phase 18)
├── tlp/                       # simple-bar.conf (copied from ../tlp in Phase 16)
├── niri/                      # simple-bar.kdl: binds + window rules for the final setup
├── install.sh  README.md  AGENTS.md  .gitignore               # final repo files (Phase 18)
├── takeover.sh                # replaces the legacy shell; run by the user (Phase 18)
└── dev/
    ├── niri-dev.kdl           # minimal config for the nested compositor
    ├── run-nested.sh          # starts nested niri running Dynamite
    ├── shot.sh                # screenshots the nested session
    └── spring-check.qml       # already provided
```

Keep files small (target < 300 lines). The legacy `shell.qml` is a single 8k-line file; don't repeat that.

## Windows and layers

| Window | Type | Layer | Anchors | Notes |
|---|---|---|---|---|
| `IslandWindow` | `PanelWindow` (one per screen via `Variants { model: Quickshell.screens }`) | `WlrLayer.Overlay` | top, left, right | Fixed `implicitHeight: Metrics.windowHeight` (780). `exclusiveZone` = `Config.island.gap + Config.bar.height` (44), or `Config.gameMode.barHeight` (47) in game mode. `mask` = union of the three island rectangles (see below). |
| `Scrim` | `PanelWindow` per screen | `WlrLayer.Top` | all four | `exclusionMode: ExclusionMode.Ignore`, fully transparent, `visible` only while an *interactive* panel is open on that screen. A `MouseArea` calls `Island.close()`. Because the island window is on `Overlay` and the scrim on `Top`, the island is always above it. |
| `LockScreen` | `WlSessionLock` + `WlSessionLockSurface` per screen | session lock | — | `06-overlays.md`. |
| `SettingsWindow` | `FloatingWindow` | normal toplevel | — | Niri tiles/floats it like any app. Add a Niri window rule to open it floating and centered. |

Do **not** resize the island layer surface while animating; resizing a layer surface every frame causes flicker on Niri. Keep the window at its max size and change only the input `mask`.

### Input mask

```qml
mask: Region {
    Region { item: albumIsland }
    Region { item: centerIsland }
    Region { item: statusIsland }
}
```

The region follows the animated items automatically. Clicks anywhere else fall through to the apps below.

## The island state machine (`state/Island.qml`)

One singleton owns what is open. Components never open each other directly; they call `Island.open(...)`/`Island.close()`.

```qml
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // collapsed | clock | calendar | media | cc | launcher | power | osd | toast | polkit | themes
    // + extras: wallpapers | clipboard | keybinds | window
    property string mode: "collapsed"
    property string ccPage: "main"        // main | wifi | bluetooth | sound | display (+ battery | system)
    property string screenName: ""        // output the panel is open on (Niri focused output)
    property bool gameMode: false
    property bool editing: false          // CC layout editor active

    // extras (wallpapers, clipboard, keybinds, window) join both lists when they're built
    readonly property bool interactive: ["calendar","media","cc","launcher","power","polkit","themes"].includes(mode)
    readonly property bool wantsKeyboard: ["launcher","power","polkit","themes","cc","calendar","media"].includes(mode)

    function open(m) { … }   // applies priority rules below
    function close() { mode = "collapsed"; ccPage = "main" }
    function toggle(m) { mode === m ? close() : open(m) }
}
```

### Which island hosts which mode

| Mode | Island that expands | Others |
|---|---|---|
| `collapsed` | none | all three at rest |
| `clock`, `calendar`, `launcher`, `power`, `osd`, `toast`, `polkit`, `themes`, and the extras `wallpapers`, `clipboard`, `keybinds`, `window` | **center** | album + status slide outwards (gap rule in `04-island.md`) |
| `media` | **album** (grows leftwards from its right edge) | center + status stay collapsed |
| `cc` | **status** (grows rightwards/down from its top-left corner) | album + center stay collapsed |

### Priority and interruption rules

1. `lock` (separate surface) beats everything.
2. `polkit` preempts any mode and cannot be dismissed by the scrim; only Cancel/Esc/success close it.
3. Interactive panels (`calendar`, `media`, `cc`, `launcher`, `power`, `themes`) replace each other immediately; the springs retarget mid-flight.
4. `osd` only shows when mode is `collapsed` or `clock`; it auto-returns to the previous mode after 1.6 s of no changes. When the CC is open, volume/brightness changes just move its sliders.
5. `toast` shows when mode is `collapsed`/`clock`/`osd`, lasts 4 s, and queues otherwise. While the CC is open, new notifications appear in its notifications card instead. Focus mode (DND) suppresses toasts entirely.
6. Hover: `collapsed → clock` after the pointer rests on the center island for 80 ms; `clock → collapsed` 120 ms after it leaves; `calendar → collapsed` 350 ms after it leaves.

## Keyboard focus

`IslandWindow.WlrLayershell.keyboardFocus`:

- `WlrKeyboardFocus.Exclusive` while `launcher`, `polkit`, `themes`, `power`, `wallpapers`, `clipboard`, `keybinds` or `window` is open (they take typing/arrow keys).
- `WlrKeyboardFocus.OnDemand` for the other interactive modes (so Esc works after a click).
- `WlrKeyboardFocus.None` otherwise.

Esc always calls `Island.close()` (except polkit, where it means Cancel).

## IPC (for Niri keybinds)

Use `IpcHandler` in `shell.qml`. **Always address the instance by path**: `qs ipc -p <dir> call <target> <fn> [args]`. Named configs (`qs -c …`) don't work on this machine, because `~/.config/quickshell/shell.qml` exists and that disables config-name lookup.

- During development: `qs ipc -p <repo>/dynamite call …` (the nested instance).
- After Phase 18: `qs ipc -p ~/.config/quickshell/simple-bar call …`. That path is a symlink to the repo, and `simple-bar.service` keeps running `qs -p` on it, so the service name and path don't change.

| Target | Functions |
|---|---|
| `island` | `toggle(mode: string)`, `open(mode: string)`, `close()` |
| `cc` | `page(name: string)` |
| `lock` | `lock()` |
| `brightness` | `up()`, `down()`, `set(percent: int)` (drives the smooth ramp) |
| `gamemode` | `toggle()` |
| `theme` | `apply(name: string)` |
| `settings` | `open(page: string)` |
| `shell` | `reload()` → `Quickshell.reload(false)` (replaces the old "Restart Shell" bind that pkill'ed qs) |
| `wallpaper` | `set(path: string)`, `random()`, `next()`, `prev()` (Phase 13) |
| `caffeine` | `toggle()`, `for(minutes: int)` (Phase 16) |
| `power` | `profile(name: string)`, `auto()` (Phase 16) |

**Compatibility targets.** The user's Niri config already calls the legacy shell's targets. Implement these as thin aliases so those binds keep working unchanged after the takeover:

| Legacy call | Dynamite alias for |
|---|---|
| `launcher toggle` | `island.toggle("launcher")` |
| `powermenu toggle` | `island.toggle("power")` |
| `clipboard toggle` | `island.toggle("clipboard")` (Phase 15; until then it opens nothing) |
| `cheatsheet toggle` | `island.toggle("keybinds")` (Phase 15) |
| `bar prevWorkspace` / `bar nextWorkspace` | no-op (bar workspaces are gone; Phase 18 removes those binds) |

### Niri binds (final, written to `dynamite/niri/simple-bar.kdl` in Phase 18)

The user's binds live in `~/.config/niri/config.d/70-binds.kdl`. **Read it before choosing chords**: Mod+T, Mod+L, Mod+W, Mod+E, Mod+A, Mod+C, Mod+F, Mod+O, Mod+Q, Mod+R and many Mod+Shift/Ctrl combos are already taken. Existing shell binds to keep as they are: Mod+Space (launcher), Mod+V (clipboard), Mod+Slash (cheatsheet), Mod+Escape (power menu). Mod+Shift+V (fuzzel clipboard) is the user's own; leave it.

Proposed additions/replacements (free on this machine as of writing; re-check):

```kdl
binds {
    // replaces: Mod+Alt+L spawn "swaylock"
    Mod+Alt+L allow-when-locked=true hotkey-overlay-title="Lock" { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "lock" "lock"; }
    // replaces: Mod+Shift+Ctrl+Q "Restart Shell" (pkill + qs)
    Mod+Shift+Ctrl+Q hotkey-overlay-title="Reload Shell" { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "shell" "reload"; }
    Mod+N       hotkey-overlay-title="Control Center" { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "island" "toggle" "cc"; }
    Mod+M       hotkey-overlay-title="Media"          { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "island" "toggle" "media"; }
    Mod+Shift+T hotkey-overlay-title="Themes"         { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "island" "toggle" "themes"; }
    Mod+Shift+W hotkey-overlay-title="Wallpapers"     { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "island" "toggle" "wallpapers"; }
    Mod+Shift+Space hotkey-overlay-title="Window Menu" { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "island" "toggle" "window"; }
    Mod+G       hotkey-overlay-title="Game Mode"      { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "gamemode" "toggle"; }
    Mod+Comma   hotkey-overlay-title="Settings"       { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "settings" "open" "island"; }
    // brightness keys: route through the shell so they use the smooth ramp + OSD (replace the existing brightnessctl binds)
    XF86MonBrightnessUp   allow-when-locked=true { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "brightness" "up"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "qs" "ipc" "-p" "/home/djrcx/.config/quickshell/simple-bar" "call" "brightness" "down"; }
}
```

Remove the `Mod+Alt+Left/Right` "Bar Workspace" binds. Keep the user's volume keys; volume doesn't need IPC, because `services/Audio.qml` watches the PipeWire sink and triggers the OSD itself.

## Launching apps

Launch everything through Niri, not as a child of Quickshell, so apps never live in the shell's cgroup (the reason the legacy service can't be restarted):

```qml
Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", ...entry.command])
```

## Development loop

The live session already runs simple-bar, which owns the top edge, so develop Dynamite inside a **nested Niri** window.

`dev/niri-dev.kdl` — minimal config, no autostart of the real bar:

```kdl
input { keyboard { xkb { layout "us"; } } }
output "winit" { scale 1.0; }
layout { gaps 16; }
prefer-no-csd
binds {
    Mod+Return { spawn "alacritty"; }
    Mod+Space  { spawn "qs" "ipc" "-p" "DYNAMITE_DIR" "call" "island" "toggle" "launcher"; }
    Mod+Escape { spawn "qs" "ipc" "-p" "DYNAMITE_DIR" "call" "island" "toggle" "power"; }
    Mod+Q      { close-window; }
}
```

The dev scripts below exist and were tested on this machine; use them as they are.

| Script | What it does |
|---|---|
| `dev/run-nested.sh [start\|stop\|restart\|status] [--windowed]` | Starts nested Niri **in the background** and returns. Moves its window to the 1920×1080 host output (eDP-1, or `$DYNAMITE_OUTPUT`) and fullscreens it, so the nested output is exactly 1920×1080. Writes the nested display name to `/tmp/dynamite-display`. Prints the Quickshell log's WARN/ERROR lines. |
| `dev/ipc.sh <target> <fn> [args]` / `dev/ipc.sh show` | Calls Dynamite's IPC in the nested session. |
| `dev/shot.sh <name> ["x,y wxh"]` | Screenshot (optionally a region) of the nested output → `/tmp/dynamite-<name>.png`. |
| Logs | Quickshell: `/tmp/dynamite-dev.log`. Niri: `/tmp/dynamite-niri.log`. |

Three facts behind that design (don't "simplify" them away):

1. **Niri discards the stdout/stderr of the command it starts**, so `niri -- qs … | tee log` never shows Quickshell's errors. The script starts `qs` through `sh -c 'exec qs -p DIR >>LOG 2>&1'`.
2. **`qs ipc` only sees instances on the current display.** From the host, `qs ipc -p <dir> …` reports "no running instances" for the nested shell; it needs `WAYLAND_DISPLAY=<nested>`, which `dev/ipc.sh` sets.
3. The nested window is tiled at an arbitrary size by default (952×1024 here), which breaks every crop box, hence the fullscreen.

**Sandbox:** nested Niri must connect to the live compositor's socket in `$XDG_RUNTIME_DIR`. Inside a restricted sandbox that fails with `NoCompositor` (seen with Codex's default sandbox). The agent needs full access (no sandbox) to run the dev loop.

Quickshell hot-reloads on save; you rarely need to restart the nested session. Stop it when you're done (`dev/run-nested.sh stop`).

### Single-owner D-Bus services (important)

The nested session shares your real session bus. These can only have one owner at a time, and the live session already owns them:

| Service | Current owner | Effect during dev |
|---|---|---|
| `org.freedesktop.Notifications` | simple-bar's `NotificationServer` | Dynamite's server won't receive notifications. |
| Polkit authentication agent | `polkit-gnome-authentication-agent-1` (started by the XDG autostart unit `app-org.gnome.PolkitGnomeAuthenticationAgent@autostart.service`). A second agent, `polkit-mate-authentication-agent-1`, is also launched by `spawn-at-startup` in `~/.config/niri/config.d/50-startup.kdl` and by its own XDG autostart entry; it loses the race. | Dynamite's `PolkitAgent` won't register. |
| StatusNotifierWatcher (tray) | simple-bar | Not used by Dynamite. |

Build those features against fake data (a `Notifs.debugInject()` IPC function and a `PolkitPrompt` preview mode), then verify them for real after the takeover in Phase 18, when the legacy bar is gone and both polkit agents are disabled (XDG autostart overrides with `Hidden=true` in `~/.config/autostart/`, and the `spawn-at-startup` line removed).
