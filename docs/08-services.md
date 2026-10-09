# 08 — Services

Each service is a `Singleton` in `dynamite/services/`. UI code reads properties and calls functions; it never runs commands itself. Prefer Quickshell's native modules (verified present in 0.3.1) over shelling out.

| Service | Source | Key API |
|---|---|---|
| `Niri` | `Process { command: ["niri","msg","-j","event-stream"]; stdout: SplitParser {…} }` | `workspaces`, `focusedOutput`, `focusedWindow`, `outputs` |
| `Audio` | `Quickshell.Services.Pipewire` | `sink`, `source`, `volume`, `muted`, `setVolume()`, `outputs`, `inputs`, `streams`, `setDefault(node)` |
| `Battery` | `Quickshell.Services.UPower` | `fraction` (0–1), `charging`, `timeLeft` |
| `Network` | `Quickshell.Networking` | `wifiEnabled`, `wifi` (device), `networks`, `active`, `wifiIcon`, `connect(net, psk)` |
| `Bluetooth` | `Quickshell.Bluetooth` | `adapter`, `enabled`, `discovering`, `saved`, `nearby` |
| `Media` | `Quickshell.Services.Mpris` | `players`, `activePlayer` |
| `Notifs` | `Quickshell.Services.Notifications` | `list`, `dnd`, `clear()`, `dismiss(n)`, `toastQueue` |
| `Displays` | `niri msg -j outputs` | `outputs`, `setMode()`, `setScale()` |
| `Brightness` | `brightnessctl` + `ddcutil` | per-output `target`/`current`, smooth ramp |
| `NightLight` | `wlsunset` | `enabled`, `temperature` |
| `Apps` | `DesktopEntries` | `search(q)`, `launch(entry)` |
| `Power` | `systemctl`, `niri msg`, `tlpctl` | `suspend()`, `reboot()`, `poweroff()`, `logout()`, `setProfile()` |
| `Lock` | — | `locked` (bound by `WlSessionLock`) |
| Extras (Phases 13–17) | see `10-extras.md` | `Wallpaper`, `TerminalThemes`, `Wallhaven`, `Clipboard`, `Keybinds`, `PowerProfile`, `Idle`, `SysStats`, `Weather` |

## Niri

- Parse each line of `niri msg -j event-stream` as JSON. Events are objects keyed by type, e.g. `{"WorkspacesChanged":{"workspaces":[…]}}`, `{"WorkspaceActivated":{"id":…,"focused":true}}`, `{"WindowFocusChanged":{"id":…}}`, `{"WindowsChanged":{"windows":[…]}}`, `{"WindowOpenedOrChanged":{"window":{…}}}`.
- `focusedOutput` = the `output` of the workspace with `is_focused: true`. Panels open on this output only (`Island.screenName`).
- Restart the process if it exits (`onExited: restartTimer.start()`).
- The legacy `scripts/control.py wm-stream` does a version of this. Don't use it (it's deleted in Phase 18); parse the event stream directly so Dynamite has no Python dependency on its hot path.
- Keep the full window objects (`id`, `app_id`, `title`, `pid`, `workspace_id`, `is_floating`, `is_focused`) in `Niri.windows`; `focusedWindow` is used by the window menu and game bar (`10-extras.md` §11).

## Audio (PipeWire)

```qml
import Quickshell.Services.Pipewire
PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }  // required, or audio props stay invalid
readonly property PwNode sink: Pipewire.defaultAudioSink
readonly property real volume: sink?.audio?.volume ?? 0
readonly property bool muted: sink?.audio?.muted ?? false
function setVolume(v) { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v)) }
function setDefault(node) { Pipewire.preferredDefaultAudioSink = node }   // source: preferredDefaultAudioSource
```

- `outputs`/`inputs`: `Pipewire.nodes.values` filtered by `isSink`/`!isSink` and `!isStream` and `audio`.
- `streams` (the Sound page's "Apps"): nodes with `isStream && isSink === false`. Track them with a `PwObjectTracker` while the Sound page is open, and show `properties["application.name"]`.
- Emit `osdRequested("volume")` when `volume` or `muted` changes and the change didn't come from the CC slider being dragged.

## Battery (UPower)

`UPower.displayDevice`: `percentage` (check the range at runtime and normalize to 0–1), `state` (`UPowerDeviceState.Charging`/`FullyCharged`), `timeToEmpty`, `timeToFull`. If `isLaptopBattery` is false (desktop), hide the ring and show only the Wi-Fi glyph.

## Network

Use `Quickshell.Networking`:

- `Networking.wifiEnabled` (read/write) is the master switch.
- `Networking.devices.values` → the `WifiDevice` (`type === DeviceType.Wifi`). Set `scannerEnabled = true` while the Wi-Fi page is open, false otherwise.
- `wifiDevice.networks.values` → `WifiNetwork { name, signalStrength (0–1), security, connected, known, state, stateChanging, connectionFailed, reason }`.
- Connect: known → `net.connect()`; secured unknown → `net.connectWithPsk(psk)`; `net.disconnect()`, `net.forget()`.
- Wired: `WiredDevice.hasLink` → use the `lan` icon in the status circle.
- `wifiIcon`: `wifi_off` when disabled, `signal_wifi_statusbar_not_connected` when on but not connected, otherwise `network_wifi_1_bar`/`network_wifi_2_bar`/`network_wifi_3_bar`/`wifi` by strength.

Fallback, if the module misbehaves on this machine: `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto` and `nmcli dev wifi connect <ssid> password <psk>`.

## Bluetooth

`Quickshell.Bluetooth`:

- `Bluetooth.defaultAdapter`: `enabled` (read/write), `discovering` (read/write; set true while the page is open), `devices.values`.
- `BluetoothDevice`: `name`, `icon` (freedesktop icon name such as `audio-headphones`), `connected`, `paired`, `bonded`, `trusted`, `state` (`BluetoothDeviceState`: Connecting/Connected/Disconnecting/Disconnected), `batteryAvailable`, `battery` (0–1); methods `connect()`, `disconnect()`, `pair()`, `forget()`.
- `saved` = devices with `paired || bonded`; `nearby` = the rest with a non-empty name.
- After `pair()` succeeds, set `trusted = true` and `connect()`.

## Media (MPRIS)

`Mpris.players.values`. `activePlayer` = the playing one, else the last one that played. Its properties: `trackTitle`, `trackArtist`, `trackAlbum`, `trackArtUrl`, `identity`, `isPlaying`, `canGoNext`, `canGoPrevious`, `canSeek`, `position`, `length`; methods `togglePlaying()`, `next()`, `previous()`, and assign `position` to seek. Refresh `position` by calling `player.positionChanged()` every second while the media panel is open.

## Notifications

```qml
NotificationServer {
    keepOnReload: true
    actionsSupported: true
    imageSupported: true
    bodyMarkupSupported: false
    onNotification: n => { n.tracked = true; Notifs.push(n) }
}
```

`Notifs.list` = `server.trackedNotifications.values` (newest first). `toastQueue` holds notifications that haven't been toasted. Respect `Config.notifications.dnd`. Expose `IpcHandler { target: "notifs"; function debugInject(summary: string, body: string): void }` that adds a fake entry, so the UI can be built while simple-bar still owns the bus.

## Displays (Niri outputs)

- Read: `niri msg -j outputs` → object keyed by connector name. Use `name`, `make`, `model`, `modes[]` (`width`, `height`, `refresh_rate` in mHz), `current_mode` (index), `logical.scale`. Refresh on `OutputsChanged`-style events or when the Display page opens.
- Mode: `niri msg output <name> mode <W>x<H>@<Hz>` (Hz with 3 decimals, from `refresh_rate / 1000`).
- Scale: `niri msg output <name> scale <s>`.
- These are runtime changes. To persist them, write an `output "<name>" { mode "…"; scale …; }` block to `~/.config/niri/config.d/60-dynamite-outputs.kdl`, but only if the user's `config.kdl` already includes `config.d/*.kdl` (check first; never edit their main config).

## Brightness — the smooth ramp

The walkthrough's point: brightness changes are **ramps, never steps**, on both the laptop panel and DDC/CI monitors.

Per output keep `target` (0–100, what the user asked for) and `current` (what's on screen). Animate `current` toward `target` with the `fade` spring, and push `current` to hardware from a writer that never blocks the UI:

```text
Internal panel (eDP-*):
  device = first entry of `brightnessctl -l -c backlight -m`
  writer: Timer 16 ms; if round(current) != lastWritten and no process running:
          brightnessctl -q -d <device> set <round(current)>%     (clamp to ≥ 1%)

External monitor (DP-*, HDMI-*):
  bus   = from `ddcutil detect --terse`, matching "DRM connector: cardN-<name>" to "I2C bus: /dev/i2c-<bus>"
  writer: exactly one ddcutil process in flight; when it exits, if round(current) != lastWritten:
          ddcutil --bus <bus> --noverify --sleep-multiplier 0.2 setvcp 10 <round(current)>
```

DDC writes are slow (~50–150 ms), so the coalescing writer naturally drops intermediate values while the spring keeps the UI smooth. Read initial values with `brightnessctl -m -d <device>` and `ddcutil --bus <bus> getvcp 10 --terse`.

Keys: `brightness up/down` IPC changes the **focused output's** `target` by ±5 and requests the OSD.

Requirements: `ddcutil` needs the `i2c-dev` module and the user in the `i2c` group. If `ddcutil detect` finds nothing, hide that output's slider rather than failing.

## Night light

`wlsunset` is installed. For a constant temperature, set low and high one kelvin apart so day and night look the same:

```text
wlsunset -t <K> -T <K+1> -S 06:00 -s 18:00
```

Changing the temperature restarts the process (debounce slider drags: apply 250 ms after the last change). Off = stop the process. If `wl-gammarelay-rs` is installed later, prefer it: it can change temperature live over D-Bus without a restart.

## Apps

`DesktopEntries.applications.values`, excluding `noDisplay`. Launch with `Quickshell.execDetached(["niri","msg","action","spawn","--", ...entry.command])` (and `entry.workingDirectory` if set). Store launch counts in `~/.local/state/dynamite/launch-counts.json`.

## Power

- Suspend: `systemctl suspend` (lock first). Reboot/power off: `systemctl reboot|poweroff`. Log out: `niri msg action quit --skip-confirmation`.
- Power profiles: TLP + tlp-pd are installed and configured by the drop-in `tlp/simple-bar.conf`. Read the profile with `tlpctl get` and set it with `tlpctl performance|balanced|power-saver`. Until Phase 16, game mode just switches to performance and restores the previous profile on exit; Phase 16 adds automatic switching (`services/PowerProfile.qml`, `10-extras.md` §7) and owns all profile changes from then on. Don't run power-profiles-daemon.

## Lock

`Lock.locked` is the single source of truth, bound to `WlSessionLock.locked`. `Lock.lock()` sets it; the lock surface unlocks it after PAM succeeds. Expose `IpcHandler { target: "lock"; function lock(): void }`.
