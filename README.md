# 🌙 simple-bar

> A Niri desktop shell configuration for Arch Linux, built with [Quickshell](https://quickshell.outfoxxed.me/). It combines a pitch-black floating status pill, quick-settings panels, and Niri-specific controls.

---

## ✨ Features

- **🖤 Pitch-Black Aesthetic**: Pure `#000000` background with refined `#0a0a0a` cards and subtle high-contrast borders.
- **🗂️ 4 Modular Bar-Workspaces**: Switch workspaces with `Mod+Alt+Left` / `Mod+Alt+Right`:
  - **Workspace 0 (Overview)**: Focused app badge (with context menu), Clock + Unified Calendar, Weather/System Tray slot, and Notification Bell with DND status.
  - **Workspace 1 (Status & Controls)**: Wi-Fi, Bluetooth, Caffeine inhibitor, Battery, Brightness, and Volume.
  - **Workspace 2 (Media Player)**: MPRIS playback controls with track title and album art.
  - **Workspace 3 (System Resources)**: Real-time CPU %, CPU Temp (°C), RAM usage, and Swap usage with dedicated details popup.
- **🎨 Wallpaper Management & Dynamic Theming**:
  - **Zero-Dependency PIL Color Engine**: Extracts dominant vibrant accents, secondary tones, and contrast-tested tokens directly from the desktop wallpaper.
  - **Randomized Animated Transitions**: Every wallpaper change runs a randomized `awww` transition effect (`wipe`, `fade`, `grow`, `wave`, `outer`) with randomized angles and focal points.
  - **Wallhaven.cc Online Explorer**: Integrated online catalogue browser with keyword search, sorting presets (`Toplist`, `Hot`, `Latest`, `Random`), 12-images-per-page pagination, and 1-click downloading directly to `~/Pictures/Wallpapers/`.
  - **Live Palette Swatches**: 6-color swatch chips to customize the primary accent, plus Pitch Black vs Tinted Dark modes.
  - **Live Terminal Theming**: Automatically generates and syncs colors for **Kitty** (`current-theme.conf`) and **Foot** (`colors.ini`), with zero-restart live reload (`pkill -USR1 kitty`).
  - **Zero-Restart Reactivity**: Live synchronization through `wm-stream` IPC updates all bar pills and panels instantaneously.
  - **Persistent Autostart & Memory**: Built-in systemd user services (`awww-daemon.service` & `simple-bar.service`) restore the remembered wallpaper and palette automatically on session startup.
- **🔗 Seamless Unified Panels**: All 11 flyout panels (Apps, Clipboard, Calendar, Connectivity, Battery, System Resources, Notifications, App Context, Wallpapers, Power & Session, Niri Keybindings) expand to a flush 560px width with flattened connecting edges directly merging into the bar pill.
- **🔔 Native Notification Server & In-Pill HUD**: Built-in notification server with single-line horizontal toast HUD, newline sanitization, hover dismiss button, and click-to-expand full details in the notification center.
- **☕ Caffeine Idle Inhibitor**: One-click system idle/sleep inhibition via `systemd-inhibit` with instant desktop feedback notifications.
- **🚀 Integrated Application Launcher**: Categorized app drawer (`All`, `System`, `Development`, `Internet`, `Media`, etc.) with full keyboard navigation and automatic query resets.
- **🧮 Launcher Calculator**: Enter arithmetic expressions in the app search field and copy the result directly from the launcher.
- **⌨️ Niri Keybinding Cheatsheet**: Search and filter keybindings parsed from `~/.config/niri/config.kdl` and `~/.config/niri/config.d/*.kdl`.
- **⏻ Power & Session Menu**: Lock, suspend, log out, reboot, power off, or enter firmware setup, with a confirmation step for disruptive actions. Shows the current host and uptime.
- **🪟 Better App Discovery**: Includes Flatpak and desktop-folder launchers, recognizes web apps, and uses desktop-entry metadata to resolve focused-app names and icons.
- **🧭 Timed Bar Workspaces**: The four bar workspaces can revert to Overview after a configurable timeout.
- **📋 Visual Clipboard History Manager**: Dual-format history for copied text and image thumbnails via `cliphist`.
- **🫥 Terminal Opacity**: The generated Kitty and Foot themes use the configurable `terminal_opacity` value from `config.json`.
- **📐 Window Exclusive Zone**: Reserves 46px at the configured edge (top or bottom) so tiled and maximized windows never overlap the bar.
- **🖱️ Outside-Click Dismissal**: Clicking outside any open panel or on any window instantly dismisses the panel back to the compact pill.

---

## 📦 Requirements & Dependencies

The theme relies on standard Linux utilities and Quickshell:

| Package | Purpose |
|---|---|
| **quickshell** (`qs`) | Modern Qt/QML shell environment for Wayland |
| **python3** | Hardware, Niri configuration, and desktop-app integration |
| **wireplumber** (`wpctl`) | Audio volume & mute control |
| **brightnessctl** | Display backlight control |
| **networkmanager** (`nmcli`) | Wi-Fi scanning, connection, and power control |
| **bluez** (`bluetoothctl`) | Bluetooth device pairing and connection management |
| **awww** | High-performance Wayland wallpaper daemon with animated transitions |
| **python-pillow** | Image processing and dynamic color extraction |
| **kitty** / **foot** *(optional)* | Terminal emulators with automatic dynamic theme reloading |
| **Nerd Fonts** | System font with icons (e.g. JetBrains Mono Nerd Font) |
| **blueman** *(optional)* | Graphical Bluetooth manager (`blueman-manager`) |
| **btop** *(optional)* | Terminal hardware resource monitor |

On Arch Linux, install the required packages with your preferred repositories/AUR helper. The installer prints an Arch package hint when it finds missing dependencies; Quickshell and `awww` may require AUR packages depending on your setup.

---

## 🚀 Installation

Clone the repository and run the setup script:

```bash
git clone https://github.com/DJRCX/simple-bar.git
cd simple-bar
./install.sh
```

The installer verifies your dependencies, sets execution permissions, symlinks the configuration to `~/.config/quickshell/simple-bar`, and installs/enables systemd user services for `simple-bar` and `awww-daemon`.

The checked-in `config.json` currently contains machine-specific wallpaper and weather-location values. Update those values for another machine; the wallpaper file must exist locally. `bar_workspace_timeout` is in seconds, and `terminal_opacity` is the generated Kitty/Foot background opacity (from `0.0` to `1.0`).

### Testing / Starting Manually

```bash
qs -d -p ~/.config/quickshell/simple-bar
```

---

## 🖥️ Autostart Configuration

### Systemd User Services (Recommended)
Both services run automatically under `graphical-session.target`:
```bash
systemctl --user enable --now awww-daemon.service simple-bar.service
```

### Wayland Compositor Autostart

#### Niri (`~/.config/niri/config.kdl` or `config.d/50-startup.kdl`)
```kdl
spawn-at-startup "systemctl" "--user" "start" "awww-daemon.service" "simple-bar.service"
```

#### Hyprland (`~/.config/hypr/hyprland.conf`)
```ini
exec-once = systemctl --user start awww-daemon.service simple-bar.service
```

#### Sway (`~/.config/sway/config`)
```ini
exec systemctl --user start awww-daemon.service simple-bar.service
```

---

## 🛠️ Architecture & Documentation

```
simple-bar/
├── shell.qml                  # Quickshell bar, panels, launcher, power menu, and Niri cheatsheet
├── config.json                # Persistent bar & wallpaper settings
├── scripts/
│   ├── control.py             # Asynchronous hardware bridge & WM event stream
│   └── theme.py               # Wallpaper engine, Wallhaven client & terminal theme exporter
├── systemd/
│   ├── awww-daemon.service    # Systemd service with wallpaper restoration hook
│   └── simple-bar.service     # Systemd service for the bar interface
├── CHANGELOG.md               # Comprehensive log of features, bugs, and fixes
├── install.sh                 # Cross-distro installer and systemd configurator
└── .gitignore
```

For full details on recent fixes, features, and debugging history, refer to [CHANGELOG.md](CHANGELOG.md).

### Making Future Changes
Since the configuration is symlinked to `~/.config/quickshell/simple-bar`, any edits made in your local repository are immediately active:

1. Edit [`shell.qml`](shell.qml) or [`scripts/control.py`](scripts/control.py).
2. Reload quickshell:
   ```bash
   killall qs && qs -d -p ~/.config/quickshell/simple-bar
   ```
3. Commit and push your changes to GitHub:
   ```bash
   git add .
   git commit -m "feat: your new feature"
   git push
   ```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
